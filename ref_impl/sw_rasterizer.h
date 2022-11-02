// sw_rasterizer.h
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef SW_RASTERIZER_H
#define SW_RASTERIZER_H

#include <fx.h>
#include <stdbool.h>

typedef void (*draw_pixel_fn_t)(int x, int y, int color);

void sw_init_rasterizer(int fb_width, int fb_height, draw_pixel_fn_t draw_pixel_fn);
void sw_dispose_rasterizer();

void sw_clear_depth_buffer();

void sw_draw_triangle(rfx32 x0, rfx32 y0, rfx32 z0, rfx32 u0, rfx32 v0, rfx32 r0, rfx32 g0, rfx32 b0, rfx32 a0,
                      rfx32 x1, rfx32 y1, rfx32 z1, rfx32 u1, rfx32 v1, rfx32 r1, rfx32 g1, rfx32 b1, rfx32 a1,
                      rfx32 x2, rfx32 y2, rfx32 z2, rfx32 u2, rfx32 v2, rfx32 r2, rfx32 g2, rfx32 b2, rfx32 a2,
                      bool texture, bool clamp_s, bool clamp_t, bool depth_test);
#endif  // SW_RASTERIZER_H