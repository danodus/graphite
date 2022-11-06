// glide.c
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#include "glide.h"

#include <stdbool.h>
#include <string.h>

#if GLIDE_SDL
#include <SDL2/SDL.h>

#include "sw_rasterizer.h"
#endif

#define GLIDE_VERSION_STR "Glide Version 2.2"

void xd_draw_triangle(rfx32 x0, rfx32 y0, rfx32 z0, rfx32 u0, rfx32 v0, rfx32 r0, rfx32 g0, rfx32 b0, rfx32 a0,
                      rfx32 x1, rfx32 y1, rfx32 z1, rfx32 u1, rfx32 v1, rfx32 r1, rfx32 g1, rfx32 b1, rfx32 a1,
                      rfx32 x2, rfx32 y2, rfx32 z2, rfx32 u2, rfx32 v2, rfx32 r2, rfx32 g2, rfx32 b2, rfx32 a2,
                      bool texture, bool clamp_s, bool clamp_t, bool depth_test, bool persp_correct);

static GrVertex vectorAdd(const GrVertex* v1, const GrVertex* v2) {
    GrVertex r = {v1->x + v2->x, v1->y + v2->y, v1->z + v2->z};
    return r;
}

static GrVertex vectorSub(const GrVertex* v1, const GrVertex* v2) {
    GrVertex r = {v1->x - v2->x, v1->y - v2->y, v1->z - v2->z};
    return r;
}

static GrVertex vectorMul(const GrVertex* v1, float k) {
    GrVertex r = {MUL(v1->x, k), MUL(v1->y, k), MUL(v1->z, k)};
    return r;
}

static fx32 vectorDotProduct(const GrVertex* v1, const GrVertex* v2) {
    return MUL(v1->x, v2->x) + MUL(v1->y, v2->y) + MUL(v1->z, v2->z);
}

static fx32 vectorLength(const GrVertex* v) { return SQRT(vectorDotProduct(v, v)); }

static GrVertex vectorNormalize(const GrVertex* v) {
    fx32 l = vectorLength(v);
    if (l > FX(0.0f)) {
        GrVertex r = {DIV(v->x, l), DIV(v->y, l), DIV(v->z, l)};
        return r;
    } else {
        GrVertex r = {FX(0.0f), FX(0.0f), FX(0.0f)};
        return r;
    }
}

static int screen_width = 320;
static int screen_height = 240;
static int screen_scale = 3;
static GrTexInfo* tex_info = NULL;

#if GLIDE_SDL
static SDL_Renderer* renderer = NULL;
static SDL_Window* window = NULL;
#endif  // GLIDE_SDL

static GrCombineLocal_t combine_local = GR_COMBINE_LOCAL_ITERATED;
static GrColor_t constant_color = 0x000000;
static GrDepthBufferMode_t depth_buffer_mode = GR_DEPTHBUFFER_DISABLE;
static FxBool depth_mask = FXFALSE;

#if GLIDE_SDL
void draw_pixel(int x, int y, int color) {
    float r = (float)((color >> 8) & 0xF) / 15.0f;
    float g = (float)((color >> 4) & 0xF) / 15.0f;
    float b = (float)((color >> 0) & 0xF) / 15.0f;

    SDL_SetRenderDrawColor(renderer, r * 255, g * 255, b * 255, SDL_ALPHA_OPAQUE);
    SDL_RenderDrawPoint(renderer, x, y);
}
#endif  // GLIDE_SDL

#if GLIDE_SDL
void xd_draw_triangle(rfx32 x0, rfx32 y0, rfx32 z0, rfx32 u0, rfx32 v0, rfx32 r0, rfx32 g0, rfx32 b0, rfx32 a0,
                      rfx32 x1, rfx32 y1, rfx32 z1, rfx32 u1, rfx32 v1, rfx32 r1, rfx32 g1, rfx32 b1, rfx32 a1,
                      rfx32 x2, rfx32 y2, rfx32 z2, rfx32 u2, rfx32 v2, rfx32 r2, rfx32 g2, rfx32 b2, rfx32 a2,
                      bool texture, bool clamp_s, bool clamp_t, bool depth_test, bool persp_correct) {
    sw_draw_triangle(x0, y0, z0, u0, v0, r0, g0, b0, a0, x1, y1, z1, u1, v1, r1, g1, b1, a1, x2, y2, z2, u2, v2, r2, g2,
                     b2, a2, texture, clamp_s, clamp_t, depth_test, persp_correct);
}
#endif  // GLIDE_SDL

