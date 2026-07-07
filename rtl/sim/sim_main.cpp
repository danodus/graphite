// sim_main.cpp
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <SDL.h>
#include <Vtop.h>
#include <cube.h>
#include <errno.h>
#include <fcntl.h>
#include <graphite.h>
#include <string.h>
#include <teapot.h>
#include <termios.h>
#include <stdio.h>
#include <unistd.h>
#include <verilated.h>

#include <deque>
#include <iostream>
#include <limits>
#include <vector>

#define FB_WIDTH 320
#define FB_HEIGHT 240
#define WINDOW_SCALE 3
#define VRAM_SIZE   (16*1024*1024)

#define OP_SET_MIN_X 0
#define OP_SET_MAX_X 1
#define OP_SET_MAX_Y 2
#define OP_SET_START_X 3
#define OP_SET_START_Y 4
#define OP_SET_E01_START 5
#define OP_SET_E12_START 6
#define OP_SET_E20_START 7
#define OP_SET_STEP_E01_X 8
#define OP_SET_STEP_E01_Y 9
#define OP_SET_STEP_E12_X 10
#define OP_SET_STEP_E12_Y 11
#define OP_SET_STEP_E20_X 12
#define OP_SET_STEP_E20_Y 13
#define OP_SET_START_W_INV 14
#define OP_SET_START_S 15
#define OP_SET_START_T 16
#define OP_SET_START_R 17
#define OP_SET_START_G 18
#define OP_SET_START_B 19
#define OP_SET_DW_DX 20
#define OP_SET_DW_DY 21
#define OP_SET_DS_DX 22
#define OP_SET_DS_DY 23
#define OP_SET_DT_DX 24
#define OP_SET_DT_DY 25
#define OP_SET_DR_DX 26
#define OP_SET_DR_DY 27
#define OP_SET_DG_DX 28
#define OP_SET_DG_DY 29
#define OP_SET_DB_DX 30
#define OP_SET_DB_DY 31
#define OP_CLEAR 32
#define OP_DRAW 33
#define OP_SWAP 34
#define OP_SET_TEX_ADDR 35
#define OP_SET_FB_ADDR 36

#if FIXED_POINT
#define PARAM(x) (x)
#else
#define PARAM(x) (_FLOAT_TO_FIXED(x, 14))
#endif

extern uint16_t tex64x64[];
extern uint16_t tex32x32[];
extern uint16_t tex32x64[];
extern uint16_t tex256x2048[];
uint16_t *tex = tex64x64;
#define TEXTURE_SCALE_X 1
#define TEXTURE_SCALE_Y 1
#define TEXTURE_WIDTH (32 << TEXTURE_SCALE_X)
#define TEXTURE_HEIGHT (32 << TEXTURE_SCALE_Y)

typedef int32_t fixed16;
#define TO_FIXED(x)          ((fixed16)std::round((x) * 65536.0f))
#define INT_TO_FIXED(x)      ((fixed16)((x) << 16))
#define FIXED_TO_INT(x)      ((int32_t)((x) >> 16))
#define FIXED_MUL(a, b)      ((fixed16)(((int64_t)(a) * (b)) >> 16))
#define FIXED_DIV(a, b)      ((fixed16)(((int64_t)(a) << 16) / (b)))
#define FIXED_CEIL_HALF(x)   (((x) + 0x7FFF) >> 16)

struct Vertex2 {
    int16_t x, y; // 12.4 fixed-point format
    fixed16 w; 
    fixed16 s, t;
    fixed16 r, g, b; 
};

static inline int16_t min3(int16_t a, int16_t b, int16_t c) {
    int16_t m = a; if (b < m) m = b; if (c < m) m = c; return m;
}

static inline int16_t max3(int16_t a, int16_t b, int16_t c) {
    int16_t m = a; if (b > m) m = b; if (c > m) m = c; return m;
}

// Serial

// Ref.: https://stackoverflow.com/questions/6947413/how-to-open-read-and-write-from-serial-port-in-c

int g_serial_fd = -1;

int set_interface_attribs(int fd, int speed, int parity) {
    struct termios tty;
    if (tcgetattr(fd, &tty) != 0) {
        printf("error %d from tcgetattr", errno);
        return -1;
    }

    cfsetospeed(&tty, speed);
    cfsetispeed(&tty, speed);

    tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;  // 8-bit chars
    // disable IGNBRK for mismatched speed tests; otherwise receive break
    // as \000 chars
    tty.c_iflag &= ~IGNBRK;  // disable break processing
    tty.c_lflag = 0;         // no signaling chars, no echo,
                             // no canonical processing
    tty.c_oflag = 0;         // no remapping, no delays
    tty.c_cc[VMIN] = 0;      // read doesn't block
    tty.c_cc[VTIME] = 5;     // 0.5 seconds read timeout

    tty.c_iflag &= ~(IXON | IXOFF | IXANY);  // shut off xon/xoff ctrl

    tty.c_cflag |= (CLOCAL | CREAD);    // ignore modem controls,
                                        // enable reading
    tty.c_cflag &= ~(PARENB | PARODD);  // shut off parity
    tty.c_cflag |= parity;
    tty.c_cflag &= ~CSTOPB;
    tty.c_cflag &= ~CRTSCTS;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        printf("error %d from tcsetattr", errno);
        return -1;
    }
    return 0;
}

