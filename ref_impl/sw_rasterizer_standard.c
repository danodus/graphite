// sw_rasterizer_standard.c
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "sw_rasterizer.h"

extern uint16_t tex32x32[];
extern uint16_t tex32x64[];
extern uint16_t tex256x2048[];

uint16_t *texture = tex32x32;
#define TEX_WIDTH   32
#define TEX_HEIGHT  32

// 16.16 Fixed-Point Macros
typedef int32_t fixed16;
#define INT_TO_FIXED(x)      ((fixed16)((x) << 16))
#define FIXED_TO_INT(x)      ((int32_t)((x) >> 16))
#define FIXED_MUL(a, b)      ((fixed16)(((int64_t)(a) * (b)) >> 16))
#define FIXED_DIV(a, b)      ((fixed16)(((int64_t)(a) << 16) / (b)))

#define FIXED_HALF           0x8000
#define FIXED_CEIL_HALF(x)   (((x) + 0x7FFF) >> 16)

#if FIXED_POINT
#define FX32_TO_FIXED16(x) ((fixed16)(x))
#else
#define FX32_TO_FIXED16(x) ((fixed16)((x) * 65536.0f))
#endif

// 16-bit integer far clipping plane depth limit
#define Z_INFINITY_16        20000

typedef struct {
    fixed16 x, y, w; // w maps to true transformed camera Z depth
    fixed16 s, t;
    fixed16 r, g, b; 
} Vertex;

typedef struct {
    int16_t x, y; // 12.4 fixed-point format
    fixed16 w; // w maps to true transformed camera Z depth
    fixed16 s, t;
    fixed16 r, g, b; 
} Vertex2;

static int g_fb_width, g_fb_height;
static draw_pixel_fn_t g_draw_pixel_fn;

static fx32* g_depth_buffer;

void sw_init_rasterizer_standard(int fb_width, int fb_height, draw_pixel_fn_t draw_pixel_fn) {
    g_fb_width = fb_width;
    g_fb_height = fb_height;
    g_depth_buffer = (fx32*)malloc(fb_width * fb_height * sizeof(fx32));
    g_draw_pixel_fn = draw_pixel_fn;
}

void sw_dispose_rasterizer_standard() { free(g_depth_buffer); }

void sw_clear_depth_buffer_standard() {
    for (int i = 0; i < g_fb_width * g_fb_height; i++)
        g_depth_buffer[i] = Z_INFINITY_16;  // max int32 = "infinity"
}

static inline int16_t min3(int16_t a, int16_t b, int16_t c) {
    int16_t m = a; if (b < m) m = b; if (c < m) m = c; return m;
}

static inline int16_t max3(int16_t a, int16_t b, int16_t c) {
    int16_t m = a; if (b > m) m = b; if (c > m) m = c; return m;
}

