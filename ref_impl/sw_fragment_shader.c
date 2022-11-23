#include "sw_rasterizer.h"

typedef struct {
    rfx32 r, g, b, a;
} color_t;

#define RECIPROCAL_NUMERATOR 256.0f
static rfx32 reciprocal(rfx32 x) { return x > 0 ? RDIV(RFX(RECIPROCAL_NUMERATOR), x) : RFX(RECIPROCAL_NUMERATOR); }

color_t texture_sample_color(bool texture, rfx32 u, rfx32 v) {
    if (texture) {
        if (u < RFX(0.5f) && v < RFX(0.5f)) return (color_t){RFX(1.0f), RFX(1.0f), RFX(1.0f), RFX(1.0f)};
        if (u >= RFX(0.5f) && v < RFX(0.5f)) return (color_t){RFX(1.0f), RFX(0.0f), RFX(0.0f), RFX(1.0f)};
        if (u < RFX(0.5f) && v >= RFX(0.5f)) return (color_t){RFX(0.0f), RFX(1.0f), RFX(0.0f), RFX(1.0f)};
        return (color_t){RFX(0.0f), RFX(0.0f), RFX(1.0f), RFX(1.0f)};
    }
    return (color_t){RFX(1.0f), RFX(1.0f), RFX(1.0f), RFX(1.0f)};
}


void sw_fragment_shader(int fb_width, int x, int y, rfx32 z, rfx32 u, rfx32 v, rfx32 r, rfx32 g, rfx32 b, rfx32 a, bool depth_test, bool texture, rfx32* depth_buffer, bool persp_correct, draw_pixel_fn_t draw_pixel_fn) {
    int depth_index = y * fb_width + x;
    if (!depth_test || (z > depth_buffer[depth_index])) {
        // Perspective correction
        rfx32 inv_z = reciprocal(z);
        inv_z = RDIV(inv_z, RFX(RECIPROCAL_NUMERATOR));
        u = RMUL(u, inv_z);
        v = RMUL(v, inv_z);

        if (persp_correct) {
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

        (*draw_pixel_fn)(x, y, aa << 12 | rr << 8 | gg << 4 | bb);

        // write to depth buffer
        depth_buffer[depth_index] = z;
    }
}