//
// Glide API
//

void grDrawPoint(const GrVertex* pt) {
    fx32 r = FXI((constant_color >> 16) & 0xFF);
    fx32 g = FXI((constant_color >> 8) & 0xFF);
    fx32 b = FXI(constant_color & 0xFF);
    fx32 a = FX(255.0f);
    xd_draw_triangle(RFXP(pt->x + FX(1.0f)), RFXP(pt->y), RFXP(FX(1.0f)), RFXP(FX(0.0f)), RFXP(FX(0.0f)),
                     RFXP(DIV(r, FX(255.0f))), RFXP(DIV(g, FX(255.0f))), RFXP(DIV(b, FX(255.0f))),
                     RFXP(DIV(a, FX(255.0f))), RFXP(pt->x), RFXP(pt->y), RFXP(FX(1.0f)), RFXP(FX(0.0f)), RFXP(FX(0.0f)),
                     RFXP(DIV(r, FX(255.0f))), RFXP(DIV(g, FX(255.0f))), RFXP(DIV(b, FX(255.0f))),
                     RFXP(DIV(a, FX(255.0f))), RFXP(pt->x), RFXP(pt->y + FX(1.0f)), RFXP(FX(1.0f)), RFXP(FX(0.0f)),
                     RFXP(FX(0.0f)), RFXP(DIV(r, FX(255.0f))), RFXP(DIV(g, FX(255.0f))), RFXP(DIV(b, FX(255.0f))),
                     RFXP(DIV(a, FX(255.0f))), false, false, false, false, false);
}

void grDrawLine(const GrVertex* a, const GrVertex* b) {
    // skip if zero length
    if (a->x == b->x && a->y == b->y) return;

    // define the line between the two points
    GrVertex line = vectorSub(b, a);

    // find the normal vector of this line
    GrVertex normal = (GrVertex){-line.y, line.x, FX(0.0f)};
    normal = vectorNormalize(&normal);

    GrVertex miter = vectorMul(&normal, FX(0.5f));

    GrVertex vv0 = vectorAdd(a, &miter);
    GrVertex vv1 = vectorSub(a, &miter);
    GrVertex vv2 = vectorAdd(b, &miter);
    GrVertex vv3 = vectorSub(b, &miter);

    GrVertex c0, c1;

    if (combine_local == GR_COMBINE_LOCAL_CONSTANT) {
        c0.r = FXI((constant_color >> 16) & 0xFF);
        c0.g = FXI((constant_color >> 8) & 0xFF);
        c0.b = FXI(constant_color & 0xFF);
        c0.a = FX(255.0f);
        c1 = c0;
    } else {
        c0.r = a->r, c0.g = a->g, c0.b = a->b, c0.a = FX(255.0f);
        c1.r = b->r, c1.g = b->g, c1.b = b->b, c1.a = FX(255.0f);
    }

    fx32 z[4] = {FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)};

    if (tex_info != NULL) {
        z[0] = a->oow;
        z[1] = a->oow;
        z[2] = b->oow;
        z[3] = b->oow;
    } else if (depth_buffer_mode == GR_DEPTHBUFFER_ZBUFFER) {
        z[0] = DIV(a->ooz, FX(65535.0f));
        z[1] = DIV(a->ooz, FX(65535.0f));
        z[2] = DIV(b->ooz, FX(65535.0f));
        z[3] = DIV(b->ooz, FX(65535.0f));
    }

    xd_draw_triangle(RFXP(vv0.x), RFXP(vv0.y), RFXP(z[0]), RFXP(DIV(a->tmuvtx->sow, FX(255.0f))),
                     RFXP(DIV(a->tmuvtx->tow, FX(255.0f))), RFXP(DIV(c0.r, FX(255.0f))), RFXP(DIV(c0.g, FX(255.0f))),
                     RFXP(DIV(c0.b, FX(255.0f))), RFXP(DIV(c0.a, FX(255.0f))), RFXP(vv2.x), RFXP(vv2.y), RFXP(z[2]),
                     RFXP(DIV(b->tmuvtx->sow, FX(255.0f))), RFXP(DIV(b->tmuvtx->tow, FX(255.0f))),
                     RFXP(DIV(c1.r, FX(255.0f))), RFXP(DIV(c1.g, FX(255.0f))), RFXP(DIV(c1.b, FX(255.0f))),
                     RFXP(DIV(c1.a, FX(255.0f))), RFXP(vv3.x), RFXP(vv3.y), RFXP(z[3]),
                     RFXP(DIV(b->tmuvtx->sow, FX(255.0f))), RFXP(DIV(b->tmuvtx->tow, FX(255.0f))),
                     RFXP(DIV(c1.r, FX(255.0f))), RFXP(DIV(c1.g, FX(255.0f))), RFXP(DIV(c1.b, FX(255.0f))),
                     RFXP(DIV(c1.a, FX(255.0f))), tex_info != NULL, true, true, false, true);
    xd_draw_triangle(RFXP(vv1.x), RFXP(vv1.y), RFXP(z[1]), RFXP(DIV(a->tmuvtx->sow, FX(255.0f))),
                     RFXP(DIV(a->tmuvtx->tow, FX(255.0f))), RFXP(DIV(c0.r, FX(255.0f))), RFXP(DIV(c0.g, FX(255.0f))),
                     RFXP(DIV(c0.b, FX(255.0f))), RFXP(DIV(c0.a, FX(255.0f))), RFXP(vv0.x), RFXP(vv0.y), RFXP(z[0]),
                     RFXP(DIV(a->tmuvtx->sow, FX(255.0f))), RFXP(DIV(a->tmuvtx->tow, FX(255.0f))),
                     RFXP(DIV(c0.r, FX(255.0f))), RFXP(DIV(c0.g, FX(255.0f))), RFXP(DIV(c0.b, FX(255.0f))),
                     RFXP(DIV(c0.a, FX(255.0f))), RFXP(vv3.x), RFXP(vv3.y), RFXP(z[3]),
                     RFXP(DIV(b->tmuvtx->sow, FX(255.0f))), RFXP(DIV(b->tmuvtx->tow, FX(255.0f))),
                     RFXP(DIV(c1.r, FX(255.0f))), RFXP(DIV(c1.g, FX(255.0f))), RFXP(DIV(c1.b, FX(255.0f))),
                     RFXP(DIV(c1.a, FX(255.0f))), tex_info != NULL, true, true, false, true);
}

