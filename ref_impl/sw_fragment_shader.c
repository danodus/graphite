#include "sw_rasterizer.h"

#include <math.h>

extern uint16_t tex32x32[];
extern uint16_t tex32x64[];
extern uint16_t tex256x2048[];

uint16_t *tex = tex256x2048;
#define TEXTURE_WIDTH   256
#define TEXTURE_HEIGHT  2048

typedef struct {
    fx32 r, g, b, a;
} color_t;

#define RECIPROCAL_NUMERATOR 256.0f
static fx32 reciprocal(fx32 x) { return x > 0 ? DIV(FX(RECIPROCAL_NUMERATOR), x) : FX(RECIPROCAL_NUMERATOR); }

color_t texture_sample_color(bool texture, fx32 u, fx32 v) {
    if (texture) {
        int x = INT(MUL(u, FXI(TEXTURE_WIDTH)));
        int y = INT(MUL(v, FXI(TEXTURE_HEIGHT)));
        if (x >= TEXTURE_WIDTH) x = TEXTURE_WIDTH - 1;
        if (y >= TEXTURE_HEIGHT) y = TEXTURE_HEIGHT - 1;
        uint16_t c = tex[y * TEXTURE_WIDTH + x];
        uint8_t a = (c >> 12) & 0xF;
        uint8_t r = (c >> 8) & 0xF;
        uint8_t g = (c >> 4) & 0xF;
        uint8_t b = c & 0xF;

        return (color_t){DIV(FXI(r), FXI(15)), DIV(FXI(g), FXI(15)), DIV(FXI(b), FXI(15)), DIV(FXI(a), FXI(15))};
    }
    return (color_t){FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)};
}

static fx32 clamp(fx32 v) {
    if (v < FX(0.0f)) {
        v = FX(0.0f);
    } else if (v > FX(1.0f)) {
        v = FX(1.0f);
    }
    return v;
}

static fx32 wrap(fx32 v) {
    if (v < FX(0.0f)) {
        v = FX(0.0f);
    } else if (v >= FX(1.0f)) {
        //v = FX(fmod(FLT(v), 1.0f));
        v = v & 0x3FFF;
    }
    return v;
}

void sw_fragment_shader(int fb_width, int fb_height, int x, int y, fx32 z, fx32 u, fx32 v, fx32 r, fx32 g, fx32 b, fx32 a, bool clamp_s, bool clamp_t, bool depth_test, bool texture, fx32* depth_buffer, bool persp_correct, draw_pixel_fn_t draw_pixel_fn) {
    if (x < 0 || y < 0 || x >= fb_width || y >= fb_height)
        return;
    int depth_index = y * fb_width + x;
    if (!depth_test || (z > depth_buffer[depth_index])) {
        // Perspective correction
        fx32 inv_z = reciprocal(z);
        inv_z = DIV(inv_z, FX(RECIPROCAL_NUMERATOR));

        if (persp_correct) {
            u = MUL(u, inv_z);
            v = MUL(v, inv_z);
            r = MUL(r, inv_z);
            g = MUL(g, inv_z);
            b = MUL(b, inv_z);
            a = MUL(a, inv_z);
        }

        if (clamp_s) {
            u = clamp(u);
        } else {
            u = wrap(u);
        }
        
        if (clamp_t) {
            v = clamp(v);
        } else {
            v = wrap(v);
        }

        color_t sample = texture_sample_color(texture, u, v);
        r = MUL(r, sample.r);
        g = MUL(g, sample.g);
        b = MUL(b, sample.b);

        int rr = INT(MUL(r, FX(31.0f)));
        int gg = INT(MUL(g, FX(63.0f)));
        int bb = INT(MUL(b, FX(31.0f)));

        (*draw_pixel_fn)(x, y, rr << 11 | gg << 5 | bb);

        // write to depth buffer
        depth_buffer[depth_index] = z;
    }
}