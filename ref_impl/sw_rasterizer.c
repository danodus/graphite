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
    return (vec3d){FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
}

void sw_draw_triangle(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 r0, fx32 g0, fx32 b0, fx32 a0, fx32 x1, fx32 y1,
                      fx32 z1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1, fx32 x2, fx32 y2, fx32 z2, fx32 u2,
                      fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2, texture_t* tex, bool clamp_s, bool clamp_t,
                      bool depth_test) {
    fx32 vv0[3] = {x0, y0, z0};
    fx32 vv1[3] = {x1, y1, z1};
    fx32 vv2[3] = {x2, y2, z2};

    fx32 c0[4] = {r0, g0, b0, a0};
    fx32 c1[4] = {r1, g1, b1, a1};
    fx32 c2[4] = {r2, g2, b2, a2};

    fx32 t0[3] = {u0, v0, FX(0.0f)};
    fx32 t1[3] = {u1, v1, FX(0.0f)};
    fx32 t2[3] = {u2, v2, FX(0.0f)};

    int min_x = min3(INT(x0), INT(x1), INT(x2));
    int min_y = min3(INT(y0), INT(y1), INT(y2));
    int max_x = max3(INT(x0), INT(x1), INT(x2)) + 1;
    int max_y = max3(INT(y0), INT(y1), INT(y2)) + 1;

    fx32 area = edge_function(vv0, vv1, vv2);

    for (int y = min_y; y <= max_y; ++y)
        for (int x = min_x; x <= max_x; ++x) {
            fx32 pixel_sample[2] = {FXI(x), FXI(y)};
            fx32 w0 = edge_function(vv1, vv2, pixel_sample);
            fx32 w1 = edge_function(vv2, vv0, pixel_sample);
            fx32 w2 = edge_function(vv0, vv1, pixel_sample);
            if (w0 >= FX(0.0f) && w1 >= FX(0.0f) && w2 >= FX(0.0f)) {
                if (SAFE_DIV(area)) {
                    fx32 inv_area = SAFE_RDIV(area) ? RDIV(FX(1.0), area) : FX(1.0f);
                    w0 = RMUL(w0, inv_area);
                    w1 = RMUL(w1, inv_area);
                    w2 = RMUL(w2, inv_area);
                    fx32 u = MUL(w0, t0[0]) + MUL(w1, t1[0]) + MUL(w2, t2[0]);
                    fx32 v = MUL(w0, t0[1]) + MUL(w1, t1[1]) + MUL(w2, t2[1]);
                    fx32 r = MUL(w0, c0[0]) + MUL(w1, c1[0]) + MUL(w2, c2[0]);
                    fx32 g = MUL(w0, c0[1]) + MUL(w1, c1[1]) + MUL(w2, c2[1]);
                    fx32 b = MUL(w0, c0[2]) + MUL(w1, c1[2]) + MUL(w2, c2[2]);
                    fx32 a = MUL(w0, c0[3]) + MUL(w1, c1[3]) + MUL(w2, c2[3]);

                    // Perspective correction
                    fx32 z = MUL(w0, vv0[2]) + MUL(w1, vv1[2]) + MUL(w2, vv2[2]);

                    int depth_index = y * g_fb_width + x;
                    if (!depth_test || (z > g_depth_buffer[depth_index])) {
                        fx32 inv_z = SAFE_RDIV(FX_SHIFT(z)) ? RDIV(FX(1.0f), FX_SHIFT(z)) : FX(1.0f);
                        u = MUL(u, FX_SHIFT(inv_z));
                        v = MUL(v, FX_SHIFT(inv_z));
                        r = MUL(r, FX_SHIFT(inv_z));
                        g = MUL(g, FX_SHIFT(inv_z));
                        b = MUL(b, FX_SHIFT(inv_z));
                        a = MUL(a, FX_SHIFT(inv_z));

                        if (tex != NULL) {
                            vec3d sample = texture_sample_color(tex, u, v);
                            r = MUL(r, sample.x);
                            g = MUL(g, sample.y);
                            b = MUL(b, sample.z);
                        }

                        int rr = INT(MUL(r, FX(15.0f)));
                        int gg = INT(MUL(g, FX(15.0f)));
                        int bb = INT(MUL(b, FX(15.0f)));
                        int aa = INT(MUL(a, FX(15.0f)));

                        (*g_draw_pixel_fn)(x, y, aa << 12 | rr << 8 | gg << 4 | bb);

                        // write to depth buffer
                        g_depth_buffer[depth_index] = z;
                    }
                }
            }
        }
}
