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

typedef struct {
    fx32 y1, y2, y3;
    fx32 x1, x2;
    fx32 u1, v1, w1;
    fx32 u2, v2, w2;
    fx32 r1, g1, b1, a1;
    fx32 r2, g2, b2, a2;
    fx32 dax_step, dbx_step;
    fx32 du1_step, dv1_step, dw1_step;
    fx32 du2_step, dv2_step, dw2_step;
    fx32 dr1_step, dg1_step, db1_step, da1_step;
    fx32 dr2_step, dg2_step, db2_step, da2_step;
    fx32 sy, ey, sx, su, sv, sw, sr, sg, sb, sa;
    bool tex;
} rasterize_triangle_half_params_t;

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

void rasterize_triangle_half(rasterize_triangle_half_params_t* p)
{
    for (int i = p->sy; i <= p->ey; i++) {
        int ax = INT(FXI(p->sx) + MUL(FXI(i - p->sy), p->dax_step));
        int bx = INT(FXI(p->x1) + MUL(FXI(i - p->y1), p->dbx_step));

        fx32 tex_su = p->su + MUL(FXI(i - p->sy), p->du1_step);
        fx32 tex_sv = p->sv + MUL(FXI(i - p->sy), p->dv1_step);
        fx32 tex_sw = p->sw + MUL(FXI(i - p->sy), p->dw1_step);

        fx32 tex_eu = p->u1 + MUL(FXI(i - p->y1), p->du2_step);
        fx32 tex_ev = p->v1 + MUL(FXI(i - p->y1), p->dv2_step);
        fx32 tex_ew = p->w1 + MUL(FXI(i - p->y1), p->dw2_step);

        fx32 col_sr = p->sr + MUL(FXI(i - p->sy), p->dr1_step);
        fx32 col_sg = p->sg + MUL(FXI(i - p->sy), p->dg1_step);
        fx32 col_sb = p->sb + MUL(FXI(i - p->sy), p->db1_step);
        fx32 col_sa = p->sa + MUL(FXI(i - p->sy), p->da1_step);

        fx32 col_er = p->r1 + MUL(FXI(i - p->y1), p->dr2_step);
        fx32 col_eg = p->g1 + MUL(FXI(i - p->y1), p->dg2_step);
        fx32 col_eb = p->b1 + MUL(FXI(i - p->y1), p->db2_step);
        fx32 col_ea = p->a1 + MUL(FXI(i - p->y1), p->da2_step);

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

        fx32 tex_u = tex_su;
        fx32 tex_v = tex_sv;
        fx32 tex_w = tex_sw;

        fx32 col_r = col_sr;
        fx32 col_g = col_sg;
        fx32 col_b = col_sb;
        fx32 col_a = col_sa;

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

            // Perspective correction
            tex_u = DIV(tex_u, tex_w);
            tex_v = DIV(tex_v, tex_w);

            int depth_index = i * g_fb_width + j;
            if (tex_w > g_depth_buffer[depth_index]) {
                color_t sample = texture_sample_color(p->tex, tex_u, tex_v);

                // Perspective correction
                col_r = DIV(col_r, tex_w);
                col_g = DIV(col_g, tex_w);
                col_b = DIV(col_b, tex_w);
                col_a = DIV(col_a, tex_w);

                col_r = MUL(col_r, sample.r);
                col_g = MUL(col_g, sample.g);
                col_b = MUL(col_b, sample.b);
                col_a = MUL(col_a, sample.a);

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

    rasterize_triangle_half_params_t p;

    p.y1 = y1; p.y2 = y2; p.y3 = y3;
    p.x1 = x1; p.x2 = x2;
    p.u1 = u1; p.v1 = v1; p.w1 = w1;
    p.u2 = u2; p.v2 = v2; p.w2 = w2;
    p.r1 = r1; p.g1 = g1; p.b1 = b1; p.a1 = a1;
    p.r2 = r2; p.g2 = g2; p.b2 = b2; p.a2 = a2;    

    p.tex = texture;    

    // rasterize top half    

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

    if (dy1) p.dax_step = DIV(FXI(dx1), FXI(abs(dy1)));
    if (dy2) p.dbx_step = DIV(FXI(dx2), FXI(abs(dy2)));

    if (dy1) p.du1_step = DIV(du1, FXI(abs(dy1)));
    if (dy1) p.dv1_step = DIV(dv1, FXI(abs(dy1)));
    if (dy1) p.dw1_step = DIV(dw1, FXI(abs(dy1)));

    if (dy2) p.du2_step = DIV(du2, FXI(abs(dy2)));
    if (dy2) p.dv2_step = DIV(dv2, FXI(abs(dy2)));
    if (dy2) p.dw2_step = DIV(dw2, FXI(abs(dy2)));

    if (dy1) p.dr1_step = DIV(dr1, FXI(abs(dy1)));
    if (dy1) p.dg1_step = DIV(dg1, FXI(abs(dy1)));
    if (dy1) p.db1_step = DIV(db1, FXI(abs(dy1)));
    if (dy1) p.da1_step = DIV(da1, FXI(abs(dy1)));

    if (dy2) p.dr2_step = DIV(dr2, FXI(abs(dy2)));
    if (dy2) p.dg2_step = DIV(dg2, FXI(abs(dy2)));
    if (dy2) p.db2_step = DIV(db2, FXI(abs(dy2)));
    if (dy2) p.da2_step = DIV(da2, FXI(abs(dy2)));

    p.sy = y1;
    p.ey = y2;
    p.sx = x1;
    p.su = u1;
    p.sv = v1;
    p.sw = w1;
    p.sr = r1;
    p.sg = g1;
    p.sb = b1;
    p.sa = a1;

    if (dy1)
        rasterize_triangle_half(&p);

    // rasterize bottom half

    dy1 = y3 - y2;
    dx1 = x3 - x2;
    dv1 = v3 - v2;
    du1 = u3 - u2;
    dw1 = w3 - w2;

    dr1 = r3 - r2;
    dg1 = g3 - g2;
    db1 = b3 - b2;
    da1 = a3 - a2;

    if (dy1) p.dax_step = DIV(FXI(dx1), FXI(abs(dy1)));
    if (dy2) p.dbx_step = DIV(FXI(dx2), FXI(abs(dy2)));

    p.du1_step = FX(0.0f), p.dv1_step = FX(0.0f);
    if (dy1) p.du1_step = DIV(du1, FXI(abs(dy1)));
    if (dy1) p.dv1_step = DIV(dv1, FXI(abs(dy1)));
    if (dy1) p.dw1_step = DIV(dw1, FXI(abs(dy1)));

    p.dr1_step = FX(0.0f), p.dg1_step = FX(0.0f), p.db1_step = FX(0.0f), p.da1_step = FX(0.0f);
    if (dy1) p.dr1_step = DIV(dr1, FXI(abs(dy1)));
    if (dy1) p.dg1_step = DIV(dg1, FXI(abs(dy1)));
    if (dy1) p.db1_step = DIV(db1, FXI(abs(dy1)));
    if (dy1) p.da1_step = DIV(da1, FXI(abs(dy1)));

    p.sy = y2;
    p.ey = y3;
    p.sx = x2;
    p.su = u2;
    p.sv = v2;
    p.sw = w2;
    p.sr = r2;
    p.sg = g2;
    p.sb = b2;
    p.sa = a2;    

    if (dy1)
        rasterize_triangle_half(&p);
}
