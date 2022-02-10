#include <SDL.h>
#include <Vtop.h>
#include <verilated.h>

#include <deque>
#include <iostream>
#include <limits>

#define OP_NOP 0
#define OP_SET_X0 1
#define OP_SET_Y0 2
#define OP_SET_X1 3
#define OP_SET_Y1 4
#define OP_SET_COLOR 5
#define OP_CLEAR 6
#define OP_DRAW_LINE 7

struct Command {
    uint16_t opcode : 4;
    uint16_t param : 12;
};

void pulse_clk(Vtop* top) {
    top->contextp()->timeInc(1);
    top->clk = 1;
    top->eval();

    top->contextp()->timeInc(1);
    top->clk = 0;
    top->eval();
}

int main(int argc, char** argv, char** env) {
    SDL_Init(SDL_INIT_VIDEO);

    SDL_Window* window =
        SDL_CreateWindow("Graphite", SDL_WINDOWPOS_UNDEFINED_DISPLAY(1), SDL_WINDOWPOS_UNDEFINED, 640, 480, 0);

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    const size_t vram_size = 128 * 128;
    uint16_t* vram_data = new uint16_t[vram_size];
    for (size_t i = 0; i < vram_size; ++i) vram_data[i] = 0xFF00;

    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB4444, SDL_TEXTUREACCESS_STREAMING, 128, 128);

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

    Vtop* top = new Vtop{contextp.get(), "TOP"};

    top->reset_i = 1;
    pulse_clk(top);

    top->reset_i = 0;

    std::deque<Command> commands;
    Command c;
    c.opcode = OP_NOP;
    c.param = 0;
    commands.push_back(c);

    bool quit = false;
    while (!contextp->gotFinish() && !quit) {
        SDL_Event e;

        if (top->cmd_axis_tready_o) {
            while (SDL_PollEvent(&e)) {
                if (e.type == SDL_QUIT) {
                    quit = true;
                    continue;
                } else if (e.type == SDL_KEYUP) {
                    switch (e.key.keysym.sym) {
                        case SDLK_1:
                            c.opcode = OP_SET_COLOR;
                            c.param = 0x00F;
                            commands.push_back(c);
                            c.opcode = OP_CLEAR;
                            c.param = 0x000;
                            commands.push_back(c);
                            break;
                        case SDLK_2:
                            c.opcode = OP_SET_COLOR;
                            c.param = 0xFFF;
                            commands.push_back(c);
                            c.opcode = OP_SET_X0;
                            c.param = 10;
                            commands.push_back(c);
                            c.opcode = OP_SET_Y0;
                            c.param = 10;
                            commands.push_back(c);
                            c.opcode = OP_SET_X1;
                            c.param = 100;
                            commands.push_back(c);
                            c.opcode = OP_SET_Y1;
                            c.param = 50;
                            commands.push_back(c);
                            c.opcode = OP_DRAW_LINE;
                            c.param = 0;
                            commands.push_back(c);
                            break;
                    }
                }
            }
        }

        if (top->cmd_axis_tready_o) {
            if (commands.size() > 0) {
                auto c = commands.front();
                commands.pop_front();
                top->cmd_axis_tdata_i = (c.opcode << 12) | c.param;
                top->cmd_axis_tvalid_i = 1;
            }
        }

        if (top->vram_sel_o && top->vram_wr_o) {
            assert(top->vram_addr_o < 128 * 128);
            vram_data[top->vram_addr_o] = top->vram_data_out_o;
        }

        if (top->cmd_axis_tready_o) {
            void* p;
            int pitch;
            SDL_LockTexture(texture, NULL, &p, &pitch);
            assert(pitch == 128 * 2);
            memcpy(p, vram_data, 128 * 128 * 2);
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