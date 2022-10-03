#include "sw_rasterizer.h"

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#if FIXED_POINT
#define SAFE_DIV(x) (x > 0xFF)
#define SAFE_RDIV(x) (x > 0xFFFF)
#define RMUL(x, y) ((int)((x) >> (SCALE)) * (int)((y)))
#define RDIV(x, y) (((int)(x)) / (int)((y) >> (SCALE)))
#define FX_SHIFT(x) (x << 12)
#else
#define SAFE_DIV(x) (x != 0.0f)
#define SAFE_RDIV(x) (x != 0.0f)
#define RMUL(x, y) (x * y)
#define RDIV(x, y) (x / y)
#define FX_SHIFT(x) (x)
#endif

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

fx32 edge_function(fx32 a[2], fx32 b[2], fx32 c[2]) {
    return MUL(c[0] - a[0], b[1] - a[1]) - MUL(c[1] - a[1], b[0] - a[0]);
}

int min(int a, int b) { return (a <= b) ? a : b; }

int max(int a, int b) { return (a >= b) ? a : b; }

int min3(int a, int b, int c) { return min(a, min(b, c)); }

int max3(int a, int b, int c) { return max(a, max(b, c)); }

vec3d texture_sample_color(texture_t* tex, fx32 u, fx32 v) {
    if (tex == NULL) {
        if (u < FX(0.5) && v < FX(0.5)) return (vec3d){FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)};
        if (u >= FX(0.5) && v < FX(0.5)) return (vec3d){FX(0.5f), FX(0.5f), FX(0.5f), FX(1.0f)};
        if (u < FX(0.5) && v >= FX(0.5)) return (vec3d){FX(0.25f), FX(0.25f), FX(0.25f), FX(1.0f)};
        return (vec3d){FX(0.75f), FX(0.75f), FX(0.75f), FX(1.0f)};
    }
    return (vec3d){FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)};
}

void swapi(int *a, int *b) {
    int t = *a;
    *a = *b;
    *b = t;
}

void swapf(fx32 *a, fx32 *b) {
    fx32 t = *a;
    *a = *b;
    *b = t;
}

