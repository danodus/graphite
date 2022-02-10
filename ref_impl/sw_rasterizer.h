#ifndef SW_RASTERIZER_H
#define SW_RASTERIZER_H

#include "graphite.h"

typedef void (*draw_pixel_fn_t)(int x, int y, int color);

void sw_init_rasterizer(draw_pixel_fn_t draw_pixel_fn);

void sw_draw_line(int x0, int y0, int x1, int y1, int color);
void sw_draw_triangle(int x0, int y0, int x1, int y1, int x2, int y2, int color);
void sw_draw_filled_triangle(int x0, int y0, int x1, int y1, int x2, int y2, int color);
void sw_draw_filled_rectangle(int x0, int y0, int x1, int y1, int color);
void sw_draw_textured_triangle(int x0, int y0, fx32 u0, fx32 v0, int x1, int y1, fx32 u1, fx32 v1, int x2, int y2,
                               fx32 u2, fx32 v2, texture_t* tex);
#endif