void grDrawTriangle(const GrVertex* a, const GrVertex* b, const GrVertex* c) {
    GrVertex c0, c1, c2;

    /*
    if (tex_info != NULL) {
        fx32 cc0 = MUL(FX(255.0f), a->oow);
        fx32 cc1 = MUL(FX(255.0f), b->oow);
        fx32 cc2 = MUL(FX(255.0f), c->oow);
        c0.r = cc0, c0.g = cc0, c0.b = cc0, c0.a = cc0;
        c1.r = cc1, c1.g = cc1, c1.b = cc1, c1.a = cc1;
        c2.r = cc2, c2.g = cc2, c2.b = cc2, c2.a = cc2;
    } else*/
    if (combine_local == GR_COMBINE_LOCAL_CONSTANT) {
        c0.r = FXI((constant_color >> 16) & 0xFF);
        c0.g = FXI((constant_color >> 8) & 0xFF);
        c0.b = FXI(constant_color & 0xFF);
        c0.a = FX(255.0f);
        c1 = c0;
        c2 = c0;
    } else {
        // GR_COMBINE_LOCAL_ITERATED
        c0.r = a->r, c0.g = a->g, c0.b = a->b, c0.a = FX(255.0f);
        c1.r = b->r, c1.g = b->g, c1.b = b->b, c1.a = FX(255.0f);
        c2.r = c->r, c2.g = c->g, c2.b = c->b, c2.a = FX(255.0f);
    }

    fx32 z[3] = {FX(1.0f), FX(1.0f), FX(1.0f)};

    if (tex_info != NULL) {
        z[0] = a->oow;
        z[1] = b->oow;
        z[2] = c->oow;
    } else if (depth_buffer_mode == GR_DEPTHBUFFER_ZBUFFER) {
        z[0] = DIV(a->ooz, FX(65535.0f));
        z[1] = DIV(b->ooz, FX(65535.0f));
        z[2] = DIV(c->ooz, FX(65535.0f));
    }

    xd_draw_triangle(RFXP(a->x), RFXP(a->y), RFXP(z[0]), RFXP(DIV(a->tmuvtx->sow, FX(255.0f))),
                     RFXP(DIV(a->tmuvtx->tow, FX(255.0f))), RFXP(DIV(c0.r, FX(255.0f))), RFXP(DIV(c0.g, FX(255.0f))),
                     RFXP(DIV(c0.b, FX(255.0f))), RFXP(DIV(c0.a, FX(255.0f))), RFXP(b->x), RFXP(b->y), RFXP(z[1]),
                     RFXP(DIV(b->tmuvtx->sow, FX(255.0f))), RFXP(DIV(b->tmuvtx->tow, FX(255.0f))),
                     RFXP(DIV(c1.r, FX(255.0f))), RFXP(DIV(c1.g, FX(255.0f))), RFXP(DIV(c1.b, FX(255.0f))),
                     RFXP(DIV(c1.a, FX(255.0f))), RFXP(c->x), RFXP(c->y), RFXP(z[2]),
                     RFXP(DIV(c->tmuvtx->sow, FX(255.0f))), RFXP(DIV(c->tmuvtx->tow, FX(255.0f))),
                     RFXP(DIV(c2.r, FX(255.0f))), RFXP(DIV(c2.g, FX(255.0f))), RFXP(DIV(c2.b, FX(255.0f))),
                     RFXP(DIV(c2.a, FX(255.0f))), tex_info != NULL, true, true, true, true);
}