void set_blocking(int fd, int should_block) {
    struct termios tty;
    memset(&tty, 0, sizeof tty);
    if (tcgetattr(fd, &tty) != 0) {
        printf("error %d from tggetattr", errno);
        return;
    }

    tty.c_cc[VMIN] = should_block ? 1 : 0;
    tty.c_cc[VTIME] = 5;  // 0.5 seconds read timeout

    if (tcsetattr(fd, TCSANOW, &tty) != 0) printf("error %d setting term attributes", errno);
}

// -------------

struct Command {
    uint32_t opcode : 8;
    uint32_t param : 24;
};

std::deque<Command> g_commands;

void pulse_clk(Vtop* top) {
    top->contextp()->timeInc(1);
    top->clk = 1;
    top->eval();

    top->contextp()->timeInc(1);
    top->clk = 0;
    top->eval();
}

static void swap(fx32* a, fx32* b) {
    fx32 c = *a;
    *a = *b;
    *b = c;
}

static inline int64_t mul_shr4(int64_t a, int64_t b) {
    return a * (b >> 4) + ((a * (b & 15)) >> 4);
}

static inline int64_t solve_gradient_high(int64_t det, fixed16 termA, int32_t factorA, fixed16 termB, int32_t factorB) {
    int64_t num = (int64_t)termA * factorA - (int64_t)termB * factorB; 
    return (num / det) * 1048576LL + ((num % det) * 1048576LL) / det;
}



