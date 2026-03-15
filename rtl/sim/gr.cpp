#include "gr.h"

#include <SDL.h>
#include <Vtop.h>

#include <cstdint>
#include <cstdio>

#define _FLOAT_TO_FIXED(x, scale) ((int32_t)((x) * (float)(1 << scale)))
#define PARAM(x) (_FLOAT_TO_FIXED(x, 14))


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

typedef struct {
    float clearR, clearG, clearB;
    size_t bufferSize;
    void* bufferData;
} GrContext;

struct Command {
    uint32_t opcode : 8;
    uint32_t param : 24;
};

std::deque<Command> commands;

static VerilatedContext* contextp;
static Vtop* top;

SDL_Window* window;
SDL_Renderer* renderer;

SDL_Texture* texture;

uint16_t* vram_data;

GrContext ctx;

void (*displayFunc)(void) = nullptr;

static void pulse_clk(Vtop* top) {
    top->contextp()->timeInc(1);
    top->clk = 1;
    top->eval();

    top->contextp()->timeInc(1);
    top->clk = 0;
    top->eval();
}

double sc_time_stamp() { return 0; }

static void drawPoint(float x, float y)                      
{
    if (x < 0.0f || x >= 320.0f || y < 0.0f || y >= 240.0f)
        return;

    struct Command cmd;

    const float radius = 0.5f;

    cmd.opcode = OP_SET_X0;
    cmd.param = PARAM(x-radius) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(x-radius) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_Y0;
    cmd.param = PARAM(y) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(y) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_X1;
    cmd.param = PARAM(x) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(x) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_Y1;
    cmd.param = PARAM(y+radius) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(y+radius) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_X2;
    cmd.param = PARAM(x+radius) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(x+radius) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_Y2;
    cmd.param = PARAM(y) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(y) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_R0;
    cmd.param = PARAM(1.0f) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(1.0f) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_G0;
    cmd.param = PARAM(1.0f) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(1.0f) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_B0;
    cmd.param = PARAM(1.0f) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(1.0f) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_R1;
    cmd.param = PARAM(1.0f) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(1.0f) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_G1;
    cmd.param = PARAM(1.0f) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(1.0f) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_B1;
    cmd.param = PARAM(1.0f) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(1.0f) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_R2;
    cmd.param = PARAM(1.0f) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(1.0f) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_G2;
    cmd.param = PARAM(1.0f) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(1.0f) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_SET_B2;
    cmd.param = PARAM(1.0f) & 0xFFFF;
    commands.push_back(cmd);
    cmd.param = 0x10000 | (PARAM(1.0f) >> 16);
    commands.push_back(cmd);

    cmd.opcode = OP_DRAW;
    cmd.param = 0;

    commands.push_back(cmd);
}

void grutInit(const char* title) {
    SDL_Init(SDL_INIT_VIDEO);

    window = SDL_CreateWindow(title, SDL_WINDOWPOS_UNDEFINED_DISPLAY(1), SDL_WINDOWPOS_UNDEFINED,
                                          FB_WIDTH * WINDOW_SCALE, FB_HEIGHT * WINDOW_SCALE, 0);

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    vram_data = new uint16_t[VRAM_SIZE];
    for (size_t i = 0; i < VRAM_SIZE; ++i) vram_data[i] = 0x0000;

    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGB565, SDL_TEXTUREACCESS_STREAMING, FB_WIDTH, FB_HEIGHT);

    contextp = new VerilatedContext;

    top = new Vtop{contextp, "TOP"};

    top->clk = 0;
    top->eval();

    top->reset_i = 1;
    pulse_clk(top);
    top->reset_i = 0;
}

void grutSwapBuffers(void) {
    Command cmd;
    cmd.opcode = OP_SWAP;
    cmd.param = 0;
    commands.push_back(cmd);    
}

void grutDisplayFunc(void (*fn)(void)) {
    displayFunc = fn;
}

void grutMainLoop(void) {
    bool quit = false;
    while (!contextp->gotFinish() && !quit) {
        SDL_Event e;
        if (top->cmd_axis_tready_o && commands.size() == 0) {

            if (displayFunc)
                displayFunc();

            while (SDL_PollEvent(&e)) {
                if (e.type == SDL_QUIT) {
                    quit = true;
                    continue;
                }
            }
        }
        
        if (top->cmd_axis_tready_o) {
            if (commands.size() > 0) {
                auto c = commands.front();
                commands.pop_front();
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
                top->vram_data_in_i = 0xF800;
            }
        }

        if (top->swap_o) {
            void* p;
            int pitch;
            SDL_LockTexture(texture, NULL, &p, &pitch);
            assert(pitch == FB_WIDTH * 2);
            memcpy(p, vram_data + top->front_addr_o, FB_WIDTH * FB_HEIGHT * 2);
            SDL_UnlockTexture(texture);

            int draw_w, draw_h;
            SDL_GL_GetDrawableSize(window, &draw_w, &draw_h);

            SDL_Rect vga_r = {0, 0, draw_w, draw_h};
            SDL_RenderCopy(renderer, texture, NULL, &vga_r);

            SDL_RenderPresent(renderer);
        }
        
        pulse_clk(top);
        top->cmd_axis_tvalid_i = 0;
    }
}

void grClearColor(float red, float green, float blue) {
    ctx.clearR = red;
    ctx.clearG = green;
    ctx.clearB = blue;
}

void grClear(void) {
    Command cmd;
    // Clear framebuffer
    cmd.opcode = OP_CLEAR;
    uint32_t red = ctx.clearR * 0x1F;
    uint32_t green = ctx.clearG * 0x3F;
    uint32_t blue = ctx.clearB * 0x1F;
    cmd.param = (red << 11) | (green << 5) | blue;
    commands.push_back(cmd);
    // Clear depth buffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x010000;
    commands.push_back(cmd);    
}

void grBufferData(size_t bufferSize, void* data) {
    ctx.bufferSize = bufferSize;
    ctx.bufferData = malloc(bufferSize);
    memcpy(ctx.bufferData, data, bufferSize);
}

void grDrawArrays(int type) {
    size_t nbPoints = ctx.bufferSize / (3 * sizeof(float));
    float* f = (float *)ctx.bufferData;
    for (size_t i = 0; i < nbPoints; ++i) {
        float x = f[0];
        float y = f[1];

        x = -x;
        y = -y;
        x += 1.0f;
        y += 1.0f;
        x *= 320.0 / 2.0f;
        y *= 240.0 / 2.0f;
        if (type == GR_POINTS) {
            drawPoint(x, y);
        } else if (type == GR_TRIANGLES) {
            // TODO
        }
        f += 3;
    }
}