void grBufferClear(GrColor_t color, GrAlpha_t alpha, FxU16 depth) {
#if GLIDE_SDL
    sw_clear_depth_buffer();
    SDL_SetRenderDrawColor(renderer, (color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF, alpha);
    SDL_RenderClear(renderer);
#endif  // GLIDE_SDL
}

void grBufferSwap(int swap_interval) {
#if GLIDE_SDL
    SDL_RenderPresent(renderer);
#endif  // GLIDE_SDL
}

FxBool grSstWinOpen(FxU32 hwnd, GrScreenResolution_t res, GrScreenRefresh_t ref, GrColorFormat_t cformat,
                    GrOriginLocation_t org_loc, int num_buffers, int num_aux_buffers) {
#if GLIDE_SDL
    if (window || renderer) return FXFALSE;
    SDL_Init(SDL_INIT_VIDEO);

    window = SDL_CreateWindow("Glide", SDL_WINDOWPOS_CENTERED_DISPLAY(1), SDL_WINDOWPOS_UNDEFINED,
                              screen_width * screen_scale, screen_height * screen_scale, 0);

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    SDL_RenderSetScale(renderer, (float)screen_scale, (float)screen_scale);
#endif  // GLIDE_SDL

    return FXTRUE;
}

void grSstWinClose() {
#if GLIDE_SDL
    if (window) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        sw_dispose_rasterizer();
    }
#endif  // GLIDE_SDL
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

void grGlideInit(void) {
#if GLIDE_SDL
    sw_init_rasterizer(screen_width, screen_height, draw_pixel);
#endif  // GLIDE_SDL
}

void grGlideGetVersion(char version[80]) { strcpy(version, GLIDE_VERSION_STR); }

void grColorCombine(GrCombineFunction_t func, GrCombineFactor_t factor, GrCombineLocal_t local, GrCombineOther_t other,
                    FxBool invert) {
    combine_local = local;
}

void grConstantColorValue(GrColor_t value) { constant_color = value; }

void grDepthBufferFunction(GrCmpFnc_t function) {}
void grDepthBufferMode(GrDepthBufferMode_t mode) { depth_buffer_mode = mode; }
void grDepthMask(FxBool mask) { depth_mask = mask; }

FxU32 grTexMinAddress(GrChipID_t tmu) { return 0; }
void grTexSource(GrChipID_t tmu, FxU32 startAddress, FxU32 evenOdd, GrTexInfo* info) { tex_info = info; }
void grTexCombine(GrChipID_t tmu, GrCombineFunction_t rgb_function, GrCombineFactor_t rgb_factor,
                  GrCombineFunction_t alpha_function, GrCombineFactor_t alpha_factor, FxBool rgb_invert,
                  FxBool alpha_invert) {}
void grTexFilterMode(GrChipID_t tmu, GrTextureFilterMode_t minfilter_mode, GrTextureFilterMode_t magfilter_mode) {}
void grTexDownloadMipMap(GrChipID_t tmu, FxU32 startAddress, FxU32 evenOdd, GrTexInfo* info) {}
void grTexMipMapMode(GrChipID_t tmu, GrMipMapMode_t mode, FxBool lodBlend) {}