void xd_draw_triangle(vec3d p[3], vec2d t[3], vec3d c[3], texture_t* tex, bool clamp_s, bool clamp_t, int texture_scale_x, int texture_scale_y,
                      bool depth_test, bool perspective_correct)                      
{
    uint32_t texture_width = 32 << texture_scale_x;
    uint32_t texture_height = 32 << texture_scale_y;

    Vertex2 v0, v1, v2;
    v0.x = p[0].x >> 12; v0.y = p[0].y >> 12; v0.w = t[0].w; v0.s = MUL(t[0].u, FXI(texture_width)); v0.t = MUL(t[0].v, FXI(texture_height)); v0.r = MUL(c[0].x, FXI(255)); v0.g = MUL(c[0].y, FXI(255)); v0.b = MUL(c[0].z, FXI(255));
    v1.x = p[1].x >> 12; v1.y = p[1].y >> 12; v1.w = t[1].w; v1.s = MUL(t[1].u, FXI(texture_width)); v1.t = MUL(t[1].v, FXI(texture_height)); v1.r = MUL(c[1].x, FXI(255)); v1.g = MUL(c[1].y, FXI(255)); v1.b = MUL(c[1].z, FXI(255));
    v2.x = p[2].x >> 12; v2.y = p[2].y >> 12; v2.w = t[2].w; v2.s = MUL(t[2].u, FXI(texture_width)); v2.t = MUL(t[2].v, FXI(texture_height)); v2.r = MUL(c[2].x, FXI(255)); v2.g = MUL(c[2].y, FXI(255)); v2.b = MUL(c[2].z, FXI(255));

    if (v0.y > v1.y) std::swap(v0, v1);
    if (v0.y > v2.y) std::swap(v0, v2);
    if (v1.y > v2.y) std::swap(v1, v2);

    int32_t dx1 = v1.x - v0.x; int32_t dy1 = v1.y - v0.y;
    int32_t dx2 = v2.x - v0.x; int32_t dy2 = v2.y - v0.y;
    int64_t det = (int64_t)dx1 * dy2 - (int64_t)dy1 * dx2; // 24.8 format
    if (det == 0) return; 

    // SOLVE HIGH-PRECISION GRADIENTS
    fixed16 w0_inv = v0.w;
    fixed16 w1_inv = v1.w;
    fixed16 w2_inv = v2.w;

    fixed16 s0_w = FIXED_MUL(v0.s, w0_inv); fixed16 s1_w = FIXED_MUL(v1.s, w1_inv); fixed16 s2_w = FIXED_MUL(v2.s, w2_inv);
    fixed16 t0_w = FIXED_MUL(v0.t, w0_inv); fixed16 t1_w = FIXED_MUL(v1.t, w1_inv); fixed16 t2_w = FIXED_MUL(v2.t, w2_inv);
    fixed16 r0_w = FIXED_MUL(v0.r, w0_inv); fixed16 r1_w = FIXED_MUL(v1.r, w1_inv); fixed16 r2_w = FIXED_MUL(v2.r, w2_inv);
    fixed16 g0_w = FIXED_MUL(v0.g, w0_inv); fixed16 g1_w = FIXED_MUL(v1.g, w1_inv); fixed16 g2_w = FIXED_MUL(v2.g, w2_inv);
    fixed16 b0_w = FIXED_MUL(v0.b, w0_inv); fixed16 b1_w = FIXED_MUL(v1.b, w1_inv); fixed16 b2_w = FIXED_MUL(v2.b, w2_inv);

    fixed16 dw_inv1 = w1_inv - w0_inv; fixed16 dw_inv2 = w2_inv - w0_inv;
    fixed16 ds1 = s1_w - s0_w;         fixed16 ds2 = s2_w - s0_w;
    fixed16 dt1 = t1_w - t0_w;         fixed16 dt2 = t2_w - t0_w;
    fixed16 dr1 = r1_w - r0_w;         fixed16 dr2 = r2_w - r0_w;
    fixed16 dg1 = g1_w - g0_w;         fixed16 dg2 = g2_w - g0_w;
    fixed16 db1 = b1_w - b0_w;         fixed16 db2 = b2_w - b0_w;

    int64_t raw_dw_dx = solve_gradient_high(det, dw_inv1, dy2, dw_inv2, dy1);
    int64_t raw_du_dx = solve_gradient_high(det, ds1,     dy2, ds2,     dy1);
    int64_t raw_dv_dx = solve_gradient_high(det, dt1,     dy2, dt2,     dy1);
    int64_t raw_dr_dx = solve_gradient_high(det, dr1,     dy2, dr2,     dy1);
    int64_t raw_dg_dx = solve_gradient_high(det, dg1,     dy2, dg2,     dy1);
    int64_t raw_db_dx = solve_gradient_high(det, db1,     dy2, db2,     dy1);

    int64_t raw_dw_dy = solve_gradient_high(det, dw_inv2, dx1, dw_inv1, dx2);
    int64_t raw_ds_dy = solve_gradient_high(det, ds2,     dx1, ds1,     dx2);
    int64_t raw_dt_dy = solve_gradient_high(det, dt2,     dx1, dt1,     dx2);
    int64_t raw_dr_dy = solve_gradient_high(det, dr2,     dx1, dr1,     dx2);
    int64_t raw_dg_dy = solve_gradient_high(det, dg2,     dx1, dg1,     dx2);
    int64_t raw_db_dy = solve_gradient_high(det, db2,     dx1, db1,     dx2);

    int64_t raw_start_w = ((int64_t)w0_inv << 16) - mul_shr4(v0.x, raw_dw_dx) - mul_shr4(v0.y, raw_dw_dy);
    int64_t raw_start_s = ((int64_t)s0_w   << 16) - mul_shr4(v0.x, raw_du_dx) - mul_shr4(v0.y, raw_ds_dy);
    int64_t raw_start_t = ((int64_t)t0_w   << 16) - mul_shr4(v0.x, raw_dv_dx) - mul_shr4(v0.y, raw_dt_dy);
    int64_t raw_start_r = ((int64_t)r0_w   << 16) - mul_shr4(v0.x, raw_dr_dx) - mul_shr4(v0.y, raw_dr_dy);
    int64_t raw_start_g = ((int64_t)g0_w   << 16) - mul_shr4(v0.x, raw_dg_dx) - mul_shr4(v0.y, raw_dg_dy);
    int64_t raw_start_b = ((int64_t)b0_w   << 16) - mul_shr4(v0.x, raw_db_dx) - mul_shr4(v0.y, raw_db_dy);    

    int32_t start_w = (int32_t)(raw_start_w >> 2);
    int32_t dw_dx   = (int32_t)(raw_dw_dx   >> 2);
    int32_t dw_dy   = (int32_t)(raw_dw_dy   >> 2);

    int32_t start_s = (int32_t)(raw_start_s >> 14);
    int32_t du_dx   = (int32_t)(raw_du_dx   >> 14);
    int32_t du_dy   = (int32_t)(raw_ds_dy   >> 14);

    int32_t start_t = (int32_t)(raw_start_t >> 14);
    int32_t dv_dx   = (int32_t)(raw_dv_dx   >> 14);
    int32_t dv_dy   = (int32_t)(raw_dt_dy   >> 14);

    int32_t start_r = ((int32_t)(raw_start_r >> 20) << 8) >> 8;
    int32_t dr_dx   = ((int32_t)(raw_dr_dx   >> 20) << 8) >> 8;
    int32_t dr_dy   = ((int32_t)(raw_dr_dy   >> 20) << 8) >> 8;

    int32_t start_g = ((int32_t)(raw_start_g >> 20) << 8) >> 8;
    int32_t dg_dx   = ((int32_t)(raw_dg_dx   >> 20) << 8) >> 8;
    int32_t dg_dy   = ((int32_t)(raw_dg_dy   >> 20) << 8) >> 8;

    int32_t start_b = ((int32_t)(raw_start_b >> 20) << 8) >> 8;
    int32_t db_dx   = ((int32_t)(raw_db_dx   >> 20) << 8) >> 8;
    int32_t db_dy   = ((int32_t)(raw_db_dy   >> 20) << 8) >> 8;

    // Rasterizer Bounding Box & Pineda Edges setup
    bool sign_bit = det > 0;
    int32_t sign = sign_bit ? -1 : 1;

    int start_y = v0.y >> 4;
    int min_x   = min3(v0.x, v1.x, v2.x) >> 4;
    int max_x   = max3(v0.x, v1.x, v2.x) >> 4;
    int max_y   = v2.y >> 4;

    if (min_x < 0) min_x = 0;
    if (max_x >= FB_WIDTH) max_x = FB_WIDTH - 1;
    if (max_y >= FB_HEIGHT) max_y = FB_HEIGHT - 1;
    if (start_y < 0) start_y = 0;    

    int32_t step_e01_x = sign * ((int32_t)(v1.y - v0.y) << 4);
    int32_t step_e01_y = -sign * ((int32_t)(v1.x - v0.x) << 4);
    int32_t step_e12_x = sign * ((int32_t)(v2.y - v1.y) << 4);
    int32_t step_e12_y = -sign * ((int32_t)(v2.x - v1.x) << 4);
    int32_t step_e20_x = sign * ((int32_t)(v0.y - v2.y) << 4);
    int32_t step_e20_y = -sign * ((int32_t)(v0.x - v2.x) << 4);

    int32_t bias01, bias12, bias20;
    if (sign == -1) {
        bias01 = (dy1 > 0 || (dy1 == 0 && dx1 < 0)) ? 0 : -1;
        bias12 = ((v2.y - v1.y) > 0 || ((v2.y - v1.y) == 0 && (v2.x - v1.x) < 0)) ? 0 : -1;
        bias20 = ((v0.y - v2.y) > 0 || ((v0.y - v2.y) == 0 && (v0.x - v2.x) < 0)) ? 0 : -1;
    } else {
        bias01 = (dy1 > 0 || (dy1 == 0 && dx1 < 0)) ? -1 : 0;
        bias12 = ((v2.y - v1.y) > 0 || ((v2.y - v1.y) == 0 && (v2.x - v1.x) < 0)) ? -1 : 0;
        bias20 = ((v0.y - v2.y) > 0 || ((v0.y - v2.y) == 0 && (v0.x - v2.x) < 0)) ? -1 : 0;
    }    

    int curr_x = min_x;
    int curr_y = start_y;
    int32_t p_x = (curr_x << 4) + 8;
    int32_t p_y = (curr_y << 4) + 8;

    int32_t E01 = sign * ((p_x - v0.x) * dy1 - (p_y - v0.y) * dx1) + bias01;
    int32_t E12 = sign * ((p_x - v1.x) * (v2.y - v1.y) - (p_y - v1.y) * (v2.x - v1.x)) + bias12;
    int32_t E20 = sign * ((p_x - v2.x) * (v0.y - v2.y) - (p_y - v2.y) * (v0.x - v2.x)) + bias20;

    int32_t acc_w_inv = start_w + (int32_t)(((int64_t)curr_x * dw_dx) + ((int64_t)curr_y * dw_dy) + (dw_dx >> 1) + (dw_dy >> 1));
    int32_t acc_u_w   = start_s + (int32_t)(((int64_t)curr_x * du_dx) + ((int64_t)curr_y * du_dy) + (du_dx >> 1) + (du_dy >> 1));
    int32_t acc_v_w   = start_t + (int32_t)(((int64_t)curr_x * dv_dx) + ((int64_t)curr_y * dv_dy) + (dv_dx >> 1) + (dv_dy >> 1));
    int32_t acc_r_w   = start_r + (int32_t)(((int64_t)curr_x * dr_dx) + ((int64_t)curr_y * dr_dy) + (dr_dx >> 1) + (dr_dy >> 1));
    int32_t acc_g_w   = start_g + (int32_t)(((int64_t)curr_x * dg_dx) + ((int64_t)curr_y * dg_dy) + (dg_dx >> 1) + (dg_dy >> 1));
    int32_t acc_b_w   = start_b + (int32_t)(((int64_t)curr_x * db_dx) + ((int64_t)curr_y * db_dy) + (db_dx >> 1) + (db_dy >> 1));


    struct Command cmd;

    auto push_16 = [&](uint32_t op, int32_t val) {
        cmd.opcode = op;
        cmd.param = val & 0xFFFF;
        g_commands.push_back(cmd);
    };

    auto push_32 = [&](uint32_t op, int32_t val) {
        cmd.opcode = op;
        cmd.param = val & 0xFFFF;
        g_commands.push_back(cmd);
        cmd.param = 0x10000 | ((val >> 16) & 0xFFFF);
        g_commands.push_back(cmd);
    };

    push_16(OP_SET_MIN_X, min_x);
    push_16(OP_SET_MAX_X, max_x);
    push_16(OP_SET_MAX_Y, max_y);
    push_16(OP_SET_START_X, curr_x);
    push_16(OP_SET_START_Y, curr_y);

    push_32(OP_SET_E01_START, E01);
    push_32(OP_SET_E12_START, E12);
    push_32(OP_SET_E20_START, E20);
    
    push_32(OP_SET_STEP_E01_X, step_e01_x);
    push_32(OP_SET_STEP_E01_Y, step_e01_y);
    push_32(OP_SET_STEP_E12_X, step_e12_x);
    push_32(OP_SET_STEP_E12_Y, step_e12_y);
    push_32(OP_SET_STEP_E20_X, step_e20_x);
    push_32(OP_SET_STEP_E20_Y, step_e20_y);

    push_32(OP_SET_START_W_INV, acc_w_inv);
    push_32(OP_SET_START_S, acc_u_w);
    push_32(OP_SET_START_T, acc_v_w);
    push_32(OP_SET_START_R, acc_r_w);
    push_32(OP_SET_START_G, acc_g_w);
    push_32(OP_SET_START_B, acc_b_w);

    push_32(OP_SET_DW_DX, dw_dx);
    push_32(OP_SET_DW_DY, dw_dy);
    push_32(OP_SET_DS_DX, du_dx);
    push_32(OP_SET_DS_DY, du_dy);
    push_32(OP_SET_DT_DX, dv_dx);
    push_32(OP_SET_DT_DY, dv_dy);
    push_32(OP_SET_DR_DX, dr_dx);
    push_32(OP_SET_DR_DY, dr_dy);
    push_32(OP_SET_DG_DX, dg_dx);
    push_32(OP_SET_DG_DY, dg_dy);
    push_32(OP_SET_DB_DX, db_dx);
    push_32(OP_SET_DB_DY, db_dy);

    cmd.opcode = OP_DRAW;

    cmd.param = (depth_test ? 0b01000 : 0b00000) | (clamp_s ? 0b00100 : 0b00000) | (clamp_t ? 0b00010 : 0b00000) |
              ((tex != NULL) ? 0b00001 : 0b00000) | (perspective_correct ? 0b10000 : 0b00000);

    cmd.param |= texture_scale_x << 5;
    cmd.param |= texture_scale_y << 8;

    g_commands.push_back(cmd);
}

