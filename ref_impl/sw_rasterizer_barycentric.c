// sw_rasterizer_barycentric.c
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "sw_rasterizer.h"

#define RECIPROCAL_NUMERATOR 256.0f

typedef struct {
    rfx32 r, g, b, a;
} color_t;

int g_fb_width, g_fb_height;
static draw_pixel_fn_t g_draw_pixel_fn;

rfx32* g_depth_buffer;

void sw_init_rasterizer(int fb_width, int fb_height, draw_pixel_fn_t draw_pixel_fn) {
    g_fb_width = fb_width;
    g_fb_height = fb_height;
    g_depth_buffer = (rfx32*)malloc(fb_width * fb_height * sizeof(rfx32));
    g_draw_pixel_fn = draw_pixel_fn;
}

void sw_dispose_rasterizer() { free(g_depth_buffer); }

void sw_clear_depth_buffer() { memset(g_depth_buffer, RFX(0.0f), g_fb_width * g_fb_height * sizeof(rfx32)); }

rfx32 reciprocal(rfx32 x) { return x > 0 ? RDIV(RFX(RECIPROCAL_NUMERATOR), x) : RFX(RECIPROCAL_NUMERATOR); }

rfx32 edge_function(rfx32 a[2], rfx32 b[2], rfx32 c[2]) {
    return RMUL(c[0] - a[0], b[1] - a[1]) - RMUL(c[1] - a[1], b[0] - a[0]);
}

int min(int a, int b) { return (a <= b) ? a : b; }

int max(int a, int b) { return (a >= b) ? a : b; }

int min3(int a, int b, int c) { return min(a, min(b, c)); }

int max3(int a, int b, int c) { return max(a, max(b, c)); }

color_t texture_sample_color(bool texture, rfx32 u, rfx32 v) {
    if (texture) {
        if (u < RFX(0.5f) && v < RFX(0.5f)) return (color_t){RFX(1.0f), RFX(1.0f), RFX(1.0f), RFX(1.0f)};
        if (u >= RFX(0.5f) && v < RFX(0.5f)) return (color_t){RFX(1.0f), RFX(0.0f), RFX(0.0f), RFX(1.0f)};
        if (u < RFX(0.5f) && v >= RFX(0.5f)) return (color_t){RFX(0.0f), RFX(1.0f), RFX(0.0f), RFX(1.0f)};
        return (color_t){RFX(0.0f), RFX(0.0f), RFX(1.0f), RFX(1.0f)};
    }
    return (color_t){RFX(1.0f), RFX(1.0f), RFX(1.0f), RFX(1.0f)};
}

void sw_draw_triangle(rfx32 x0, rfx32 y0, rfx32 z0, rfx32 u0, rfx32 v0, rfx32 r0, rfx32 g0, rfx32 b0, rfx32 a0,
                      rfx32 x1, rfx32 y1, rfx32 z1, rfx32 u1, rfx32 v1, rfx32 r1, rfx32 g1, rfx32 b1, rfx32 a1,
                      rfx32 x2, rfx32 y2, rfx32 z2, rfx32 u2, rfx32 v2, rfx32 r2, rfx32 g2, rfx32 b2, rfx32 a2,
                      bool texture, bool clamp_s, bool clamp_t, bool depth_test, bool persp_correct) {
    rfx32 vv0[3] = {x0, y0, z0};
    rfx32 vv1[3] = {x1, y1, z1};
    rfx32 vv2[3] = {x2, y2, z2};

    rfx32 c0[4] = {r0, g0, b0, a0};
    rfx32 c1[4] = {r1, g1, b1, a1};
    rfx32 c2[4] = {r2, g2, b2, a2};

    rfx32 t0[3] = {u0, v0, RFX(0.0f)};
    rfx32 t1[3] = {u1, v1, RFX(0.0f)};
    rfx32 t2[3] = {u2, v2, RFX(0.0f)};

    int min_x = min3(RINT(x0), RINT(x1), RINT(x2));
    int min_y = min3(RINT(y0), RINT(y1), RINT(y2));
    int max_x = max3(RINT(x0), RINT(x1), RINT(x2));
    int max_y = max3(RINT(y0), RINT(y1), RINT(y2));

    rfx32 area = edge_function(vv0, vv1, vv2);

    for (int y = min_y; y <= max_y; ++y)
        for (int x = min_x; x <= max_x; ++x) {
            rfx32 pixel_sample[2] = {RFXI(x), RFXI(y)};
            rfx32 w0 = edge_function(vv1, vv2, pixel_sample);
            rfx32 w1 = edge_function(vv2, vv0, pixel_sample);
            rfx32 w2 = edge_function(vv0, vv1, pixel_sample);
            if (w0 >= RFX(0.0f) && w1 >= RFX(0.0f) && w2 >= RFX(0.0f)) {
                rfx32 inv_area = reciprocal(area);
                inv_area = RDIV(inv_area, RFX(RECIPROCAL_NUMERATOR));
                w0 = RMUL(w0, inv_area);
                w1 = RMUL(w1, inv_area);
                w2 = RMUL(w2, inv_area);
                rfx32 u = RMUL(w0, t0[0]) + RMUL(w1, t1[0]) + RMUL(w2, t2[0]);
                rfx32 v = RMUL(w0, t0[1]) + RMUL(w1, t1[1]) + RMUL(w2, t2[1]);
                rfx32 r = RMUL(w0, c0[0]) + RMUL(w1, c1[0]) + RMUL(w2, c2[0]);
                rfx32 g = RMUL(w0, c0[1]) + RMUL(w1, c1[1]) + RMUL(w2, c2[1]);
                rfx32 b = RMUL(w0, c0[2]) + RMUL(w1, c1[2]) + RMUL(w2, c2[2]);
                rfx32 a = RMUL(w0, c0[3]) + RMUL(w1, c1[3]) + RMUL(w2, c2[3]);

                rfx32 z = RMUL(w0, vv0[2]) + RMUL(w1, vv1[2]) + RMUL(w2, vv2[2]);

                int depth_index = y * g_fb_width + x;
                if (!depth_test || (z > g_depth_buffer[depth_index])) {
                    if (persp_correct) {
                        // Perspective correction
                        rfx32 inv_z = reciprocal(z);
                        inv_z = RDIV(inv_z, RFX(RECIPROCAL_NUMERATOR));
                        u = RMUL(u, inv_z);
                        v = RMUL(v, inv_z);
                        r = RMUL(r, inv_z);
                        g = RMUL(g, inv_z);
                        b = RMUL(b, inv_z);
                        a = RMUL(a, inv_z);
                    }

                    color_t sample = texture_sample_color(texture, u, v);
                    r = RMUL(r, sample.r);
                    g = RMUL(g, sample.g);
                    b = RMUL(b, sample.b);

                    int rr = RINT(RMUL(r, RFX(15.0f)));
                    int gg = RINT(RMUL(g, RFX(15.0f)));
                    int bb = RINT(RMUL(b, RFX(15.0f)));
                    int aa = RINT(RMUL(a, RFX(15.0f)));

                    (*g_draw_pixel_fn)(x, y, aa << 12 | rr << 8 | gg << 4 | bb);

                    // write to depth buffer
                    g_depth_buffer[depth_index] = z;
                }
            }
        }
}
