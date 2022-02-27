#include <SDL.h>
#include <Vtop.h>
#include <cube.h>
#include <graphite.h>
#include <teapot.h>
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
#define OP_SET_COLOR 24
#define OP_CLEAR 25
#define OP_DRAW 26
#define OP_SWAP 27
#define OP_SET_TEX_ADDR 28
#define OP_WRITE_TEX 29

#if FIXED_POINT
#define TEXCOORD_PARAM(x) (x)
#else
#define TEXCOORD_PARAM(x) (_FLOAT_TO_FIXED(x, 16))
#endif

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

void xd_draw_line(fx32 x0, fx32 y0, fx32 x1, fx32 y1, int color) {
    if (y0 > y1) {
        swap(&x0, &x1);
        swap(&y0, &y1);
    }

    Command c;
    c.opcode = OP_SET_COLOR;
    c.param = color | color << 4 | color << 8;
    g_commands.push_back(c);

    c.opcode = OP_SET_X0;
    c.param = x0 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (x0 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Y0;
    c.param = y0 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (y0 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_X1;
    c.param = x1 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (x1 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Y1;
    c.param = y1 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (y1 >> 16);
    g_commands.push_back(c);

    g_commands.push_back(c);
    c.opcode = OP_DRAW;
    c.param = 0;
    g_commands.push_back(c);
}

void xd_draw_triangle(fx32 x0, fx32 y0, fx32 x1, fx32 y1, fx32 x2, fx32 y2, int color) {
    xd_draw_line(x0, y0, x1, y1, color);
    xd_draw_line(x1, y1, x2, y2, color);
    xd_draw_line(x2, y2, x0, y0, color);
}

void xd_draw_textured_triangle(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 x1, fx32 y1, fx32 z1, fx32 u1, fx32 v1,
                               fx32 x2, fx32 y2, fx32 z2, fx32 u2, fx32 v2, texture_t* tex) {
    Command c;

    c.opcode = OP_SET_X0;
    c.param = x0 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (x0 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Y0;
    c.param = y0 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (y0 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Z0;
    c.param = z0 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (z0 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_X1;
    c.param = x1 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (x1 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Y1;
    c.param = y1 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (y1 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Z1;
    c.param = z1 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (z1 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_X2;
    c.param = x2 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (x2 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Y2;
    c.param = y2 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (y2 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_Z2;
    c.param = z2 & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (z2 >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_S0;
    c.param = TEXCOORD_PARAM(u0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (TEXCOORD_PARAM(u0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_T0;
    c.param = TEXCOORD_PARAM(v0) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (TEXCOORD_PARAM(v0) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_S1;
    c.param = TEXCOORD_PARAM(u1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (TEXCOORD_PARAM(u1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_T1;
    c.param = TEXCOORD_PARAM(v1) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (TEXCOORD_PARAM(v1) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_S2;
    c.param = TEXCOORD_PARAM(u2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (TEXCOORD_PARAM(u2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_SET_T2;
    c.param = TEXCOORD_PARAM(v2) & 0xFFFF;
    g_commands.push_back(c);
    c.param = 0x10000 | (TEXCOORD_PARAM(v2) >> 16);
    g_commands.push_back(c);

    c.opcode = OP_DRAW;
    c.param = 1;
    g_commands.push_back(c);
}

void clear() {
    Command c;
    c.opcode = OP_SET_COLOR;
    c.param = 0x333;
    g_commands.push_back(c);
    c.opcode = OP_CLEAR;
    c.param = 0x000;
    g_commands.push_back(c);
}

void swap() {
    Command c;
    c.opcode = OP_SWAP;
    c.param = 0;
    g_commands.push_back(c);
}

void draw_model_with_camera(model_t* model, vec3d* vec_camera, float theta) {
    vec3d vec_up = {FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)};

    // Projection matrix
    mat4x4 mat_proj = matrix_make_projection(FB_WIDTH, FB_HEIGHT, 60.0f);

    float yaw = 0.0f;

    vec3d vec_target = {FX(0.0f), FX(0.0f), FX(1.0f), FX(1.0f)};
    mat4x4 mat_camera_rot = matrix_make_rotation_y(yaw);
    vec3d vec_look_dir = matrix_multiply_vector(&mat_camera_rot, &vec_target);
    vec_target = vector_add(vec_camera, &vec_look_dir);

    mat4x4 mat_camera = matrix_point_at(vec_camera, &vec_target, &vec_up);

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

    // Draw model
    draw_model(FB_WIDTH, FB_HEIGHT, vec_camera, model, &mat_world, &mat_proj, &mat_view, true, true, NULL);
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
    c.param = FB_WIDTH * FB_HEIGHT;
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
    SDL_Init(SDL_INIT_VIDEO);

    SDL_Window* window =
        SDL_CreateWindow("Graphite", SDL_WINDOWPOS_UNDEFINED_DISPLAY(1), SDL_WINDOWPOS_UNDEFINED, 640, 480, 0);

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    const size_t vram_size = FB_WIDTH * FB_HEIGHT + TEXTURE_WIDTH * TEXTURE_HEIGHT;
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
                draw_model(FB_WIDTH, FB_HEIGHT, &vec_camera, current_model, &mat_world, &mat_proj, &mat_view, true,
                           wireframe, NULL);
                swap();
            }

            if (dump) {
                for (auto cmd : g_commands) {
                    printf("    send_command(b'\\x%02x\\x%02x\\x%02x\\x%02x')", cmd.opcode, cmd.param >> 16,
                           (cmd.param >> 8) & 0xFF, cmd.param & 0xFF);
                }
                dump = false;
            }

            float elapsed_time = (float)(SDL_GetTicks() - time) / 1000.0f;
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
                        case SDL_SCANCODE_SLASH:
                            dump = true;
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

        if (top->vram_sel_o && top->vram_addr_o < FB_WIDTH * FB_HEIGHT + TEXTURE_WIDTH * TEXTURE_HEIGHT) {
            // assert(top->vram_addr_o < FB_WIDTH * FB_HEIGHT + TEXTURE_WIDTH * TEXTURE_HEIGHT);

            if (top->vram_wr_o) {
                vram_data[top->vram_addr_o] = top->vram_data_out_o;
            }
            top->vram_data_in_i = vram_data[top->vram_addr_o];
        } else {
            top->vram_data_in_i = 0xFF00;
        }

        if (top->swap_o) {
            void* p;
            int pitch;
            SDL_LockTexture(texture, NULL, &p, &pitch);
            assert(pitch == FB_WIDTH * 2);
            memcpy(p, vram_data, FB_WIDTH * FB_HEIGHT * 2);
            SDL_UnlockTexture(texture);

            int draw_w, draw_h;
            SDL_GL_GetDrawableSize(window, &draw_w, &draw_h);

            int scale_x, scale_y;
            scale_x = draw_w / 640;
            scale_y = draw_h / 480;

            SDL_Rect vga_r = {0, 0, scale_x * 640, scale_y * 480};
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

    return 0;
}