void clear() {
    Command cmd;
    // Clear framebuffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x0031A6;
    g_commands.push_back(cmd);
    // Clear depth buffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x010000 | 20000; // Initialize to 20000
    g_commands.push_back(cmd);
}

void swap() {
    Command cmd;
    cmd.opcode = OP_SWAP;
    cmd.param = 0;
    g_commands.push_back(cmd);
}

void send_command(const char* s) {
    Command c;
    c.opcode = s[0];
    c.param = (((uint32_t)s[1] << 16) & 0xFF0000) | (((uint32_t)s[2] << 8) & 0xFF00) | ((uint32_t)s[3] & 0xFF);
    g_commands.push_back(c);
}

void write_texture(uint16_t* vram) {
    uint32_t tex_addr = 3 * FB_WIDTH * FB_HEIGHT;
    memcpy(vram + tex_addr, tex, TEXTURE_WIDTH*TEXTURE_HEIGHT*2);
}

// Uncompressed 24-bit BGR TGA (type 2), top-left origin (descriptor 0x20).
static bool write_rgb565_tga(const char* path, const uint16_t* rgb565, int w, int h) {
    FILE* fp = fopen(path, "wb");
    if (!fp) {
        std::cerr << "write_rgb565_tga: cannot open " << path << ": " << strerror(errno) << "\n";
        return false;
    }
    uint8_t header[18] = {};
    header[2] = 2;  // uncompressed true-color
    header[12] = (uint8_t)(w & 0xFF);
    header[13] = (uint8_t)((w >> 8) & 0xFF);
    header[14] = (uint8_t)(h & 0xFF);
    header[15] = (uint8_t)((h >> 8) & 0xFF);
    header[16] = 24;
    header[17] = 0x20;  // top-left origin
    if (fwrite(header, 1, 18, fp) != 18) {
        std::cerr << "write_rgb565_tga: short write header\n";
        fclose(fp);
        return false;
    }
    for (int y = 0; y < h; ++y) {
        const uint16_t* row = rgb565 + y * w;
        for (int x = 0; x < w; ++x) {
            uint16_t p = row[x];
            unsigned r5 = (p >> 11) & 31u;
            unsigned g6 = (p >> 5) & 63u;
            unsigned b5 = p & 31u;
            uint8_t b = (uint8_t)((b5 << 3) | (b5 >> 2));
            uint8_t g = (uint8_t)((g6 << 2) | (g6 >> 4));
            uint8_t r = (uint8_t)((r5 << 3) | (r5 >> 2));
            if (fputc(b, fp) == EOF || fputc(g, fp) == EOF || fputc(r, fp) == EOF) {
                std::cerr << "write_rgb565_tga: write error\n";
                fclose(fp);
                return false;
            }
        }
    }
    fclose(fp);
    return true;
}

