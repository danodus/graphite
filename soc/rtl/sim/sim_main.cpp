// sim_main.cpp
// Copyright (c) 2023-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <SDL.h>

#include <memory>
#include <chrono>
#include <deque>
#include <fstream>
#include <sstream>

#include <verilated.h>
#include <iostream>

// Include model header, generated from Verilating "top.v"
#include "Vtop.h"

#include "sdl_ps2.h"

#define SDRAM_MEM_SIZE (32*1024*1024/2)

const int screen_width = 1024;
const int screen_height = 768;

// 640x480
const int vga_width = 800;
const int vga_height = 525;

double sc_time_stamp()
{
    return 0.0;
}

int main(int argc, char **argv, char **env)
{
    SDL_Init(SDL_INIT_VIDEO);

    SDL_Window *window = SDL_CreateWindow(
        "Graphite SoC Simulation",
        SDL_WINDOWPOS_UNDEFINED_DISPLAY(1),
        SDL_WINDOWPOS_UNDEFINED,
        screen_width,
        screen_height,
        0);

    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    // Create logs/ directory in case we have traces to put under it
    Verilated::mkdir("logs");


    const size_t pixels_size = vga_width * vga_height * 4;
    unsigned char *pixels = new unsigned char[pixels_size];

    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING, vga_width, vga_height);

    uint16_t *sdram_mem = new uint16_t[SDRAM_MEM_SIZE];
    uint32_t sdram_rows[4] = {0, 0, 0, 0};  // 2^13 = 8192 rows per bank
    uint32_t sdram_col = 0; // 2^9 = 512 columns
    uint32_t sdram_addr = 0;
    uint8_t burst_counter = 0;

    bool restart_model;
    do {

        for (size_t i = 0; i < SDRAM_MEM_SIZE; ++i) {
            sdram_mem[i] =  (i >= SDRAM_MEM_SIZE / 2) ? 0x001F : 0x0000;
        }

        std::ifstream file("program.hex", std::ifstream::in);
        size_t addr = 0;
        std::string str;
        while (std::getline(file, str))
        {
            uint32_t v;
            std::stringstream ss;
            ss << std::hex << str;
            ss >> v;
            //sdram_mem[addr] = v >> 16;
            //sdram_mem[addr + 1] = v & 0xFFFF;
            sdram_mem[addr + 1] = v >> 16;
            sdram_mem[addr] = v & 0xFFFF;
            addr += 2;
        }

        // Construct a VerilatedContext to hold simulation time, etc.
        // Multiple modules (made later below with Vtop) may share the same
        // context to share time, or modules may have different contexts if
        // they should be independent from each other.

        // Using unique_ptr is similar to
        // "VerilatedContext* contextp = new VerilatedContext" then deleting at end.
        const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

        // Set debug level, 0 is off, 9 is highest presently used
        // May be overridden by commandArgs argument parsing
        contextp->debug(0);

        // Randomization reset policy
        // May be overridden by commandArgs argument parsing
        contextp->randReset(0);

        // Verilator must compute traced signals
        contextp->traceEverOn(true);

        // Pass arguments so Verilated code can see them, e.g. $value$plusargs
        // This needs to be called before you create any model
        contextp->commandArgs(argc, argv);

        restart_model = false;

        // Construct the Verilated model, from Vtop.h generated from Verilating "top.v".
        // Using unique_ptr is similar to "Vtop* top = new Vtop" then deleting at end.
        // "TOP" will be the hierarchical name of the module.
        const std::unique_ptr<Vtop> top{new Vtop{contextp.get(), "TOP"}};

        // Set Vtop's input signals
        top->reset_i = 1;
        top->clk = 0;

        SDL_Event e;
        bool quit = false;

        auto tp_frame = std::chrono::high_resolution_clock::now();
        auto tp_clk = std::chrono::high_resolution_clock::now();
        auto tp_now = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double> duration_clk;

        unsigned int frame_counter = 0;
        bool was_vsync = false;

        size_t pixel_index = 0;

        std::deque<uint8_t> ps2_keys;

        top->clk = 0;
        top->clk_sdram = 0;

        int clk_counter = 0;
        int delay_burst = 0;
        bool write_sdram = false;
        bool read_sdram = false;

        bool manual_reset = false;

        while (!contextp->gotFinish() && !quit)
        {
            bool toggle_clk = !(clk_counter & 0x1);
            bool toggle_clk_sdram = true;

            clk_counter++;

            if (!toggle_clk_sdram && !toggle_clk)
                continue;

            if (toggle_clk_sdram)
                top->clk_sdram = !top->clk_sdram;

            if (toggle_clk)
                top->clk = !top->clk;

            // if negedge clk sdram
            if (!top->clk_sdram) {

                if (!top->sdram_cs_n_o) {
                    // activate
                    uint32_t sdram_bank = top->sdram_ba_o;
                    if (!top->sdram_ras_n_o && top->sdram_cas_n_o && top->sdram_we_n_o) {
                        sdram_rows[sdram_bank] = top->sdram_a_o;
                        //printf("ACT bank=%d, row=%d\n", sdram_bank, sdram_rows[sdram_bank]);
                    }
                    uint32_t sdram_row = sdram_rows[sdram_bank];
                    if (top->sdram_ras_n_o && !top->sdram_cas_n_o) {
                        // read or write
                        sdram_col = top->sdram_a_o & 0x1FF;
                        sdram_addr = 8192 * 512 * sdram_bank + 512 * sdram_row + sdram_col;
                        assert(sdram_addr < 8192 * 512 * 4);
                        if (!top->sdram_we_n_o) {
                            // Write
                            //printf("WRITE bank=%d, row=%d, col=%d (addr=0x%x), mask=%d\n", sdram_bank, sdram_row, sdram_col, sdram_addr*2, ~top->sdram_dqm_o & 0x03);
                            burst_counter = 0;
                            delay_burst = 0;
                            write_sdram = true;
                        } else {
                            // Read
                            //printf("READ bank=%d, row=%d, col=%d (addr=0x%x)\n", sdram_bank, sdram_row, sdram_col, sdram_addr*2);
                            burst_counter = 0;
                            delay_burst = 3;
                            read_sdram = true;
                        }
                    }

                    if (top->sdram_ras_n_o && top->sdram_cas_n_o && !top->sdram_we_n_o) {
                        // end of burst
                        //printf("EOB\n");
                        write_sdram = false;
                        //read_sdram = false;
                    }
                }

                uint32_t addr = sdram_addr + burst_counter;
                assert(addr < 8192 * 512 * 4);
                uint8_t mask = ~top->sdram_dqm_o & 0x03;

                if (write_sdram) {
                    //printf("Write %x at addr %x (%d), mask=%x\n", top->sdram_dq_io, addr*2, burst_counter, mask);
                    switch (mask) {
                        case 0:
                            break;
                        case 1:
                            sdram_mem[addr] = (sdram_mem[addr] & 0xFF00) | (top->sdram_dq_io & 0x00FF);
                            break;
                        case 2:
                            sdram_mem[addr] = (sdram_mem[addr] & 0x00FF) | (top->sdram_dq_io & 0xFF00);
                            break;
                        case 3:
                            sdram_mem[addr] = top->sdram_dq_io;
                            break;
                    } 
                } else if (read_sdram) {
                    //printf("Read at addr %x (%d), mask=%x (%x)\n", addr*2, burst_counter, mask, sdram_mem[addr]);
                    top->sdram_dq_io = sdram_mem[addr];
                }

                if (read_sdram || write_sdram) {
                    if (delay_burst == 0) {
                        if (burst_counter < 127)
                            burst_counter++;
                    } else {
                        delay_burst--;
                    }
                }
            }

            // if posedge clk
            if (toggle_clk && top->clk) {
                
                if (top->ps2_kbd_strobe_i) {
                    top->ps2_kbd_strobe_i = 0;

                } else {
                    if (ps2_keys.size() > 0) {
                        top->ps2_kbd_code_i = ps2_keys.back();
                        top->ps2_kbd_strobe_i = 1;
                        ps2_keys.pop_back();
                    }
                }

                if (manual_reset) {
                    top->reset_i = 1;
                } else {
                    if (contextp->time() > 1 && contextp->time() < 10) {
                        top->reset_i = 1; // Assert reset
                    } else {
                        top->reset_i = 0; // Deassert reset
                    }
                }

                // Update video display
                if (was_vsync && top->vga_vsync)
                {
                    pixel_index = 0;
                    was_vsync = false;
                }

                pixels[pixel_index] = top->vga_r;
                pixels[pixel_index + 1] = top->vga_g;
                pixels[pixel_index + 2] = top->vga_b;
                pixels[pixel_index + 3] = 255;
                pixel_index = (pixel_index + 4) % (pixels_size);

                if (!top->vga_vsync && !was_vsync)
                {
                    was_vsync = true;
                    void *p;
                    int pitch;
                    SDL_LockTexture(texture, NULL, &p, &pitch);
                    assert(pitch == vga_width * 4);
                    memcpy(p, pixels, vga_width * vga_height * 4);
                    SDL_UnlockTexture(texture);
                }
            }

            tp_now = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double> duration_frame = tp_now - tp_frame;

            if (contextp->time() % 2000000 == 0)
            {
                duration_clk = tp_now - tp_clk;
                tp_clk = tp_now;
            }

            if (duration_frame.count() >= 1.0 / 60.0)
            {
                while (SDL_PollEvent(&e))
                {
                    if (e.type == SDL_QUIT)
                    {
                        quit = true;
                    }
                    else if (e.type == SDL_KEYUP)
                    {
                        switch (e.key.keysym.sym)
                        {
                        case SDLK_F1:
                            std::cout << "Reset released\n";
                            manual_reset = false;
                            break;
                        case SDLK_F12:
                            quit = true;
                            restart_model = true;
                            break;
                        default:
                            {
                                uint8_t out[MAX_PS2_CODE_LEN];
                                int n = ps2_encode(e.key.keysym.scancode, false, out);
                                for (int i = 0; i < n; ++i)
                                    ps2_keys.emplace_front(out[i]);
                                break;
                            }
                        }
                    }
                    else if (e.type == SDL_KEYDOWN)
                    {
                        if (e.key.repeat == 0)
                        {
                            switch (e.key.keysym.sym)
                            {
                            case SDLK_F1:
                                std::cout << "Reset pressed\n";
                                manual_reset = true;
                                break;                                
                            case SDLK_F12:
                                std::cout << "Reset context\n";
                                break;
                            default:
                                {
                                    uint8_t out[MAX_PS2_CODE_LEN];
                                    int n = ps2_encode(e.key.keysym.scancode, true, out);
                                    for (int i = 0; i < n; ++i)
                                        ps2_keys.emplace_front(out[i]);
                                    break;
                                }
                            }
                        }
                    }
                }

                int draw_w, draw_h;
                SDL_GL_GetDrawableSize(window, &draw_w, &draw_h);

                int scale_x, scale_y;
                scale_x = draw_w / screen_width;
                scale_y = draw_h / screen_height;

                SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
                SDL_RenderClear(renderer);

                if (frame_counter % 100 == 0)
                {
                    std::cout << "Clk speed: " << 1.0 / (duration_clk.count()) << " MHz\n";
                }

                tp_frame = tp_now;
                frame_counter++;

                // Read outputs
                //VL_PRINTF("[%" VL_PRI64 "d] clk=%x rstl=%x led=%02x\n",
                //          contextp->time(), top->clk, top->reset_l, top->led);

                SDL_Rect vga_r = {0, scale_x * (screen_height - vga_height - 1), scale_x * vga_width, scale_y * vga_height};
                SDL_RenderCopy(renderer, texture, NULL, &vga_r);

                int x = 0;
                int y = 0;
                for (int i = 7; i >= 0; --i)
                {
                    SDL_Rect r{scale_x * x, scale_y * y, scale_x * 50, scale_y * 50};
                    SDL_SetRenderDrawColor(renderer, 30, (top->display_o >> i) & 1 ? 255 : 30, 30, 255);
                    SDL_RenderFillRect(renderer, &r);
                    x += 60;
                }

                SDL_RenderPresent(renderer);
            }

            contextp->timeInc(1);
            top->eval();

            //if (contextp->time() > 20000)
            //    quit = true;            

        }

        // Final model cleanup
        top->final();
    } while (restart_model);

    delete[] sdram_mem;

    SDL_DestroyTexture(texture);

    delete[] pixels;

    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
