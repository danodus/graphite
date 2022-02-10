#include "sw_rasterizer.h"

#include <stdbool.h>

static draw_pixel_fn_t g_draw_pixel_fn;

void sw_init_rasterizer(draw_pixel_fn_t draw_pixel_fn) { g_draw_pixel_fn = draw_pixel_fn; }

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

void sw_draw_triangle(int x0, int y0, int x1, int y1, int x2, int y2, int color) {
    sw_draw_line(x0, y0, x1, y1, color);
    sw_draw_line(x1, y1, x2, y2, color);
    sw_draw_line(x2, y2, x0, y0, color);
}

void sw_draw_filled_triangle(int x0, int y0, int x1, int y1, int x2, int y2, int color) {
    // TODO
}

void sw_draw_filled_rectangle(int x0, int y0, int x1, int y1, int color) {
    sw_draw_filled_triangle(x0, y0, x1, y0, x0, y1, color);
    sw_draw_filled_triangle(x1, y0, x0, y1, x1, y1, color);
}

int texture_sample_color(texture_t* tex, fx32 u, fx32 v) {
    if (tex == NULL) {
        if (u < FX(0.5) && v < FX(0.5)) return 255;
        if (u >= FX(0.5) && v < FX(0.5)) return 128;
        if (u < FX(0.5) && v >= FX(0.5)) return 128;
        return 255;
    }
    return 0;
}

void sw_draw_textured_triangle(int x0, int y0, fx32 u0, fx32 v0, int x1, int y1, fx32 u1, fx32 v1, int x2, int y2,
                               fx32 u2, fx32 v2, texture_t* tex) {
    // TODO
}

#pragma GCC diagnostic pop
