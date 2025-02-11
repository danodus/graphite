// sw_rasterizer_standard.c
// Copyright (c) 2021-2025 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "sw_rasterizer.h"

static int g_fb_width, g_fb_height;
static draw_pixel_fn_t g_draw_pixel_fn;

static fx32* g_depth_buffer;

typedef struct {
    int y0, y1, y2;
    int x0, x1;
    fx32 s0, t0, w0;
    fx32 s1, t1, w1;
    fx32 r0, g0, b0, a0;
    fx32 r1, g1, b1, a1;
    fx32 dax_step, dbx_step;
    fx32 ds0_step, dt0_step, dw0_step;
    fx32 ds1_step, dt1_step, dw1_step;
    fx32 dr0_step, dg0_step, db0_step, da0_step;
    fx32 dr1_step, dg1_step, db1_step, da1_step;
    bool bottom_half;
    bool tex;
    bool persp_correct;
    bool clamp_s, clamp_t;
    bool depth_test;
} rasterize_triangle_half_params_t;

void sw_init_rasterizer_standard(int fb_width, int fb_height, draw_pixel_fn_t draw_pixel_fn) {
    g_fb_width = fb_width;
    g_fb_height = fb_height;
    g_depth_buffer = (fx32*)malloc(fb_width * fb_height * sizeof(fx32));
    g_draw_pixel_fn = draw_pixel_fn;
}

void sw_dispose_rasterizer_standard() { free(g_depth_buffer); }

void sw_clear_depth_buffer_standard() { memset(g_depth_buffer, FX(0.0f), g_fb_width * g_fb_height * sizeof(fx32)); }

void swapi(int* a, int* b) {
    int t = *a;
    *a = *b;
    *b = t;
}

void swapf(fx32* a, fx32* b) {
    fx32 t = *a;
    *a = *b;
    *b = t;
}

void rasterize_triangle_half(bool bottom_half, rasterize_triangle_half_params_t* p) {
    int sy, ey, sx;
    fx32 ss, st, sw, sr, sg, sb, sa;

    if (bottom_half) {
        sy = p->y1;
        ey = p->y2;
        sx = p->x1;
        ss = p->s1;
        st = p->t1;
        sw = p->w1;
        sr = p->r1;
        sg = p->g1;
        sb = p->b1;
        sa = p->a1;
    } else {
        // top half
        sy = p->y0;
        ey = p->y1;
        sx = p->x0;
        ss = p->s0;
        st = p->t0;
        sw = p->w0;
        sr = p->r0;
        sg = p->g0;
        sb = p->b0;
        sa = p->a0;
    }

    for (int y = sy; y <= ey; y++) {
        int ax = INT(FXI(sx) + MUL(FXI(y - sy), p->dax_step));
        int bx = INT(FXI(p->x0) + MUL(FXI(y - p->y0), p->dbx_step));

        fx32 tex_ss = ss + MUL(FXI(y - sy), p->ds0_step);
        fx32 tex_st = st + MUL(FXI(y - sy), p->dt0_step);
        fx32 tex_sw = sw + MUL(FXI(y - sy), p->dw0_step);

        fx32 tex_es = p->s0 + MUL(FXI(y - p->y0), p->ds1_step);
        fx32 tex_et = p->t0 + MUL(FXI(y - p->y0), p->dt1_step);
        fx32 tex_ew = p->w0 + MUL(FXI(y - p->y0), p->dw1_step);

        fx32 col_sr = sr + MUL(FXI(y - sy), p->dr0_step);
        fx32 col_sg = sg + MUL(FXI(y - sy), p->dg0_step);
        fx32 col_sb = sb + MUL(FXI(y - sy), p->db0_step);
        fx32 col_sa = sa + MUL(FXI(y - sy), p->da0_step);

        fx32 col_er = p->r0 + MUL(FXI(y - p->y0), p->dr1_step);
        fx32 col_eg = p->g0 + MUL(FXI(y - p->y0), p->dg1_step);
        fx32 col_eb = p->b0 + MUL(FXI(y - p->y0), p->db1_step);
        fx32 col_ea = p->a0 + MUL(FXI(y - p->y0), p->da1_step);

        if (ax > bx) {
            swapi(&ax, &bx);
            swapf(&tex_ss, &tex_es);
            swapf(&tex_st, &tex_et);
            swapf(&tex_sw, &tex_ew);

            swapf(&col_sr, &col_er);
            swapf(&col_sg, &col_eg);
            swapf(&col_sb, &col_eb);
            swapf(&col_sa, &col_ea);
        }

        fx32 s = tex_ss;
        fx32 t = tex_st;
        fx32 z = tex_sw;

        fx32 r = col_sr;
        fx32 g = col_sg;
        fx32 b = col_sb;
        fx32 a = col_sa;

        fx32 tstep = FXI(bx - ax) > 0 ? DIV(FX(1.0f), FXI(bx - ax)) : 0;
        fx32 tt = FX(0.0f);

        for (int x = ax; x < bx; x++) {
            s = MUL(FX(1.0f) - tt, tex_ss) + MUL(tt, tex_es);
            t = MUL(FX(1.0f) - tt, tex_st) + MUL(tt, tex_et);
            z = MUL(FX(1.0f) - tt, tex_sw) + MUL(tt, tex_ew);

            r = MUL(FX(1.0f) - tt, col_sr) + MUL(tt, col_er);
            g = MUL(FX(1.0f) - tt, col_sg) + MUL(tt, col_eg);
            b = MUL(FX(1.0f) - tt, col_sb) + MUL(tt, col_eb);
            a = MUL(FX(1.0f) - tt, col_sa) + MUL(tt, col_ea);

            sw_fragment_shader(g_fb_width, g_fb_height, x, y, z, s, t, r, g, b, a, p->clamp_s, p->clamp_t, p->depth_test, p->tex, g_depth_buffer, p->persp_correct, g_draw_pixel_fn);

            tt += tstep;
        }
    }
}

