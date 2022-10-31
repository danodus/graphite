// glide.c
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#include "glide.h"

#include <SDL2/SDL.h>
#include <string.h>
#include <sw_rasterizer.h>

#define GLIDE_VERSION_STR "Glide Version 2.2"

static int screen_width = 320;
static int screen_height = 240;
static int screen_scale = 3;

static SDL_Renderer* renderer = NULL;
static SDL_Window* window = NULL;

static GrColor_t constant_color = 0x000000;

void draw_pixel(int x, int y, int color) {
    float r = (float)((color >> 8) & 0xF) / 15.0f;
    float g = (float)((color >> 4) & 0xF) / 15.0f;
    float b = (float)((color >> 0) & 0xF) / 15.0f;

    SDL_SetRenderDrawColor(renderer, r * 255, g * 255, b * 255, SDL_ALPHA_OPAQUE);
    SDL_RenderDrawPoint(renderer, x, y);
}

void xd_draw_triangle(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 r0, fx32 g0, fx32 b0, fx32 a0, fx32 x1, fx32 y1,
                      fx32 z1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1, fx32 x2, fx32 y2, fx32 z2, fx32 u2,
                      fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2, texture_t* tex, bool clamp_s, bool clamp_t,
                      bool depth_test) {
    sw_draw_triangle(x0, y0, z0, u0, v0, r0, g0, b0, a0, x1, y1, z1, u1, v1, r1, g1, b1, a1, x2, y2, z2, u2, v2, r2, g2,
                     b2, a2, tex, clamp_s, clamp_t, depth_test);
}

//
// Glide API
//

void grDrawPoint(const GrVertex* pt) {
    // fx32 a = FX((float)((constant_color >> 24) & 0xFF) / 255.0f);
    fx32 a = FX(1.0f);
    fx32 r = FX((float)((constant_color >> 16) & 0xFF) / 255.0f);
    fx32 g = FX((float)((constant_color >> 8) & 0xFF) / 255.0f);
    fx32 b = FX((float)(constant_color & 0xFF) / 255.0f);
    xd_draw_triangle(FX(pt->x + 1.0f), FX(pt->y), FX(1.0f), FX(0.0f), FX(0.0f), r, g, b, a, FX(pt->x), FX(pt->y),
                     FX(1.0f), FX(0.0f), FX(0.0f), r, g, b, a, FX(pt->x), FX(pt->y + 1.0f), FX(1.0f), FX(0.0f),
                     FX(0.0f), r, g, b, a, NULL, false, false, false);
}

void grBufferClear(GrColor_t color, GrAlpha_t alpha, FxU16 depth) {
    sw_clear_depth_buffer();
    SDL_SetRenderDrawColor(renderer, (color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF, alpha);
    SDL_RenderClear(renderer);
}

void grBufferSwap(int swap_interval) { SDL_RenderPresent(renderer); }

FxBool grSstWinOpen(FxU32 hwnd, GrScreenResolution_t res, GrScreenRefresh_t ref, GrColorFormat_t cformat,
                    GrOriginLocation_t org_loc, int num_buffers, int num_aux_buffers) {
    if (window || renderer) return FXFALSE;

    SDL_Init(SDL_INIT_VIDEO);

    window = SDL_CreateWindow("Glide Test", SDL_WINDOWPOS_CENTERED_DISPLAY(1), SDL_WINDOWPOS_UNDEFINED,
                              screen_width * screen_scale, screen_height * screen_scale, 0);

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    SDL_RenderSetScale(renderer, (float)screen_scale, (float)screen_scale);

    return FXTRUE;
}

void grSstWinClose() {
    if (window) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        sw_dispose_rasterizer();
    }
}

FxBool grSstQueryHardware(GrHwConfiguration* hwConfig) {
    if (hwConfig) {
        GrHwConfiguration hwc;
        hwConfig->num_sst = 1;
        GrGraphiteConfig_t gc;
        gc.fbRam = 16;
        hwConfig->SSTs[0].type = GR_SSTTYPE_GRAPHITE;
        hwConfig->SSTs[0].sstBoard.GraphiteConfig = gc;
        return FXTRUE;
    }
    return FXFALSE;
}

void grSstSelect(int which_sst) {}

void grGlideInit(void) { sw_init_rasterizer(screen_width, screen_height, draw_pixel); }

void grGlideGetVersion(char version[80]) { strcpy(version, GLIDE_VERSION_STR); }

void grColorCombine(GrCombineFunction_t func, GrCombineFactor_t factor, GrCombineLocal_t local, GrCombineOther_t other,
                    FxBool invert) {}
void grConstantColorValue(GrColor_t value) { constant_color = value; }