static void draw_triangle_serpentine_ras(Vertex2 v0, Vertex2 v1, Vertex2 v2,
                              int32_t start_w, int32_t start_s, int32_t start_t, int32_t start_r, int32_t start_g, int32_t start_b,
                              int32_t dw_dx, int32_t ds_dx, int32_t dt_dx, int32_t dr_dx, int32_t dg_dx, int32_t db_dx,
                              int32_t dw_dy, int32_t ds_dy, int32_t dt_dy, int32_t dr_dy, int32_t dg_dy, int32_t db_dy, bool sign_bit,
                              bool texture_enabled, bool depth_test, bool perspective_correct) {
    
    // -------------------------------------------------------------------------
    // 1. WINDING ORIENTATION
    // -------------------------------------------------------------------------
    int32_t dx1 = v1.x - v0.x; int32_t dy1 = v1.y - v0.y;

    // Winding sign correction factor so 'inside' always results in all positive edge values
    int32_t sign = sign_bit ? -1 : 1;

    // -------------------------------------------------------------------------
    // 2. BOUNDING BOX & RUNTIME ANCHORS
    // -------------------------------------------------------------------------
    // Vertices are pre-sorted vertically by your pipeline: v0.y <= v1.y <= v2.y

    // Convert 12.4 coordinates to standard integer bounding box
    int start_y = v0.y >> 4;
    int min_x   = min3(v0.x, v1.x, v2.x) >> 4;
    int max_x   = max3(v0.x, v1.x, v2.x) >> 4;
    int max_y   = v2.y >> 4;

    if (min_x < 0) min_x = 0;
    if (max_x >= g_fb_width) max_x = g_fb_width - 1;
    if (start_y < 0) start_y = 0;    

    // -------------------------------------------------------------------------
    // 3. PINEDA EDGE SETUP
    // -------------------------------------------------------------------------

    // Edge steps are downscaled to << 4 due to the 4-bit subpixel precision
    int32_t step_e01_x = sign * ((int32_t)(v1.y - v0.y) << 4);
    int32_t step_e01_y = -sign * ((int32_t)(v1.x - v0.x) << 4);
    int32_t step_e12_x = sign * ((int32_t)(v2.y - v1.y) << 4);
    int32_t step_e12_y = -sign * ((int32_t)(v2.x - v1.x) << 4);
    int32_t step_e20_x = sign * ((int32_t)(v0.y - v2.y) << 4);
    int32_t step_e20_y = -sign * ((int32_t)(v0.x - v2.x) << 4);

    // -------------------------------------------------------------------------
    // SIGN-AWARE HETEROGENEOUS TIE-BREAKING BIAS
    // -------------------------------------------------------------------------
    int32_t bias01, bias12, bias20;

    if (sign == -1) {
        bias01 = (dy1 > 0 || (dy1 == 0 && dx1 < 0)) ? 0 : -1;
        bias12 = ((v2.y - v1.y) > 0 || ((v2.y - v1.y) == 0 && (v2.x - v1.x) < 0)) ? 0 : -1;
        bias20 = ((v0.y - v2.y) > 0 || ((v0.y - v2.y) == 0 && (v0.x - v2.x) < 0)) ? 0 : -1;
    } else {
        // Invert the tie-breaker when the face winding sign flips.
        // This guarantees back-to-back seams cleanly hand off the pixel.
        bias01 = (dy1 > 0 || (dy1 == 0 && dx1 < 0)) ? -1 : 0;
        bias12 = ((v2.y - v1.y) > 0 || ((v2.y - v1.y) == 0 && (v2.x - v1.x) < 0)) ? -1 : 0;
        bias20 = ((v0.y - v2.y) > 0 || ((v0.y - v2.y) == 0 && (v0.x - v2.x) < 0)) ? -1 : 0;
    }    

    int curr_x = min_x;
    int curr_y = start_y;

    // Calculate initial pixel center in 12.4 format (+0.5 is represented by +8)
    int32_t p_x = (curr_x << 4) + 8;
    int32_t p_y = (curr_y << 4) + 8;

    // Edge equations evaluate entirely inside a native 32-bit budget
    int32_t E01 = sign * ((p_x - v0.x) * dy1 - (p_y - v0.y) * dx1) + bias01;
    int32_t E12 = sign * ((p_x - v1.x) * (v2.y - v1.y) - (p_y - v1.y) * (v2.x - v1.x)) + bias12;
    int32_t E20 = sign * ((p_x - v2.x) * (v0.y - v2.y) - (p_y - v2.y) * (v0.x - v2.x)) + bias20;

    // -------------------------------------------------------------------------
    // 4. RASTERIZER INITIALIZATION (EVALUATE DIRECTLY AT TARGET PIXEL CENTER)
    // -------------------------------------------------------------------------
    // Step parameters to pixel centers directly using native integer products
    int32_t acc_w_inv = start_w + (int32_t)(((int64_t)curr_x * dw_dx) + ((int64_t)curr_y * dw_dy) + (dw_dx >> 1) + (dw_dy >> 1));
    int32_t acc_u_w   = start_s + (int32_t)(((int64_t)curr_x * ds_dx) + ((int64_t)curr_y * ds_dy) + (ds_dx >> 1) + (ds_dy >> 1));
    int32_t acc_v_w   = start_t + (int32_t)(((int64_t)curr_x * dt_dx) + ((int64_t)curr_y * dt_dy) + (dt_dx >> 1) + (dt_dy >> 1));
    int32_t acc_r_w   = start_r + (int32_t)(((int64_t)curr_x * dr_dx) + ((int64_t)curr_y * dr_dy) + (dr_dx >> 1) + (dr_dy >> 1));
    int32_t acc_g_w   = start_g + (int32_t)(((int64_t)curr_x * dg_dx) + ((int64_t)curr_y * dg_dy) + (dg_dx >> 1) + (dg_dy >> 1));
    int32_t acc_b_w   = start_b + (int32_t)(((int64_t)curr_x * db_dx) + ((int64_t)curr_y * db_dy) + (db_dx >> 1) + (db_dy >> 1));

    int dir = 1; 

    // -------------------------------------------------------------------------
    // 5. RASTERIZATION LOOP
    // -------------------------------------------------------------------------
    bool hit_inside_this_row = false;
    while (curr_y <= max_y && curr_y < g_fb_height) {
        bool inside = (curr_x >= min_x && curr_x <= max_x && curr_y >= 0 && curr_y < g_fb_height) && 
                      (E01 >= 0 && E12 >= 0 && E20 >= 0);

        if (inside) {
            hit_inside_this_row = true;
            // Convert customized hardware bits back into standard 16.16 for perspective division
            fixed16 current_zinv = acc_w_inv >> 12; // 4.28  -> 16.16 (shift right 12)
            fixed16 current_u_w  = acc_u_w   >> 2;  // 14.18 -> 16.16 (shift right 2)
            fixed16 current_v_w  = acc_v_w   >> 2;  // 14.18 -> 16.16 (shift right 2)
            fixed16 current_r_w  = acc_r_w   << 4;  // 12.12 -> 16.16 (shift left 4)
            fixed16 current_g_w  = acc_g_w   << 4;  // 12.12 -> 16.16 (shift left 4)
            fixed16 current_b_w  = acc_b_w   << 4;  // 12.12 -> 16.16 (shift left 4)

            fixed16 z_inv = (current_zinv < 1) ? 1 : current_zinv;
            fixed16 current_w = (fixed16)(((int64_t)1 << 40) / z_inv);
            
            int32_t w_int = FIXED_TO_INT(current_w);
            if (w_int < 0) w_int = 0;
            if (w_int > Z_INFINITY_16) w_int = Z_INFINITY_16;
            uint16_t depth_16 = (uint16_t)w_int;

            int buf_idx = curr_y * g_fb_width + curr_x;
            if (!depth_test || depth_16 < g_depth_buffer[buf_idx]) {
                if (depth_test) g_depth_buffer[buf_idx] = depth_16;

                fixed16 true_u = perspective_correct ? (fixed16)(((int64_t)current_u_w * current_w) >> 24) : current_u_w;
                fixed16 true_v = perspective_correct ? (fixed16)(((int64_t)current_v_w * current_w) >> 24) : current_v_w;
                fixed16 true_r = perspective_correct ? (fixed16)(((int64_t)current_r_w * current_w) >> 24) : current_r_w;
                fixed16 true_g = perspective_correct ? (fixed16)(((int64_t)current_g_w * current_w) >> 24) : current_g_w;
                fixed16 true_b = perspective_correct ? (fixed16)(((int64_t)current_b_w * current_w) >> 24) : current_b_w;

                int tex_u = FIXED_TO_INT(true_u) & (TEX_WIDTH - 1);
                int tex_v = FIXED_TO_INT(true_v) & (TEX_HEIGHT - 1);

                uint16_t tex_pixel = texture_enabled ? texture[tex_v * TEX_WIDTH + tex_u] : 0x0FFF;
                uint32_t tr = texture_enabled ? ((tex_pixel >> 8) & 0xF) : 15;
                uint32_t tg = texture_enabled ? ((tex_pixel >> 4) & 0xF) : 15;
                uint32_t tb = texture_enabled ? (tex_pixel & 0xF) : 15;
                uint32_t tex_r = (tr << 4) | tr;
                uint32_t tex_g = (tg << 4) | tg;
                uint32_t tex_b = (tb << 4) | tb;

                int32_t r_int = FIXED_TO_INT(true_r);
                int32_t g_int = FIXED_TO_INT(true_g);
                int32_t b_int = FIXED_TO_INT(true_b);
                if (r_int < 0) r_int = 0; else if (r_int > 255) r_int = 255;
                if (g_int < 0) g_int = 0; else if (g_int > 255) g_int = 255;
                if (b_int < 0) b_int = 0; else if (b_int > 255) b_int = 255;

                uint32_t final_r = (tex_r * r_int) >> 8;
                uint32_t final_g = (tex_g * g_int) >> 8;
                uint32_t final_b = (tex_b * b_int) >> 8;

                g_draw_pixel_fn(curr_x, curr_y, ((final_r >> 3) << 11) | ((final_g >> 2) << 5) | (final_b >> 3));
            }
        }

        // -------------------------------------------------------------------------
        // PURE 32-BIT HARDWARE EXECUTION STEPS
        // -------------------------------------------------------------------------
        bool shift_row_down = false;
        if (dir == 1  && curr_x >= max_x) shift_row_down = true;
        if (dir == -1 && curr_x <= min_x) shift_row_down = true;

        // Smart traversal: Turn around early if we have left the triangle
        // and the edges we crossed do not expand outward to overtake our current X on the next row.
        bool turn_around = (hit_inside_this_row && !inside);
        if (turn_around) {
            if (E01 < 0 && (E01 + step_e01_y) >= 0) turn_around = false;
            if (E12 < 0 && (E12 + step_e12_y) >= 0) turn_around = false;
            if (E20 < 0 && (E20 + step_e20_y) >= 0) turn_around = false;
        }

        if (turn_around) {
            shift_row_down = true;
        }

        if (shift_row_down) {
            // Step straight down vertically 1 pixel and flip scanning tracking direction
            curr_y++;
            hit_inside_this_row = false;
            dir = -dir;

            E01 += step_e01_y;
            E12 += step_e12_y;
            E20 += step_e20_y;

            acc_w_inv += dw_dy;
            acc_u_w   += ds_dy; acc_v_w   += dt_dy;
            acc_r_w   += dr_dy; acc_g_w   += dg_dy; acc_b_w   += db_dy;
        } else {
            // Advance horizontally along the current row line
            curr_x += dir;

            // Step tracking registers horizontally (multiplying by dir is a basic Mux choosing +/-)
            E01 += step_e01_x * dir;
            E12 += step_e12_x * dir;
            E20 += step_e20_x * dir;

            acc_w_inv += dw_dx * dir;
            acc_u_w   += ds_dx * dir; acc_v_w   += dt_dx * dir;
            acc_r_w   += dr_dx * dir; acc_g_w   += dg_dx * dir; acc_b_w   += db_dx * dir;
        }

        // Enforce 24-bit sign-extension limits on color registers to match ASIC widths
        acc_r_w = (acc_r_w << 8) >> 8;
        acc_g_w = (acc_g_w << 8) >> 8;
        acc_b_w = (acc_b_w << 8) >> 8;
    }
}