void sw_draw_triangle_standard(fx32 x0, fx32 y0, fx32 w0, fx32 s0, fx32 t0, fx32 r0, fx32 g0, fx32 b0, fx32 a0,
                      fx32 x1, fx32 y1, fx32 w1, fx32 s1, fx32 t1, fx32 r1, fx32 g1, fx32 b1, fx32 a1,
                      fx32 x2, fx32 y2, fx32 w2, fx32 u2, fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2,
                      bool texture, bool clamp_s, bool clamp_t, bool depth_test, bool persp_correct) {
    int xx0 = INT(x0);
    int yy0 = INT(y0);
    int xx1 = INT(x1);
    int yy1 = INT(y1);
    int xx2 = INT(x2);
    int yy2 = INT(y2);

    if (yy1 < yy0) {
        swapi(&yy0, &yy1);
        swapi(&xx0, &xx1);
        swapf(&s0, &s1);
        swapf(&t0, &t1);
        swapf(&w0, &w1);
        swapf(&r0, &r1);
        swapf(&g0, &g1);
        swapf(&b0, &b1);
        swapf(&a0, &a1);
    }

    if (yy2 < yy0) {
        swapi(&yy0, &yy2);
        swapi(&xx0, &xx2);
        swapf(&s0, &u2);
        swapf(&t0, &v2);
        swapf(&w0, &w2);
        swapf(&r0, &r2);
        swapf(&g0, &g2);
        swapf(&b0, &b2);
        swapf(&a0, &a2);
    }

    if (yy2 < yy1) {
        swapi(&yy1, &yy2);
        swapi(&xx1, &xx2);
        swapf(&s1, &u2);
        swapf(&t1, &v2);
        swapf(&w1, &w2);
        swapf(&r1, &r2);
        swapf(&g1, &g2);
        swapf(&b1, &b2);
        swapf(&a1, &a2);
    }

    rasterize_triangle_half_params_t p;

    p.y0 = yy0;
    p.y1 = yy1;
    p.y2 = yy2;
    p.x0 = xx0;
    p.x1 = xx1;
    p.s0 = s0;
    p.t0 = t0;
    p.w0 = w0;
    p.s1 = s1;
    p.t1 = t1;
    p.w1 = w1;
    p.r0 = r0;
    p.g0 = g0;
    p.b0 = b0;
    p.a0 = a0;
    p.r1 = r1;
    p.g1 = g1;
    p.b1 = b1;
    p.a1 = a1;

    p.tex = texture;
    p.persp_correct = persp_correct;
    p.clamp_s = clamp_s;
    p.clamp_t = clamp_t;
    p.depth_test = depth_test;

    // rasterize top half

    int dy0 = yy1 - yy0;
    int dx0 = xx1 - xx0;
    fx32 dt0 = t1 - t0;
    fx32 ds0 = s1 - s0;
    fx32 dw0 = w1 - w0;

    fx32 dr0 = r1 - r0;
    fx32 dg0 = g1 - g0;
    fx32 db0 = b1 - b0;
    fx32 da0 = a1 - a0;

    int dy1 = yy2 - yy0;
    int dx1 = xx2 - xx0;
    fx32 dt1 = v2 - t0;
    fx32 ds1 = u2 - s0;
    fx32 dw1 = w2 - w0;

    fx32 dr1 = r2 - r0;
    fx32 dg1 = g2 - g0;
    fx32 db1 = b2 - b0;
    fx32 da1 = a2 - a0;

    if (dy0) p.dax_step = DIV(FXI(dx0), FXI(abs(dy0)));
    if (dy1) p.dbx_step = DIV(FXI(dx1), FXI(abs(dy1)));

    if (dy0) p.ds0_step = DIV(ds0, FXI(abs(dy0)));
    if (dy0) p.dt0_step = DIV(dt0, FXI(abs(dy0)));
    if (dy0) p.dw0_step = DIV(dw0, FXI(abs(dy0)));

    if (dy1) p.ds1_step = DIV(ds1, FXI(abs(dy1)));
    if (dy1) p.dt1_step = DIV(dt1, FXI(abs(dy1)));
    if (dy1) p.dw1_step = DIV(dw1, FXI(abs(dy1)));

    if (dy0) p.dr0_step = DIV(dr0, FXI(abs(dy0)));
    if (dy0) p.dg0_step = DIV(dg0, FXI(abs(dy0)));
    if (dy0) p.db0_step = DIV(db0, FXI(abs(dy0)));
    if (dy0) p.da0_step = DIV(da0, FXI(abs(dy0)));

    if (dy1) p.dr1_step = DIV(dr1, FXI(abs(dy1)));
    if (dy1) p.dg1_step = DIV(dg1, FXI(abs(dy1)));
    if (dy1) p.db1_step = DIV(db1, FXI(abs(dy1)));
    if (dy1) p.da1_step = DIV(da1, FXI(abs(dy1)));

    if (dy0) rasterize_triangle_half(false, &p);

    // rasterize bottom half

    dy0 = yy2 - yy1;
    dx0 = xx2 - xx1;
    dt0 = v2 - t1;
    ds0 = u2 - s1;
    dw0 = w2 - w1;

    dr0 = r2 - r1;
    dg0 = g2 - g1;
    db0 = b2 - b1;
    da0 = a2 - a1;

    if (dy0) p.dax_step = DIV(FXI(dx0), FXI(abs(dy0)));
    if (dy1) p.dbx_step = DIV(FXI(dx1), FXI(abs(dy1)));

    p.ds0_step = FX(0.0f), p.dt0_step = FX(0.0f);
    if (dy0) p.ds0_step = DIV(ds0, FXI(abs(dy0)));
    if (dy0) p.dt0_step = DIV(dt0, FXI(abs(dy0)));
    if (dy0) p.dw0_step = DIV(dw0, FXI(abs(dy0)));

    p.dr0_step = FX(0.0f), p.dg0_step = FX(0.0f), p.db0_step = FX(0.0f), p.da0_step = FX(0.0f);
    if (dy0) p.dr0_step = DIV(dr0, FXI(abs(dy0)));
    if (dy0) p.dg0_step = DIV(dg0, FXI(abs(dy0)));
    if (dy0) p.db0_step = DIV(db0, FXI(abs(dy0)));
    if (dy0) p.da0_step = DIV(da0, FXI(abs(dy0)));

    if (dy0) rasterize_triangle_half(true, &p);
}