// Return 0 if byte-identical, 1 on mismatch or I/O error (prints to stderr).
static int compare_binary_files(const char* path_a, const char* path_b) {
    FILE* fa = fopen(path_a, "rb");
    FILE* fb = fopen(path_b, "rb");
    if (!fa) {
        std::cerr << "compare_binary_files: cannot open " << path_a << ": " << strerror(errno) << "\n";
        return 1;
    }
    if (!fb) {
        std::cerr << "compare_binary_files: cannot open " << path_b << ": " << strerror(errno) << "\n";
        fclose(fa);
        return 1;
    }
    if (fseek(fa, 0, SEEK_END) != 0 || fseek(fb, 0, SEEK_END) != 0) {
        std::cerr << "compare_binary_files: fseek failed\n";
        fclose(fa);
        fclose(fb);
        return 1;
    }
    long na = ftell(fa);
    long nb = ftell(fb);
    if (na < 0 || nb < 0) {
        std::cerr << "compare_binary_files: ftell failed\n";
        fclose(fa);
        fclose(fb);
        return 1;
    }
    if (na != nb) {
        std::cerr << "golden TGA size mismatch: " << path_a << " (" << na << " bytes) vs " << path_b << " (" << nb
                  << " bytes)\n";
        fclose(fa);
        fclose(fb);
        return 1;
    }
    rewind(fa);
    rewind(fb);
    std::vector<uint8_t> bufa((size_t)na);
    std::vector<uint8_t> bufb((size_t)nb);
    if (fread(bufa.data(), 1, (size_t)na, fa) != (size_t)na || fread(bufb.data(), 1, (size_t)nb, fb) != (size_t)nb) {
        std::cerr << "compare_binary_files: short read\n";
        fclose(fa);
        fclose(fb);
        return 1;
    }
    fclose(fa);
    fclose(fb);
    size_t n_diff = 0;
    for (long i = 0; i < na; ++i) {
        if (bufa[(size_t)i] != bufb[(size_t)i]) ++n_diff;
    }
    if (n_diff != 0) {
        std::cerr << "golden TGA mismatch vs " << path_b << ": " << n_diff << " byte(s) differ (of " << na << ")\n";
        return 1;
    }
    return 0;
}

