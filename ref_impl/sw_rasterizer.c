#include "sw_rasterizer.h"

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    fx32 r, g, b, a;
} color_t;

int g_fb_width, g_fb_height;
static draw_pixel_fn_t g_draw_pixel_fn;

fx32* g_depth_buffer;

void sw_init_rasterizer(int fb_width, int fb_height, draw_pixel_fn_t draw_pixel_fn) {
    g_fb_width = fb_width;
    g_fb_height = fb_height;
    g_depth_buffer = (fx32*)malloc(fb_width * fb_height * sizeof(fx32));
    g_draw_pixel_fn = draw_pixel_fn;
}

void sw_dispose_rasterizer() { free(g_depth_buffer); }

void sw_clear_depth_buffer() { memset(g_depth_buffer, FX(0.0f), g_fb_width * g_fb_height * sizeof(fx32)); }

color_t texture_sample_color(bool texture, fx32 u, fx32 v) {
    if (texture) {
        if (u < FX(0.5) && v < FX(0.5)) return (color_t){FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)};
        if (u >= FX(0.5) && v < FX(0.5)) return (color_t){FX(1.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
        if (u < FX(0.5) && v >= FX(0.5)) return (color_t){FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)};
        return (color_t){FX(0.0f), FX(0.0f), FX(1.0f), FX(1.0f)};
    }
    return (color_t){FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)};
}

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

