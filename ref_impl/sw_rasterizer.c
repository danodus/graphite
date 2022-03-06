#include "sw_rasterizer.h"

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#if FIXED_POINT
#define SAFE_DIV(x) (x > 0xFF)
#define SAFE_RDIV(x) (x > 0xFFFF)
#define RMUL(x, y) ((int)((x) >> (SCALE)) * (int)((y)))
#define RDIV(x, y) (((int)(x)) / (int)((y) >> (SCALE)))

#else
#define SAFE_DIV(x) (x != 0.0f)
#define SAFE_RDIV(x) (x != 0.0f)
#define RMUL(x, y) (x * y)
#define RDIV(x, y) (x / y)
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

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wuninitialized"
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"

// ----------------------------------------------------------------------------
// Line

typedef enum { LINE_IDLE, LINE_INIT_0, LINE_INIT_1, LINE_DRAW } line_states_t;

typedef struct {
    bool right;
    int err;
    int dx, dy;
    bool movx, movy;
    line_states_t state;
} line_ctx_t;

static void process_line(line_ctx_t* ctx, bool reset_i, bool start_i, bool oe_i, int x0_i, int y0_i, int x1_i, int y1_i,
                         int* x_o, int* y_o, bool* drawing_o, bool* busy_o, bool* done_o) {
    ctx->movx = (2 * ctx->err >= ctx->dy);
    ctx->movy = (2 * ctx->err <= ctx->dx);

    switch (ctx->state) {
        case LINE_DRAW:
            if (oe_i) {
                if (*x_o == x1_i && *y_o == y1_i) {
                    ctx->state = LINE_IDLE;
                    *busy_o = false;
                    *done_o = true;
                } else {
                    if (ctx->movx && ctx->movy) {
                        *x_o = ctx->right ? *x_o + 1 : *x_o - 1;
                        *y_o = *y_o + 1;
                        ctx->err = ctx->err + ctx->dy + ctx->dx;
                    } else if (ctx->movx) {
                        *x_o = ctx->right ? *x_o + 1 : *x_o - 1;
                        ctx->err = ctx->err + ctx->dy;
                    } else if (ctx->movy) {
                        *y_o = *y_o + 1;  // always down
                        ctx->err = ctx->err + ctx->dx;
                    }
                }
            }
            break;
        case LINE_INIT_0:
            ctx->state = LINE_INIT_1;
            ctx->dx = ctx->right ? x1_i - x0_i : x0_i - x1_i;  // dx = abs(x1_i - x0_i)
            ctx->dy = y0_i - y1_i;                             // dy = y0_i - y1_i
            break;
        case LINE_INIT_1:
            ctx->state = LINE_DRAW;
            ctx->err = ctx->dx + ctx->dy;
            *x_o = x0_i;
            *y_o = y0_i;
            break;
        default: {  // IDLE
            *done_o = false;
            if (start_i) {
                ctx->state = LINE_INIT_0;
                ctx->right = (x0_i < x1_i);  // draw right to left?
                *busy_o = true;
            }
        }
    }

    if (reset_i) {
        ctx->state = LINE_IDLE;
        *busy_o = false;
        *done_o = false;
    }

    *drawing_o = (ctx->state == LINE_DRAW && oe_i);
}

static void swapi(int* a, int* b) {
    int c = *a;
    *a = *b;
    *b = c;
}

static void swapfx32(fx32* a, fx32* b) {
    fx32 c = *a;
    *a = *b;
    *b = c;
}

void sw_draw_line(int x0, int y0, int x1, int y1, int color) {
    if (y0 > y1) {
        swapi(&x0, &x1);
        swapi(&y0, &y1);
    }

    line_ctx_t ctx;
    int x, y;
    bool drawing, busy, done;

    // Reset
    process_line(&ctx, true, false, false, x0, y0, x1, y1, &x, &y, &drawing, &busy, &done);

    bool start = true;
    while (!done) {
        process_line(&ctx, false, start, true, x0, y0, x1, y1, &x, &y, &drawing, &busy, &done);
        start = false;
        if (drawing) (*g_draw_pixel_fn)(x, y, color);
    }
}

void sw_draw_triangle(fx32 x0, fx32 y0, fx32 x1, fx32 y1, fx32 x2, fx32 y2, int color) {
    sw_draw_line(INT(x0), INT(y0), INT(x1), INT(y1), color);
    sw_draw_line(INT(x1), INT(y1), INT(x2), INT(y2), color);
    sw_draw_line(INT(x2), INT(y2), INT(x0), INT(y0), color);
}

int edge_function(int a[2], int b[2], int c[2]) {
    return (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0]);
}

fx32 edge_function_fx32(fx32 a[2], fx32 b[2], fx32 c[2]) {
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

void sw_draw_textured_triangle(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 r0, fx32 g0, fx32 b0, fx32 a0, fx32 x1,
                               fx32 y1, fx32 z1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1, fx32 x2, fx32 y2,
                               fx32 z2, fx32 u2, fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2, texture_t* tex) {
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
    int max_x = max3(INT(x0), INT(x1), INT(x2));
    int max_y = max3(INT(y0), INT(y1), INT(y2));

    fx32 area = edge_function_fx32(vv0, vv1, vv2);

    for (int y = min_y; y <= max_y; ++y)
        for (int x = min_x; x <= max_x; ++x) {
            fx32 pixel_sample[2] = {FXI(x), FXI(y)};

            fx32 w0 = edge_function_fx32(vv1, vv2, pixel_sample);
            fx32 w1 = edge_function_fx32(vv2, vv0, pixel_sample);
            fx32 w2 = edge_function_fx32(vv0, vv1, pixel_sample);
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
                    if (z > g_depth_buffer[depth_index]) {
                        fx32 inv_z = SAFE_RDIV(z << 12) ? RDIV(FX(1.0f), z << 12) : FX(1.0f);
                        u = MUL(u, inv_z << 12);
                        v = MUL(v, inv_z << 12);
                        r = MUL(r, inv_z << 12);
                        g = MUL(g, inv_z << 12);
                        b = MUL(b, inv_z << 12);
                        a = MUL(a, inv_z << 12);

                        vec3d sample = texture_sample_color(tex, u, v);
                        r = MUL(r, sample.x);
                        g = MUL(g, sample.y);
                        b = MUL(b, sample.z);

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

#pragma GCC diagnostic pop
