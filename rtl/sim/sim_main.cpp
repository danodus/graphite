#include <SDL.h>
#include <Vtop.h>
#include <cube.h>
#include <errno.h>
#include <fcntl.h>
#include <graphite.h>
#include <string.h>
#include <teapot.h>
#include <termios.h>
#include <unistd.h>
#include <verilated.h>

#include <deque>
#include <iostream>
#include <limits>

#define FB_WIDTH 128
#define FB_HEIGHT 128
#define TEXTURE_WIDTH 32
#define TEXTURE_HEIGHT 32

#define OP_SET_X0 0
#define OP_SET_Y0 1
#define OP_SET_Z0 2
#define OP_SET_X1 3
#define OP_SET_Y1 4
#define OP_SET_Z1 5
#define OP_SET_X2 6
#define OP_SET_Y2 7
#define OP_SET_Z2 8
#define OP_SET_R0 9
#define OP_SET_G0 10
#define OP_SET_B0 11
#define OP_SET_R1 12
#define OP_SET_G1 13
#define OP_SET_B1 14
#define OP_SET_R2 15
#define OP_SET_G2 16
#define OP_SET_B2 17
#define OP_SET_S0 18
#define OP_SET_T0 19
#define OP_SET_S1 20
#define OP_SET_T1 21
#define OP_SET_S2 22
#define OP_SET_T2 23
#define OP_CLEAR 24
#define OP_DRAW 25
#define OP_SWAP 26
#define OP_SET_TEX_ADDR 27
#define OP_WRITE_TEX 28

#if FIXED_POINT
#define PARAM(x) (x)
#define RMUL(x, y) ((int)((x) >> (SCALE)) * (int)((y)))
#else
#define PARAM(x) (_FLOAT_TO_FIXED(x, 16))
#define RMUL(x, y) (x * y)
#endif

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