void sw_draw_triangle(fx32 x1a, fx32 y1a, fx32 w1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1, fx32 x2a,
                      fx32 y2a, fx32 w2, fx32 u2, fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2, fx32 x3a, fx32 y3a,
                      fx32 w3, fx32 u3, fx32 v3, fx32 r3, fx32 g3, fx32 b3, fx32 a3, bool texture, bool clamp_s,
                      bool clamp_t, bool depth_test) {
    int x1 = INT(x1a);
    int y1 = INT(y1a);
    int x2 = INT(x2a);
    int y2 = INT(y2a);
    int x3 = INT(x3a);
    int y3 = INT(y3a);

    if (y2 < y1) {
        swapi(&y1, &y2);
        swapi(&x1, &x2);
        swapf(&u1, &u2);
        swapf(&v1, &v2);
        swapf(&w1, &w2);
        swapf(&r1, &r2);
        swapf(&g1, &g2);
        swapf(&b1, &b2);
        swapf(&a1, &a2);
    }

    if (y3 < y1) {
        swapi(&y1, &y3);
        swapi(&x1, &x3);
        swapf(&u1, &u3);
        swapf(&v1, &v3);
        swapf(&w1, &w3);
        swapf(&r1, &r3);
        swapf(&g1, &g3);
        swapf(&b1, &b3);
        swapf(&a1, &a3);
    }

    if (y3 < y2) {
        swapi(&y2, &y3);
        swapi(&x2, &x3);
        swapf(&u2, &u3);
        swapf(&v2, &v3);
        swapf(&w2, &w3);
        swapf(&r2, &r3);
        swapf(&g2, &g3);
        swapf(&b2, &b3);
        swapf(&a2, &a3);
    }

    int dy1 = y2 - y1;
    int dx1 = x2 - x1;
    fx32 dv1 = v2 - v1;
    fx32 du1 = u2 - u1;
    fx32 dw1 = w2 - w1;

    fx32 dr1 = r2 - r1;
    fx32 dg1 = g2 - g1;
    fx32 db1 = b2 - b1;
    fx32 da1 = a2 - a1;

    int dy2 = y3 - y1;
    int dx2 = x3 - x1;
    fx32 dv2 = v3 - v1;
    fx32 du2 = u3 - u1;
    fx32 dw2 = w3 - w1;

    fx32 dr2 = r3 - r1;
    fx32 dg2 = g3 - g1;
    fx32 db2 = b3 - b1;
    fx32 da2 = a3 - a1;

    fx32 tex_u, tex_v, tex_w;
    fx32 col_r, col_g, col_b, col_a;

    fx32 dax_step = 0, dbx_step = 0;
    fx32 du1_step = 0, dv1_step = 0, du2_step = 0, dv2_step = 0, dw1_step = 0, dw2_step = 0;
    fx32 dr1_step = 0, dg1_step = 0, db1_step = 0, da1_step = 0, dr2_step = 0, dg2_step = 0, db2_step = 0, da2_step = 0;

    if (dy1) dax_step = DIV(FXI(dx1), FXI(abs(dy1)));
    if (dy2) dbx_step = DIV(FXI(dx2), FXI(abs(dy2)));

    if (dy1) du1_step = DIV(du1, FXI(abs(dy1)));
    if (dy1) dv1_step = DIV(dv1, FXI(abs(dy1)));
    if (dy1) dw1_step = DIV(dw1, FXI(abs(dy1)));

    if (dy2) du2_step = DIV(du2, FXI(abs(dy2)));
    if (dy2) dv2_step = DIV(dv2, FXI(abs(dy2)));
    if (dy2) dw2_step = DIV(dw2, FXI(abs(dy2)));

    if (dy1) dr1_step = DIV(dr1, FXI(abs(dy1)));
    if (dy1) dg1_step = DIV(dg1, FXI(abs(dy1)));
    if (dy1) db1_step = DIV(db1, FXI(abs(dy1)));
    if (dy1) da1_step = DIV(da1, FXI(abs(dy1)));

    if (dy2) dr2_step = DIV(dr2, FXI(abs(dy2)));
    if (dy2) dg2_step = DIV(dg2, FXI(abs(dy2)));
    if (dy2) db2_step = DIV(db2, FXI(abs(dy2)));
    if (dy2) da2_step = DIV(da2, FXI(abs(dy2)));

    if (dy1) {
        for (int i = y1; i <= y2; i++) {
            int ax = INT(FXI(x1) + MUL(FXI(i - y1), dax_step));
            int bx = INT(FXI(x1) + MUL(FXI(i - y1), dbx_step));

            fx32 tex_su = u1 + MUL(FXI(i - y1), du1_step);
            fx32 tex_sv = v1 + MUL(FXI(i - y1), dv1_step);
            fx32 tex_sw = w1 + MUL(FXI(i - y1), dw1_step);

            fx32 tex_eu = u1 + MUL(FXI(i - y1), du2_step);
            fx32 tex_ev = v1 + MUL(FXI(i - y1), dv2_step);
            fx32 tex_ew = w1 + MUL(FXI(i - y1), dw2_step);

            fx32 col_sr = r1 + MUL(FXI(i - y1), dr1_step);
            fx32 col_sg = g1 + MUL(FXI(i - y1), dg1_step);
            fx32 col_sb = b1 + MUL(FXI(i - y1), db1_step);
            fx32 col_sa = a1 + MUL(FXI(i - y1), da1_step);

            fx32 col_er = r1 + MUL(FXI(i - y1), dr2_step);
            fx32 col_eg = g1 + MUL(FXI(i - y1), dg2_step);
            fx32 col_eb = b1 + MUL(FXI(i - y1), db2_step);
            fx32 col_ea = a1 + MUL(FXI(i - y1), da2_step);

            if (ax > bx) {
                swapi(&ax, &bx);
                swapf(&tex_su, &tex_eu);
                swapf(&tex_sv, &tex_ev);
                swapf(&tex_sw, &tex_ew);

                swapf(&col_sr, &col_er);
                swapf(&col_sg, &col_eg);
                swapf(&col_sb, &col_eb);
                swapf(&col_sa, &col_ea);
            }

            tex_u = tex_su;
            tex_v = tex_sv;
            tex_w = tex_sw;

            col_r = col_sr;
            col_g = col_sg;
            col_b = col_sb;
            col_a = col_sa;

            fx32 tstep = FXI(bx - ax) > 0 ? DIV(FX(1.0f), FXI(bx - ax)) : 0;
            fx32 t = FX(0.0f);

            for (int j = ax; j < bx; j++) {
                tex_u = MUL(FX(1.0f) - t, tex_su) + MUL(t, tex_eu);
                tex_v = MUL(FX(1.0f) - t, tex_sv) + MUL(t, tex_ev);
                tex_w = MUL(FX(1.0f) - t, tex_sw) + MUL(t, tex_ew);

                col_r = MUL(FX(1.0f) - t, col_sr) + MUL(t, col_er);
                col_g = MUL(FX(1.0f) - t, col_sg) + MUL(t, col_eg);
                col_b = MUL(FX(1.0f) - t, col_sb) + MUL(t, col_eb);
                col_a = MUL(FX(1.0f) - t, col_sa) + MUL(t, col_ea);

                int depth_index = i * g_fb_width + j;
                if (tex_w > g_depth_buffer[depth_index]) {
                    color_t sample = texture_sample_color(texture, DIV(tex_u, tex_w), DIV(tex_v, tex_w));

                    col_r = DIV(col_r, tex_w);
                    col_g = DIV(col_g, tex_w);
                    col_b = DIV(col_b, tex_w);
                    col_a = DIV(col_a, tex_w);

                    col_r = MUL(col_r, sample.x);
                    col_g = MUL(col_g, sample.y);
                    col_b = MUL(col_b, sample.z);
                    col_a = MUL(col_a, sample.w);

                    int rr = INT(MUL(col_r, FX(15.0f)));
                    int gg = INT(MUL(col_g, FX(15.0f)));
                    int bb = INT(MUL(col_b, FX(15.0f)));
                    int aa = INT(MUL(col_a, FX(15.0f)));

                    (*g_draw_pixel_fn)(j, i, aa << 12 | rr << 8 | gg << 4 | bb);
                    g_depth_buffer[depth_index] = tex_w;
                }
                t += tstep;
            }
        }
    }

    dy1 = y3 - y2;
    dx1 = x3 - x2;
    dv1 = v3 - v2;
    du1 = u3 - u2;
    dw1 = w3 - w2;

    dr1 = r3 - r2;
    dg1 = g3 - g2;
    db1 = b3 - b2;
    da1 = a3 - a2;

    if (dy1) dax_step = DIV(FXI(dx1), FXI(abs(dy1)));
    if (dy2) dbx_step = DIV(FXI(dx2), FXI(abs(dy2)));

    du1_step = FX(0.0f), dv1_step = FX(0.0f);
    if (dy1) du1_step = DIV(du1, FXI(abs(dy1)));
    if (dy1) dv1_step = DIV(dv1, FXI(abs(dy1)));
    if (dy1) dw1_step = DIV(dw1, FXI(abs(dy1)));

    dr1_step = FX(0.0f), dg1_step = FX(0.0f), db1_step = FX(0.0f), da1_step = FX(0.0f);
    if (dy1) dr1_step = DIV(dr1, FXI(abs(dy1)));
    if (dy1) dg1_step = DIV(dg1, FXI(abs(dy1)));
    if (dy1) db1_step = DIV(db1, FXI(abs(dy1)));
    if (dy1) da1_step = DIV(da1, FXI(abs(dy1)));

    if (dy1) {
        for (int i = y2; i <= y3; i++) {
            int ax = INT(FXI(x2) + MUL(FXI(i - y2), dax_step));
            int bx = INT(FXI(x1) + MUL(FXI(i - y1), dbx_step));

            fx32 tex_su = u2 + MUL(FXI(i - y2), du1_step);
            fx32 tex_sv = v2 + MUL(FXI(i - y2), dv1_step);
            fx32 tex_sw = w2 + MUL(FXI(i - y2), dw1_step);

            fx32 tex_eu = u1 + MUL(FXI(i - y1), du2_step);
            fx32 tex_ev = v1 + MUL(FXI(i - y1), dv2_step);
            fx32 tex_ew = w1 + MUL(FXI(i - y1), dw2_step);

            fx32 col_sr = r2 + MUL(FXI(i - y2), dr1_step);
            fx32 col_sg = g2 + MUL(FXI(i - y2), dg1_step);
            fx32 col_sb = b2 + MUL(FXI(i - y2), db1_step);
            fx32 col_sa = a2 + MUL(FXI(i - y2), da1_step);

            fx32 col_er = r1 + MUL(FXI(i - y1), dr2_step);
            fx32 col_eg = g1 + MUL(FXI(i - y1), dg2_step);
            fx32 col_eb = b1 + MUL(FXI(i - y1), db2_step);
            fx32 col_ea = a1 + MUL(FXI(i - y1), da2_step);

            if (ax > bx) {
                swapi(&ax, &bx);
                swapf(&tex_su, &tex_eu);
                swapf(&tex_sv, &tex_ev);
                swapf(&tex_sw, &tex_ew);

                swapf(&col_sr, &col_er);
                swapf(&col_sg, &col_eg);
                swapf(&col_sb, &col_eb);
                swapf(&col_sa, &col_ea);
            }

            tex_u = tex_su;
            tex_v = tex_sv;
            tex_w = tex_sw;

            col_r = col_sr;
            col_g = col_sg;
            col_b = col_sb;
            col_a = col_sa;

            fx32 tstep = FXI(bx - ax) > 0 ? DIV(FX(1.0f), FXI(bx - ax)) : 0;
            fx32 t = FX(0.0f);

            for (int j = ax; j < bx; j++) {
                tex_u = MUL(FX(1.0f) - t, tex_su) + MUL(t, tex_eu);
                tex_v = MUL(FX(1.0f) - t, tex_sv) + MUL(t, tex_ev);
                tex_w = MUL(FX(1.0f) - t, tex_sw) + MUL(t, tex_ew);

                col_r = MUL(FX(1.0f) - t, col_sr) + MUL(t, col_er);
                col_g = MUL(FX(1.0f) - t, col_sg) + MUL(t, col_eg);
                col_b = MUL(FX(1.0f) - t, col_sb) + MUL(t, col_eb);
                col_a = MUL(FX(1.0f) - t, col_sa) + MUL(t, col_ea);

                int depth_index = i * g_fb_width + j;
                if (tex_w > g_depth_buffer[depth_index]) {
                    color_t sample = texture_sample_color(texture, DIV(tex_u, tex_w), DIV(tex_v, tex_w));

                    col_r = DIV(col_r, tex_w);
                    col_g = DIV(col_g, tex_w);
                    col_b = DIV(col_b, tex_w);
                    col_a = DIV(col_a, tex_w);

                    col_r = MUL(col_r, sample.x);
                    col_g = MUL(col_g, sample.y);
                    col_b = MUL(col_b, sample.z);
                    col_a = MUL(col_a, sample.w);

                    int rr = INT(MUL(col_r, FX(15.0f)));
                    int gg = INT(MUL(col_g, FX(15.0f)));
                    int bb = INT(MUL(col_b, FX(15.0f)));
                    int aa = INT(MUL(col_a, FX(15.0f)));

                    (*g_draw_pixel_fn)(j, i, aa << 12 | rr << 8 | gg << 4 | bb);
                    g_depth_buffer[depth_index] = tex_w;
                }
                t += tstep;
            }
        }
    }
}
