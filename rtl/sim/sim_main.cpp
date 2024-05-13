// sim_main.cpp
// Copyright (c) 2021-2024 Daniel Cliche
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
#include <unistd.h>
#include <verilated.h>

#include <deque>
#include <iostream>
#include <limits>

#define FB_WIDTH 320
#define FB_HEIGHT 240
#define WINDOW_SCALE 3
#define VRAM_SIZE   (16*1024*1024)

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
#define OP_SET_FB_ADDR 28

#if FIXED_POINT
#define PARAM(x) (x)
#else
#define PARAM(x) (_FLOAT_TO_FIXED(x, 14))
#endif

extern uint16_t tex64x64[];
extern uint16_t tex32x32[];
extern uint16_t tex32x64[];
extern uint16_t tex256x2048[];
uint16_t *tex = tex256x2048;
#define TEXTURE_WIDTH 256
#define TEXTURE_HEIGHT 2048

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

void xd_draw_triangle(vec3d p[3], vec2d t[3], vec3d c[3], texture_t* tex, bool clamp_s, bool clamp_t, int texture_scale_x, int texture_scale_y,
                      bool depth_test, bool perspective_correct)                      
{
    struct Command cmd;

    cmd.opcode = OP_SET_X0;
    cmd.param = PARAM(p[0].x) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(p[0].x) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_Y0;
    cmd.param = PARAM(p[0].y) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(p[0].y) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_Z0;
    cmd.param = PARAM(t[0].w) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(t[0].w) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_X1;
    cmd.param = PARAM(p[1].x) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(p[1].x) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_Y1;
    cmd.param = PARAM(p[1].y) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(p[1].y) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_Z1;
    cmd.param = PARAM(t[1].w) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(t[1].w) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_X2;
    cmd.param = PARAM(p[2].x) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(p[2].x) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_Y2;
    cmd.param = PARAM(p[2].y) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(p[2].y) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_Z2;
    cmd.param = PARAM(t[2].w) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(p[2].z) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_S0;
    cmd.param = PARAM(t[0].u) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(t[0].u) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_T0;
    cmd.param = PARAM(t[0].v) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(t[0].v) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_S1;
    cmd.param = PARAM(t[1].u) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(t[1].u) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_T1;
    cmd.param = PARAM(t[1].v) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(t[1].v) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_S2;
    cmd.param = PARAM(t[2].u) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(t[2].u) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_T2;
    cmd.param = PARAM(t[2].v) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(t[2].v) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_R0;
    cmd.param = PARAM(c[0].x) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(c[0].x) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_G0;
    cmd.param = PARAM(c[0].y) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(c[0].y) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_B0;
    cmd.param = PARAM(c[0].z) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(c[0].z) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_R1;
    cmd.param = PARAM(c[1].x) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(c[1].x) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_G1;
    cmd.param = PARAM(c[1].y) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(c[1].y) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_B1;
    cmd.param = PARAM(c[1].z) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(c[1].z) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_R2;
    cmd.param = PARAM(c[2].x) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(c[2].x) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_G2;
    cmd.param = PARAM(c[2].y) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(c[2].y) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_SET_B2;
    cmd.param = PARAM(c[2].z) & 0xFFFF;
    g_commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(c[2].z) >> 16);
    g_commands.push_back(cmd);

    cmd.opcode = OP_DRAW;

    cmd.param = (depth_test ? 0b01000 : 0b00000) | (clamp_s ? 0b00100 : 0b00000) | (clamp_t ? 0b00010 : 0b00000) |
              ((tex != NULL) ? 0b00001 : 0b00000) | (perspective_correct ? 0b10000 : 0xb00000);

    cmd.param |= texture_scale_x << 5;
    cmd.param |= texture_scale_y << 8;

    g_commands.push_back(cmd);
}

void clear() {
    Command cmd;
    // Clear framebuffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x00F333;
    g_commands.push_back(cmd);
    // Clear depth buffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x010000;
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
                                          FB_WIDTH * WINDOW_SCALE, FB_HEIGHT * WINDOW_SCALE, 0);

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    uint16_t* vram_data = new uint16_t[VRAM_SIZE];
    for (size_t i = 0; i < VRAM_SIZE; ++i) vram_data[i] = 0x0000;

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
                           wireframe, textured ? &dummy_texture : NULL, clamp_s, clamp_t, 3, 6, perspective_correct);

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

        if (top->vram_sel_o) {
            if (top->vram_addr_o < VRAM_SIZE) {

                if (top->vram_wr_o) {
                    vram_data[top->vram_addr_o] = top->vram_data_out_o;
                }
                top->vram_data_in_i = vram_data[top->vram_addr_o];
            } else {
                top->vram_data_in_i = 0xFF00;
            }
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
                uint16_t* d = &vram_data[2 * FB_WIDTH * FB_HEIGHT];
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
                memcpy(p, vram_data + top->front_addr_o, FB_WIDTH * FB_HEIGHT * 2);
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