// -------------------------------------------------------------------------
// HOST GEOMETRY SETUP UNIT (REALIGNED FOR 12.4 COORDINATES)
// -------------------------------------------------------------------------
static inline int64_t mul_shr4(int64_t a, int64_t b) {
    return a * (b >> 4) + ((a * (b & 15)) >> 4);
}

static inline int64_t solve_gradient_high(int64_t det, fixed16 termA, int32_t factorA, fixed16 termB, int32_t factorB) {
    // term is 16.16, factor is 12.4 -> product represents a 28.20 format fixed point structure
    int64_t num = (int64_t)termA * factorA - (int64_t)termB * factorB; 
    // Shift left by 20 to set up 40 fractional bits. Dividing by the 8 fractional bits of det yields 32.32
    return (num / det) * 1048576LL + ((num % det) * 1048576LL) / det;
}

static void draw_triangle(Vertex v0a, Vertex v1a, Vertex v2a, bool texture_enabled, bool depth_test, bool perspective_correct) {

    Vertex2 v0, v1, v2;

    v0.x = v0a.x >> 12; v0.y = v0a.y >> 12; v0.w = v0a.w; v0.s = v0a.s; v0.t = v0a.t; v0.r = v0a.r; v0.g = v0a.g; v0.b = v0a.b;
    v1.x = v1a.x >> 12; v1.y = v1a.y >> 12; v1.w = v1a.w; v1.s = v1a.s; v1.t = v1a.t; v1.r = v1a.r; v1.g = v1a.g; v1.b = v1a.b;
    v2.x = v2a.x >> 12; v2.y = v2a.y >> 12; v2.w = v2a.w; v2.s = v2a.s; v2.t = v2a.t; v2.r = v2a.r; v2.g = v2a.g; v2.b = v2a.b;

    // Sort vertices by Y coordinate
    if (v0.y > v1.y) { Vertex2 t = v0; v0 = v1; v1 = t; }
    if (v0.y > v2.y) { Vertex2 t = v0; v0 = v2; v2 = t; }
    if (v1.y > v2.y) { Vertex2 t = v1; v1 = v2; v2 = t; }

    int32_t dx1 = v1.x - v0.x; int32_t dy1 = v1.y - v0.y;
    int32_t dx2 = v2.x - v0.x; int32_t dy2 = v2.y - v0.y;
    int64_t det = (int64_t)dx1 * dy2 - (int64_t)dy1 * dx2; // Evaluates to 24.8 format
    if (det == 0) return; 


    // SOLVE HIGH-PRECISION GRADIENTS (32-BIT FRACTIONAL PARTS)
    fixed16 w0_inv = v0.w;
    fixed16 w1_inv = v1.w;
    fixed16 w2_inv = v2.w;

    fixed16 s0_w = perspective_correct ? FIXED_MUL(v0.s, w0_inv) : v0.s; fixed16 s1_w = perspective_correct ? FIXED_MUL(v1.s, w1_inv) : v1.s; fixed16 s2_w = perspective_correct ? FIXED_MUL(v2.s, w2_inv) : v2.s;
    fixed16 t0_w = perspective_correct ? FIXED_MUL(v0.t, w0_inv) : v0.t; fixed16 t1_w = perspective_correct ? FIXED_MUL(v1.t, w1_inv) : v1.t; fixed16 t2_w = perspective_correct ? FIXED_MUL(v2.t, w2_inv) : v2.t;
    fixed16 r0_w = perspective_correct ? FIXED_MUL(v0.r, w0_inv) : v0.r; fixed16 r1_w = perspective_correct ? FIXED_MUL(v1.r, w1_inv) : v1.r; fixed16 r2_w = perspective_correct ? FIXED_MUL(v2.r, w2_inv) : v2.r;
    fixed16 g0_w = perspective_correct ? FIXED_MUL(v0.g, w0_inv) : v0.g; fixed16 g1_w = perspective_correct ? FIXED_MUL(v1.g, w1_inv) : v1.g; fixed16 g2_w = perspective_correct ? FIXED_MUL(v2.g, w2_inv) : v2.g;
    fixed16 b0_w = perspective_correct ? FIXED_MUL(v0.b, w0_inv) : v0.b; fixed16 b1_w = perspective_correct ? FIXED_MUL(v1.b, w1_inv) : v1.b; fixed16 b2_w = perspective_correct ? FIXED_MUL(v2.b, w2_inv) : v2.b;

    // Compute hyper-attribute deltas relative to top anchor vertex (v0)
    fixed16 dw_inv1 = w1_inv - w0_inv; fixed16 dw_inv2 = w2_inv - w0_inv;
    fixed16 ds1 = s1_w - s0_w;         fixed16 ds2 = s2_w - s0_w;
    fixed16 dt1 = t1_w - t0_w;         fixed16 dt2 = t2_w - t0_w;
    fixed16 dr1 = r1_w - r0_w;         fixed16 dr2 = r2_w - r0_w;
    fixed16 dg1 = g1_w - g0_w;         fixed16 dg2 = g2_w - g0_w;
    fixed16 db1 = b1_w - b0_w;         fixed16 db2 = b2_w - b0_w;

    // Output gradients are raw 32.32 format
    int64_t raw_dw_dx = solve_gradient_high(det, dw_inv1, dy2, dw_inv2, dy1);
    int64_t raw_du_dx = solve_gradient_high(det, ds1,     dy2, ds2,     dy1);
    int64_t raw_dv_dx = solve_gradient_high(det, dt1,     dy2, dt2,     dy1);
    int64_t raw_dr_dx = solve_gradient_high(det, dr1,     dy2, dr2,     dy1);
    int64_t raw_dg_dx = solve_gradient_high(det, dg1,     dy2, dg2,     dy1);
    int64_t raw_db_dx = solve_gradient_high(det, db1,     dy2, db2,     dy1);

    int64_t raw_dw_dy = solve_gradient_high(det, dw_inv2, dx1, dw_inv1, dx2);
    int64_t raw_ds_dy = solve_gradient_high(det, ds2,     dx1, ds1,     dx2);
    int64_t raw_dt_dy = solve_gradient_high(det, dt2,     dx1, dt1,     dx2);
    int64_t raw_dr_dy = solve_gradient_high(det, dr2,     dx1, dr1,     dx2);
    int64_t raw_dg_dy = solve_gradient_high(det, dg2,     dx1, dg1,     dx2);
    int64_t raw_db_dy = solve_gradient_high(det, db2,     dx1, db1,     dx2);

    // Multiplied by 12.4 instead of 16.16 -> Shifting right by 4 balances output to standard 32.32
    int64_t raw_start_w = ((int64_t)w0_inv << 16) - mul_shr4(v0.x, raw_dw_dx) - mul_shr4(v0.y, raw_dw_dy);
    int64_t raw_start_s = ((int64_t)s0_w   << 16) - mul_shr4(v0.x, raw_du_dx) - mul_shr4(v0.y, raw_ds_dy);
    int64_t raw_start_t = ((int64_t)t0_w   << 16) - mul_shr4(v0.x, raw_dv_dx) - mul_shr4(v0.y, raw_dt_dy);
    int64_t raw_start_r = ((int64_t)r0_w   << 16) - mul_shr4(v0.x, raw_dr_dx) - mul_shr4(v0.y, raw_dr_dy);
    int64_t raw_start_g = ((int64_t)g0_w   << 16) - mul_shr4(v0.x, raw_dg_dx) - mul_shr4(v0.y, raw_dg_dy);
    int64_t raw_start_b = ((int64_t)b0_w   << 16) - mul_shr4(v0.x, raw_db_dx) - mul_shr4(v0.y, raw_db_dy);    

    // -------------------------------------------------------------------------
    // DOWN-SHIFT & QUANTIZE PACKETS INTO NATIVE 32-BIT REGISTER TYPES
    // -------------------------------------------------------------------------
    // W parameters pack into 4.28 format (Drop lowest 4 fractional bits from 32.32)
    int32_t start_w = (int32_t)(raw_start_w >> 4);
    int32_t dw_dx   = (int32_t)(raw_dw_dx   >> 4);
    int32_t dw_dy   = (int32_t)(raw_dw_dy   >> 4);

    // S, T parameters pack into 14.18 format (Drop lowest 14 fractional bits from 32.32)
    int32_t start_s = (int32_t)(raw_start_s >> 14);
    int32_t du_dx   = (int32_t)(raw_du_dx   >> 14);
    int32_t du_dy   = (int32_t)(raw_ds_dy   >> 14);

    int32_t start_t = (int32_t)(raw_start_t >> 14);
    int32_t dv_dx   = (int32_t)(raw_dv_dx   >> 14);
    int32_t dv_dy   = (int32_t)(raw_dt_dy   >> 14);

    // R, G, B parameters pack into 12.12 format (Drop lowest 20 fractional bits from 32.32)
    // Sign extension from bit 24 keeps them strictly bounded 24-bit inputs
    int32_t start_r = ((int32_t)(raw_start_r >> 20) << 8) >> 8;
    int32_t dr_dx   = ((int32_t)(raw_dr_dx   >> 20) << 8) >> 8;
    int32_t dr_dy   = ((int32_t)(raw_dr_dy   >> 20) << 8) >> 8;

    int32_t start_g = ((int32_t)(raw_start_g >> 20) << 8) >> 8;
    int32_t dg_dx   = ((int32_t)(raw_dg_dx   >> 20) << 8) >> 8;
    int32_t dg_dy   = ((int32_t)(raw_dg_dy   >> 20) << 8) >> 8;

    int32_t start_b = ((int32_t)(raw_start_b >> 20) << 8) >> 8;
    int32_t db_dx   = ((int32_t)(raw_db_dx   >> 20) << 8) >> 8;
    int32_t db_dy   = ((int32_t)(raw_db_dy   >> 20) << 8) >> 8;

    draw_triangle_serpentine_ras(v0, v1, v2, start_w, start_s, start_t, start_r, start_g, start_b, 
                             dw_dx, du_dx, dv_dx, dr_dx, dg_dx, db_dx, 
                             dw_dy, du_dy, dv_dy, dr_dy, dg_dy, db_dy, det > 0, texture_enabled, depth_test, perspective_correct);
}