int main(int argc, char** argv, char** env) {
    const char* tga_path = nullptr;
    const char* golden_tga_path = nullptr;
    int argi = 1;
    while (argi < argc) {
        if (strcmp(argv[argi], "--write-tga") == 0) {
            if (argi + 1 >= argc) {
                std::cerr << "usage: --write-tga <file.tga>\n";
                return 1;
            }
            tga_path = argv[argi + 1];
            argi += 2;
            continue;
        }
        if (strcmp(argv[argi], "--golden-tga") == 0) {
            if (argi + 1 >= argc) {
                std::cerr << "usage: --golden-tga <reference.tga>\n";
                return 1;
            }
            golden_tga_path = argv[argi + 1];
            argi += 2;
            continue;
        }
        break;
    }
    if (golden_tga_path && !tga_path) {
        std::cerr << "--golden-tga requires --write-tga <path> (same run captures then compares)\n";
        return 1;
    }
    if (argi < argc) {
        g_serial_fd = open(argv[argi], O_RDWR | O_NOCTTY | O_SYNC | O_NONBLOCK);
        if (g_serial_fd < 0) {
            printf("error %d opening %s: %s", errno, argv[argi], strerror(errno));
            return 1;
        }
        set_interface_attribs(g_serial_fd, B115200, 0);  // set speed to 115,200 bps, 8n1 (no parity)
        set_blocking(g_serial_fd, 0);
    }

    SDL_Init(SDL_INIT_VIDEO);

    SDL_Window* window = SDL_CreateWindow("Graphite", SDL_WINDOWPOS_UNDEFINED_DISPLAY(1), SDL_WINDOWPOS_UNDEFINED,
                                          FB_WIDTH * WINDOW_SCALE, FB_HEIGHT * WINDOW_SCALE, 0);

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    uint16_t* vram_data = new uint16_t[VRAM_SIZE];
    for (size_t i = 0; i < VRAM_SIZE; ++i) vram_data[i] = 0x0000;

    SDL_Texture* texture =
        SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGB565, SDL_TEXTUREACCESS_STREAMING, FB_WIDTH, FB_HEIGHT);

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

    Vtop* top = new Vtop{contextp.get(), "TOP"};

    top->clk = 0;
    top->eval();

    top->reset_i = 1;
    pulse_clk(top);
    top->reset_i = 0;

    Command c;

    model_t* teapot_model = load_teapot();
    model_t* cube_model = load_cube();
    model_t* current_model = cube_model;

    float theta = 0.5f;

    float yaw = 0.0f;

    vec3d vec_up = {FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)};
    vec3d vec_camera = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};

    // Projection matrix
    mat4x4 mat_proj = matrix_make_projection(FB_WIDTH, FB_HEIGHT, 60.0f);

    bool anim = false;
    bool wireframe = false;
    size_t nb_lights = 0;
    bool gouraud_shading = false;
    bool textured = true;
    bool clamp_s = false;
    bool clamp_t = false;
    bool perspective_correct = true;
    bool show_depth = false;

    light_t lights[5];
    lights[0].direction = {FX(0.0f), FX(0.0f), FX(1.0f), FX(0.0f)};
    lights[0].ambient_color = {FX(0.1f), FX(0.1f), FX(0.1f), FX(1.0f)};
    lights[0].diffuse_color = {FX(0.5f), FX(0.5f), FX(0.5f), FX(1.0f)};
    lights[1].direction = {FX(1.0f), FX(0.0f), FX(0.0f), FX(0.0f)};
    lights[1].ambient_color = {FX(0.1f), FX(0.0f), FX(0.0f), FX(1.0f)};
    lights[1].diffuse_color = {FX(0.2f), FX(0.0f), FX(0.0f), FX(1.0f)};
    lights[2].direction = {FX(0.0f), FX(1.0f), FX(0.0f), FX(0.0f)};
    lights[2].ambient_color = {FX(0.0f), FX(0.1f), FX(0.0f), FX(1.0f)};
    lights[2].diffuse_color = {FX(0.0f), FX(0.2f), FX(0.0f), FX(1.0f)};
    lights[3].direction = {FX(0.0f), FX(-1.0f), FX(0.0f), FX(0.0f)};
    lights[3].ambient_color = {FX(0.0f), FX(0.0f), FX(0.1f), FX(1.0f)};
    lights[3].diffuse_color = {FX(0.0f), FX(0.0f), FX(0.2f), FX(1.0f)};
    lights[4].direction = {FX(-1.0f), FX(0.0f), FX(0.0f), FX(0.0f)};
    lights[4].ambient_color = {FX(0.1f), FX(0.1f), FX(0.0f), FX(1.0f)};
    lights[4].diffuse_color = {FX(0.2f), FX(0.2f), FX(0.0f), FX(1.0f)};

    bool quit = false;

    bool dump = false;

    unsigned int time = SDL_GetTicks();

    bool texture_dirty = true;

    int return_code = 0;

    while (!contextp->gotFinish() && !quit) {
        SDL_Event e;

        if (top->cmd_axis_tready_o && g_commands.size() == 0) {
            clear();

            //
            // camera
            //

            vec3d vec_target = {FX(0.0f), FX(0.0f), FX(1.0f), FX(1.0f)};
            mat4x4 mat_camera_rot = matrix_make_rotation_y(yaw);
            vec3d vec_look_dir = matrix_multiply_vector(&mat_camera_rot, &vec_target);
            vec_target = vector_add(&vec_camera, &vec_look_dir);

            mat4x4 mat_camera = matrix_point_at(&vec_camera, &vec_target, &vec_up);

            // make view matrix from camera
            mat4x4 mat_view = matrix_quick_inverse(&mat_camera);

            //
            // world
            //

            mat4x4 mat_rot_z = matrix_make_rotation_z(theta);
            mat4x4 mat_rot_x = matrix_make_rotation_x(theta);

            mat4x4 mat_trans = matrix_make_translation(FX(0.0f), FX(0.0f), FX(2.0f));
            mat4x4 mat_world, mat_normal;
            mat_world = matrix_make_identity();
            mat_world = mat_normal = matrix_multiply_matrix(&mat_rot_z, &mat_rot_x);
            mat_world = matrix_multiply_matrix(&mat_world, &mat_trans);

            if (texture_dirty || dump) {
                write_texture(vram_data);
                texture_dirty = false;
            }

            if (current_model) {
                // Draw cube
                texture_t dummy_texture;
                draw_model(FB_WIDTH, FB_HEIGHT, &vec_camera, current_model, &mat_world, gouraud_shading ? &mat_normal : NULL, &mat_proj, &mat_view, lights, nb_lights,
                           wireframe, textured ? &dummy_texture : NULL, clamp_s, clamp_t, TEXTURE_SCALE_X, TEXTURE_SCALE_Y, perspective_correct);

                swap();
            }

            if (dump) {
                for (auto cmd : g_commands) {
                    if (g_serial_fd >= 0) {
                        char b[4];
                        b[0] = cmd.opcode;
                        b[1] = cmd.param >> 16;
                        b[2] = (cmd.param >> 8) & 0xFF;
                        b[3] = cmd.param & 0xFF;
                        write(g_serial_fd, &b, 4);
                        if (cmd.opcode == OP_CLEAR || cmd.opcode == OP_DRAW) {
                            usleep((7 + 25) * 4000);
                        } else {
                            usleep((7 + 25) * 200);
                        }
                    } else {
                        printf("    send_command(b'\\x%02x\\x%02x\\x%02x\\x%02x')", cmd.opcode, cmd.param >> 16,
                               (cmd.param >> 8) & 0xFF, cmd.param & 0xFF);
                    }
                }
                dump = false;
            }

            float elapsed_time = (float)(SDL_GetTicks() - time) / 1000.0f;
            if (elapsed_time < 0.001f) elapsed_time = 0.001f;
            time = SDL_GetTicks();

            if (anim) theta += 2.0f * elapsed_time;

            while (SDL_PollEvent(&e)) {
                if (e.type == SDL_QUIT) {
                    quit = true;
                    continue;
                } else if (e.type == SDL_KEYDOWN) {
                    switch (e.key.keysym.scancode) {
                        case SDL_SCANCODE_1:
                            current_model = cube_model;
                            break;
                        case SDL_SCANCODE_2:
                            current_model = teapot_model;
                            break;
                        case SDL_SCANCODE_SPACE:
                            anim = !anim;
                            break;
                        case SDL_SCANCODE_TAB:
                            wireframe = !wireframe;
                            break;
                        case SDL_SCANCODE_L:
                            nb_lights = (nb_lights + 1) % 6;
                            break;
                        case SDL_SCANCODE_G:
                            gouraud_shading = !gouraud_shading;
                            break;                            
                        case SDL_SCANCODE_T:
                            textured = !textured;
                            break;
                        case SDL_SCANCODE_SLASH:
                            dump = true;
                            break;
                        case SDL_SCANCODE_U:
                            clamp_s = !clamp_s;
                            break;
                        case SDL_SCANCODE_V:
                            clamp_t = !clamp_t;
                            break;
                        case SDL_SCANCODE_P:
                            perspective_correct = !perspective_correct;
                            break;                            
                        case SDL_SCANCODE_F1:
                            show_depth = !show_depth;
                            break;
                        default:
                            break;
                    }
                }
            }

            vec3d vec_forward = vector_mul(&vec_look_dir, MUL(FX(2.0f), FX(elapsed_time)));
            const Uint8* state = SDL_GetKeyboardState(NULL);
            if (state[SDL_SCANCODE_UP]) vec_camera.y += MUL(FX(8.0f), FX(elapsed_time));
            if (state[SDL_SCANCODE_DOWN]) vec_camera.y -= MUL(FX(8.0f), FX(elapsed_time));
            if (state[SDL_SCANCODE_LEFT]) vec_camera.x -= MUL(FX(8.0f), FX(elapsed_time));
            if (state[SDL_SCANCODE_RIGHT]) vec_camera.x += MUL(FX(8.0f), FX(elapsed_time));
            if (state[SDL_SCANCODE_W]) vec_camera = vector_add(&vec_camera, &vec_forward);
            if (state[SDL_SCANCODE_S]) vec_camera = vector_sub(&vec_camera, &vec_forward);
            if (state[SDL_SCANCODE_A]) yaw -= 2.0f * elapsed_time;
            if (state[SDL_SCANCODE_D]) yaw += 2.0f * elapsed_time;
        }

        if (top->cmd_axis_tready_o) {
            if (g_commands.size() > 0) {
                auto c = g_commands.front();
                g_commands.pop_front();
                top->cmd_axis_tdata_i = (c.opcode << 24) | c.param;
                top->cmd_axis_tvalid_i = 1;
            }
        }

        // Combinational read from vram_data[addr]: RTL may latch vram_data_in_i on cycles
        // after vram_sel_o is deasserted (e.g. depth read), so always drive read data from addr.
        if (top->vram_addr_o < VRAM_SIZE) {
            if (top->vram_sel_o && top->vram_wr_o) {
                vram_data[top->vram_addr_o] = top->vram_data_out_o;
            }
            top->vram_data_in_i = vram_data[top->vram_addr_o];
        } else {
            top->vram_data_in_i = 0xF800;
        }

        if (top->swap_o) {

            if (tga_path) {
                if (!write_rgb565_tga(tga_path, vram_data + top->front_addr_o, FB_WIDTH, FB_HEIGHT)) {
                    return_code = 1;
                    quit = true;
                    break;
                }
                if (golden_tga_path && compare_binary_files(tga_path, golden_tga_path) != 0) {
                    return_code = 1;
                    quit = true;
                    break;
                }
                quit = true;
            } else {
                void* p;
                int pitch;
                SDL_LockTexture(texture, NULL, &p, &pitch);
                assert(pitch == FB_WIDTH * 2);
                if (show_depth) {
                    uint16_t* pp = (uint16_t*)p;
                    uint16_t* d = &vram_data[2 * FB_WIDTH * FB_HEIGHT];
                    for (int y = 0; y < FB_HEIGHT; ++y)
                        for (int x = 0; x < FB_WIDTH; ++x) {
                            // Green 6-bit
                            uint16_t i = *d >> 10;
                            *pp = (i << 5);
                            ++pp;
                            ++d;
                        }

                } else {
                    memcpy(p, vram_data + top->front_addr_o, FB_WIDTH * FB_HEIGHT * 2);
                }
                SDL_UnlockTexture(texture);

                int draw_w, draw_h;
                SDL_GL_GetDrawableSize(window, &draw_w, &draw_h);

                SDL_Rect vga_r = {0, 0, draw_w, draw_h};
                SDL_RenderCopy(renderer, texture, NULL, &vga_r);

                SDL_RenderPresent(renderer);
            }

        }

        pulse_clk(top);
        top->cmd_axis_tvalid_i = 0;
    };

    top->final();

    delete top;

    SDL_DestroyTexture(texture);
    SDL_Quit();

    if (g_serial_fd >= 0) close(g_serial_fd);

    return return_code;
}