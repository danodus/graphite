#ifndef SW_RASTERIZER_H
#define SW_RASTERIZER_H

#include "graphite.h"

typedef void (*draw_pixel_fn_t)(int x, int y, int color);

void sw_init_rasterizer(draw_pixel_fn_t draw_pixel_fn);

void sw_draw_triangle(fx32 x0, fx32 y0, fx32 x1, fx32 y1, fx32 x2, fx32 y2, int color);
void sw_draw_textured_triangle(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 x1, fx32 y1, fx32 z1, fx32 u1, fx32 v1,
                               fx32 x2, fx32 y2, fx32 z2, fx32 u2, fx32 v2, texture_t* tex);
#endif