void sw_draw_triangle_standard(fx32 x0, fx32 y0, fx32 w0, fx32 s0, fx32 t0, fx32 r0, fx32 g0, fx32 b0, fx32 a0,
                      fx32 x1, fx32 y1, fx32 w1, fx32 s1, fx32 t1, fx32 r1, fx32 g1, fx32 b1, fx32 a1,
                      fx32 x2, fx32 y2, fx32 w2, fx32 s2, fx32 t2, fx32 r2, fx32 g2, fx32 b2, fx32 a2,
                      bool texture, bool clamp_s, bool clamp_t, bool depth_test, bool persp_correct) {
    Vertex v0, v1, v2;

    v0.x = FX32_TO_FIXED16(x0); v0.y = FX32_TO_FIXED16(y0); v0.w = FX32_TO_FIXED16(w0); v0.s = FX32_TO_FIXED16(MUL(s0, FXI(TEX_WIDTH))); v0.t = FX32_TO_FIXED16(MUL(t0, FXI(TEX_HEIGHT))); v0.r = FX32_TO_FIXED16(MUL(r0, FXI(255))); v0.g = FX32_TO_FIXED16(MUL(g0, FXI(255))); v0.b = FX32_TO_FIXED16(MUL(b0, FXI(255)));
    v1.x = FX32_TO_FIXED16(x1); v1.y = FX32_TO_FIXED16(y1); v1.w = FX32_TO_FIXED16(w1); v1.s = FX32_TO_FIXED16(MUL(s1, FXI(TEX_WIDTH))); v1.t = FX32_TO_FIXED16(MUL(t1, FXI(TEX_HEIGHT))); v1.r = FX32_TO_FIXED16(MUL(r1, FXI(255))); v1.g = FX32_TO_FIXED16(MUL(g1, FXI(255))); v1.b = FX32_TO_FIXED16(MUL(b1, FXI(255)));
    v2.x = FX32_TO_FIXED16(x2); v2.y = FX32_TO_FIXED16(y2); v2.w = FX32_TO_FIXED16(w2); v2.s = FX32_TO_FIXED16(MUL(s2, FXI(TEX_WIDTH))); v2.t = FX32_TO_FIXED16(MUL(t2, FXI(TEX_HEIGHT))); v2.r = FX32_TO_FIXED16(MUL(r2, FXI(255))); v2.g = FX32_TO_FIXED16(MUL(g2, FXI(255))); v2.b = FX32_TO_FIXED16(MUL(b2, FXI(255)));
    draw_triangle(v0, v1, v2, texture, depth_test, persp_correct);
}