void xd_draw_triangle(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 r0, fx32 g0, fx32 b0, fx32 a0, fx32 x1, fx32 y1,
                      fx32 z1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1, fx32 x2, fx32 y2, fx32 z2, fx32 u2,
                      fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2, texture_t* tex, bool clamp_s, bool clamp_t,
                      bool depth_test) {
    Command c;

    c.opcode = OP_SET_X0;
    c.param = PARAM(x0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(x0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Y0;
    c.param = PARAM(y0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(y0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Z0;
    c.param = PARAM(z0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(z0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_X1;
    c.param = PARAM(x1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(x1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Y1;
    c.param = PARAM(y1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(y1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Z1;
    c.param = PARAM(z1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(z1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_X2;
    c.param = PARAM(x2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(x2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Y2;
    c.param = PARAM(y2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(y2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Z2;
    c.param = PARAM(z2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(z2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_S0;
    c.param = PARAM(u0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(u0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_T0;
    c.param = PARAM(v0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(v0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_S1;
    c.param = PARAM(u1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(u1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_T1;
    c.param = PARAM(v1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(v1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_S2;
    c.param = PARAM(u2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(u2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_T2;
    c.param = PARAM(v2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(v2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_R0;
    c.param = PARAM(r0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(r0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_G0;
    c.param = PARAM(g0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(g0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_B0;
    c.param = PARAM(b0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(b0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_R1;
    c.param = PARAM(r1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(r1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_G1;
    c.param = PARAM(g1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(g1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_B1;
    c.param = PARAM(b1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(b1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_R2;
    c.param = PARAM(r2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(r2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_G2;
    c.param = PARAM(g2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(g2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_B2;
    c.param = PARAM(b2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (PARAM(b2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_DRAW;
    c.param = (depth_test ? 0b1000 : 0b0000) | (clamp_s ? 0b0100 : 0b0000) | (clamp_t ? 0b0010 : 0b0000) |
              ((tex != nullptr) ? 0b0001 : 0b0000);
    g_commands.push_back(c);
}

void clear() {
    Command c;
    // Clear framebuffer
    c.opcode = OP_CLEAR;
    c.param = 0x00F333;
    g_commands.push_back(c);
    // Clear depth buffer
    c.opcode = OP_CLEAR;
    c.param = 0x010000;
    g_commands.push_back(c);
}

void swap() {
    Command c;
    c.opcode = OP_SWAP;
    c.param = 0;
    g_commands.push_back(c);
}

const uint16_t img[] = {
    64373, 64373, 64373, 64373, 64373, 64373, 62770, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373,
    64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64972, 64972, 64972, 64972, 64169, 64169, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64169, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64169, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    63060, 63060, 63060, 63060, 63060, 63060, 62770, 64373, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060,
    63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060,
    62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770,
    62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770,
    64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373,
    64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 62770, 64373, 64373, 64373, 64373, 64373,
    64972, 64169, 64169, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64972, 64972, 64972,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64169, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64169, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060,
    63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 62770, 64373, 63060, 63060, 63060, 63060,
    62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770,
    62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770};

void send_command(const char* s) {
    Command c;
    c.opcode = s[0];
    c.param = (((uint32_t)s[1] << 16) & 0xFF0000) | (((uint32_t)s[2] << 8) & 0xFF00) | ((uint32_t)s[3] & 0xFF);
    g_commands.push_back(c);
}

void write_texture() {
    Command c;
    c.opcode = OP_SET_TEX_ADDR;
    c.param = 2 * FB_WIDTH * FB_HEIGHT;
    g_commands.push_back(c);
    c.opcode = OP_WRITE_TEX;

    const uint16_t* p = img;
    for (int t = 0; t < TEXTURE_WIDTH; ++t)
        for (int s = 0; s < TEXTURE_HEIGHT; ++s) {
            c.param = *p;
            g_commands.push_back(c);
            p++;
        }
}

int main(int argc, char** argv, char** env) {
    if (argc > 1) {
        g_serial_fd = open(argv[1], O_RDWR | O_NOCTTY | O_SYNC | O_NONBLOCK);
        if (g_serial_fd < 0) {
            printf("error %d opening %s: %s", errno, argv[1], strerror(errno));
            return 1;
        }
        set_interface_attribs(g_serial_fd, B115200, 0);  // set speed to 115,200 bps, 8n1 (no parity)
        set_blocking(g_serial_fd, 0);
    }

    SDL_Init(SDL_INIT_VIDEO);

    SDL_Window* window = SDL_CreateWindow("Graphite", SDL_WINDOWPOS_UNDEFINED_DISPLAY(1), SDL_WINDOWPOS_UNDEFINED,
                                          FB_WIDTH * 4, FB_HEIGHT * 4, 0);

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    const size_t vram_size = 2 * FB_WIDTH * FB_HEIGHT + TEXTURE_WIDTH * TEXTURE_HEIGHT;
    uint16_t* vram_data = new uint16_t[vram_size];
    for (size_t i = 0; i < vram_size; ++i) vram_data[i] = 0x0000;

    SDL_Texture* texture =
        SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB4444, SDL_TEXTUREACCESS_STREAMING, FB_WIDTH, FB_HEIGHT);

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

    float theta = 0.0f;

    float yaw = 0.0f;

    vec3d vec_up = {FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)};
    vec3d vec_camera = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};

    // Projection matrix
    mat4x4 mat_proj = matrix_make_projection(FB_WIDTH, FB_HEIGHT, 60.0f);

    bool anim = false;
    bool wireframe = false;
    bool lighting = false;
    bool textured = false;
    bool clamp_s = false;
    bool clamp_t = false;
    bool show_depth = false;

    uint16_t show_depth_value = 32000;
    uint16_t last_show_depth_value = show_depth_value;

    bool quit = false;

    bool dump = false;

    unsigned int time = SDL_GetTicks();

    bool texture_dirty = true;

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

            mat4x4 mat_trans = matrix_make_translation(FX(0.0f), FX(0.0f), FX(3.0f));
            mat4x4 mat_world;
            mat_world = matrix_make_identity();
            mat_world = matrix_multiply_matrix(&mat_rot_z, &mat_rot_x);
            mat_world = matrix_multiply_matrix(&mat_world, &mat_trans);

            if (texture_dirty || dump) {
                write_texture();
                texture_dirty = false;
            }

            if (current_model) {
                // Draw cube
                texture_t dummy_texture;
                draw_model(FB_WIDTH, FB_HEIGHT, &vec_camera, current_model, &mat_world, &mat_proj, &mat_view, lighting,
                           wireframe, textured ? &dummy_texture : NULL, clamp_s, clamp_t);

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
                        usleep((7 + 25) * 100);
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
                            lighting = !lighting;
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
                        case SDL_SCANCODE_F1:
                            show_depth = !show_depth;
                            break;
                        default:
                            break;
                    }
                }
            }

            vec3d vec_forward = vector_mul(&vec_look_dir, RMUL(FX(2.0f), FX(elapsed_time)));
            const Uint8* state = SDL_GetKeyboardState(NULL);
            if (state[SDL_SCANCODE_UP]) vec_camera.y += RMUL(FX(8.0f), FX(elapsed_time));
            if (state[SDL_SCANCODE_DOWN]) vec_camera.y -= RMUL(FX(8.0f), FX(elapsed_time));
            if (state[SDL_SCANCODE_LEFT]) vec_camera.x -= RMUL(FX(8.0f), FX(elapsed_time));
            if (state[SDL_SCANCODE_RIGHT]) vec_camera.x += RMUL(FX(8.0f), FX(elapsed_time));
            if (state[SDL_SCANCODE_W]) vec_camera = vector_add(&vec_camera, &vec_forward);
            if (state[SDL_SCANCODE_S]) vec_camera = vector_sub(&vec_camera, &vec_forward);
            if (state[SDL_SCANCODE_A]) yaw -= 2.0f * elapsed_time;
            if (state[SDL_SCANCODE_D]) yaw += 2.0f * elapsed_time;
            if (state[SDL_SCANCODE_LEFTBRACKET]) show_depth_value -= 1000;
            if (state[SDL_SCANCODE_RIGHTBRACKET]) show_depth_value += 1000;
        }

        if (top->cmd_axis_tready_o) {
            if (g_commands.size() > 0) {
                auto c = g_commands.front();
                g_commands.pop_front();
                top->cmd_axis_tdata_i = (c.opcode << 24) | c.param;
                top->cmd_axis_tvalid_i = 1;
            }
        }

        if (top->vram_sel_o && top->vram_addr_o < 2 * FB_WIDTH * FB_HEIGHT + TEXTURE_WIDTH * TEXTURE_HEIGHT) {
            // assert(top->vram_addr_o < FB_WIDTH * FB_HEIGHT + TEXTURE_WIDTH * TEXTURE_HEIGHT);

            if (top->vram_wr_o) {
                vram_data[top->vram_addr_o] = top->vram_data_out_o;
            }
            top->vram_data_in_i = vram_data[top->vram_addr_o];
        } else {
            top->vram_data_in_i = 0xFF00;
        }

        if (last_show_depth_value != show_depth_value) {
            printf("Displaying depth %d\n", show_depth_value);
            last_show_depth_value = show_depth_value;
        }
        if (top->swap_o) {
            void* p;
            int pitch;
            SDL_LockTexture(texture, NULL, &p, &pitch);
            assert(pitch == FB_WIDTH * 2);
            if (show_depth) {
                uint16_t* pp = (uint16_t*)p;
                uint16_t* d = &vram_data[FB_WIDTH * FB_HEIGHT];
                for (int y = 0; y < FB_HEIGHT; ++y)
                    for (int x = 0; x < FB_WIDTH; ++x) {
                        // if (*d > show_depth_value - 1000 && *d < show_depth_value + 1000) {
                        uint16_t i = *d >> 12;
                        *pp = (i) | (i << 4) | (i << 8);
                        //} else {
                        //    *pp = 0;
                        //}
                        ++pp;
                        ++d;
                    }

            } else {
                memcpy(p, vram_data, FB_WIDTH * FB_HEIGHT * 2);
            }
            SDL_UnlockTexture(texture);

            int draw_w, draw_h;
            SDL_GL_GetDrawableSize(window, &draw_w, &draw_h);

            SDL_Rect vga_r = {0, 0, draw_w, draw_h};
            SDL_RenderCopy(renderer, texture, NULL, &vga_r);

            SDL_RenderPresent(renderer);
        }

        pulse_clk(top);
        top->cmd_axis_tvalid_i = 0;
    };

    top->final();

    delete top;

    SDL_DestroyTexture(texture);
    SDL_Quit();

    if (g_serial_fd >= 0) close(g_serial_fd);

    return 0;
}