void sw_draw_triangle(fx32 x1a, fx32 y1a, fx32 w1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1, fx32 x2a,
                      fx32 y2a, fx32 w2, fx32 u2, fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2, fx32 x3a, fx32 y3a,
                      fx32 w3, fx32 u3, fx32 v3, fx32 r3, fx32 g3, fx32 b3, fx32 a3, texture_t* tex, bool clamp_s,
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
    }

    if (y3 < y1) {
        swapi(&y1, &y3);
        swapi(&x1, &x3);
        swapf(&u1, &u3);
        swapf(&v1, &v3);
        swapf(&w1, &w3);
    }

    if (y3 < y2) {
        swapi(&y2, &y3);
        swapi(&x2, &x3);
        swapf(&u2, &u3);
        swapf(&v2, &v3);
        swapf(&w2, &w3);
    }

    int dy1 = y2 - y1;
    int dx1 = x2 - x1;
    fx32 dv1 = v2 - v1;
    fx32 du1 = u2 - u1;
    fx32 dw1 = w2 - w1;

    int dy2 = y3 - y1;
    int dx2 = x3 - x1;
    fx32 dv2 = v3 - v1;
    fx32 du2 = u3 - u1;
    fx32 dw2 = w3 - w1;

    fx32 tex_u, tex_v, tex_w;

    fx32 dax_step = 0, dbx_step = 0, du1_step = 0, dv1_step = 0, du2_step = 0, dv2_step = 0, dw1_step = 0,
          dw2_step = 0;

    if (dy1) dax_step = DIV(FXI(dx1), FXI(abs(dy1)));
    if (dy2) dbx_step = DIV(FXI(dx2), FXI(abs(dy2)));

    if (dy1) du1_step = DIV(FXI(du1), FXI(abs(dy1)));
    if (dy1) dv1_step = DIV(FXI(dv1), FXI(abs(dy1)));
    if (dy1) dw1_step = DIV(FXI(dw1), FXI(abs(dy1)));

    if (dy2) du2_step = DIV(FXI(du2), FXI(abs(dy2)));
    if (dy2) dv2_step = DIV(FXI(dv2), FXI(abs(dy2)));
    if (dy2) dw2_step = DIV(FXI(dw2), FXI(abs(dy2)));

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

            if (ax > bx) {
                swapi(&ax, &bx);
                swapf(&tex_su, &tex_eu);
                swapf(&tex_sv, &tex_ev);
                swapf(&tex_sw, &tex_ew);
            }

            tex_u = tex_su;
            tex_v = tex_sv;
            tex_w = tex_sw;

            //fx32 tstep = SAFE_RDIV(FX_SHIFT(FXI(bx - ax))) ? RDIV(FX(1.0f), FX_SHIFT(FXI(bx - ax))) : FX(1.0f);
            fx32 tstep = FXI(bx - ax) > 0 ? DIV(FX(1.0f), FXI(bx - ax)) : 0;
            fx32 t = FX(0.0f);

            for (int j = ax; j < bx; j++) {
                tex_u = MUL(FX(1.0f) - t, tex_su) + MUL(t, tex_eu);
                tex_v = MUL(FX(1.0f) - t, tex_sv) + MUL(t, tex_ev);
                tex_w = MUL(FX(1.0f) - t, tex_sw) + MUL(t, tex_ew);
                int depth_index = i * g_fb_width + j;
                if (tex_w > g_depth_buffer[depth_index]) {
                    //vec3d sample = texture_sample_color(tex, DIV(tex_u, tex_w), DIV(tex_v, tex_w));

                    //int rr = INT(MUL(sample.x, FX(15.0f)));
                    //int gg = INT(MUL(sample.y, FX(15.0f)));
                    //int bb = INT(MUL(sample.z, FX(15.0f)));
                    //int aa = 15;

                    //(*g_draw_pixel_fn)(j, i, aa << 12 | rr << 8 | gg << 4 | bb);
                    (*g_draw_pixel_fn)(j, i, 0xFFFF);
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

    if (dy1) dax_step = DIV(FXI(dx1), FXI(abs(dy1)));
    if (dy2) dbx_step = DIV(FXI(dx2), FXI(abs(dy2)));

    du1_step = FX(0.0f), dv1_step = FX(0.0f);
    if (dy1) du1_step = DIV(du1, FXI(abs(dy1)));
    if (dy1) dv1_step = DIV(dv1, FXI(abs(dy1)));
    if (dy1) dw1_step = DIV(dw1, FXI(abs(dy1)));

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

            if (ax > bx) {
                swapi(&ax, &bx);
                swapf(&tex_su, &tex_eu);
                swapf(&tex_sv, &tex_ev);
                swapf(&tex_sw, &tex_ew);
            }

            tex_u = tex_su;
            tex_v = tex_sv;
            tex_w = tex_sw;

            //fx32 tstep = SAFE_RDIV(FX_SHIFT(FXI(bx - ax))) ? RDIV(FX(1.0f), FX_SHIFT(FXI(bx - ax))) : FX(1.0f);
            fx32 tstep =  FXI(bx - ax) > 0 ? DIV(FX(1.0f), FXI(bx - ax)) : 0;
            fx32 t = FX(0.0f);

            for (int j = ax; j < bx; j++) {

                tex_u = MUL(FX(1.0f) - t, tex_su) + MUL(t, tex_eu);
                tex_v = MUL(FX(1.0f) - t, tex_sv) + MUL(t, tex_ev);
                tex_w = MUL(FX(1.0f) - t, tex_sw) + MUL(t, tex_ew);
                int depth_index = i * g_fb_width + j;
                if (tex_w > g_depth_buffer[depth_index]) {
                    //vec3d sample = texture_sample_color(tex, DIV(tex_u, tex_w), DIV(tex_v, tex_w));

                    //int rr = INT(MUL(sample.x, FX(15.0f)));
                    //int gg = INT(MUL(sample.y, FX(15.0f)));
                    //int bb = INT(MUL(sample.z, FX(15.0f)));
                    //int aa = 15;

                    //(*g_draw_pixel_fn)(j, i, aa << 12 | rr << 8 | gg << 4 | bb);
                    (*g_draw_pixel_fn)(j, i, 0xFFFF);
                    g_depth_buffer[depth_index] = tex_w;
                }
                t += tstep;
            }
        }
    }
}
