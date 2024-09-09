// sw_rasterizer.h
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef SW_RASTERIZER_H
#define SW_RASTERIZER_H

#include <stdbool.h>
#include <graphite.h>

typedef void (*draw_pixel_fn_t)(int x, int y, int color);

void sw_init_rasterizer_standard(int fb_width, int fb_height, draw_pixel_fn_t draw_pixel_fn);
void sw_dispose_rasterizer_standard();
void sw_clear_depth_buffer_standard();

void sw_init_rasterizer_barycentric(int fb_width, int fb_height, draw_pixel_fn_t draw_pixel_fn);
void sw_dispose_rasterizer_barycentric();
void sw_clear_depth_buffer_barycentric();

void sw_fragment_shader(int fb_width, int fb_height, int x, int y, fx32 z, fx32 u, fx32 v, fx32 r, fx32 g, fx32 b, fx32 a, bool clamp_s, bool clamp_t, bool depth_test, bool texture, fx32* depth_buffer, bool persp_correct, draw_pixel_fn_t draw_pixel_fn);

void sw_draw_triangle_standard(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 r0, fx32 g0, fx32 b0, fx32 a0,
                      fx32 x1, fx32 y1, fx32 z1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1,
                      fx32 x2, fx32 y2, fx32 z2, fx32 u2, fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2,
                      bool texture, bool clamp_s, bool clamp_t, bool depth_test, bool persp_correct);

void sw_draw_triangle_barycentric(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 r0, fx32 g0, fx32 b0, fx32 a0,
                      fx32 x1, fx32 y1, fx32 z1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1,
                      fx32 x2, fx32 y2, fx32 z2, fx32 u2, fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2,
                      bool texture, bool clamp_s, bool clamp_t, bool depth_test, bool persp_correct);

#endif  // SW_RASTERIZER_H