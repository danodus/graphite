#include <libfixmath/fix16.h>

#include "triangle.h"
#include "swap.h"

#include "display.h"

vec3_t get_triangle_normal(vec4_t vertices[3]) {

    vec3_t vector_a = vec3_from_vec4(vertices[0]); /*   A   */
    vec3_t vector_b = vec3_from_vec4(vertices[1]); /*  / \  */
    vec3_t vector_c = vec3_from_vec4(vertices[2]); /* C---B */

    // Get the vector substraction of B-A and C-A
    vec3_t vector_ab = vec3_sub(vector_b, vector_a);
    vec3_t vector_ac = vec3_sub(vector_c, vector_a);
    vec3_normalize(&vector_ab);
    vec3_normalize(&vector_ac);

    vec3_t normal = vec3_cross(vector_ab, vector_ac);
    vec3_normalize(&normal);

    return normal;
}

///////////////////////////////////////////////////////////////////////////////
// Draw a triangle
///////////////////////////////////////////////////////////////////////////////
void draw_triangle(int x0, int y0, int x1, int y1, int x2, int y2, uint16_t color) {
    draw_line(x0, y0, x1, y1, color);
    draw_line(x1, y1, x2, y2, color);
    draw_line(x2, y2, x0, y0, color);
}

///////////////////////////////////////////////////////////////////////////////
// Return the barycentric weights alpha, beta and gamma for point p
///////////////////////////////////////////////////////////////////////////////
//
//       B
//      / 
//     /(p)
//    A-----C
///////////////////////////////////////////////////////////////////////////////
vec3_t barycentric_weights(vec2_t a, vec2_t b, vec2_t c, vec2_t p) {
    // Find the vectors vetween the vertices ABC and point p
    vec2_t ac = vec2_sub(c, a);
    vec2_t ab = vec2_sub(b, a);
    vec2_t ap = vec2_sub(p, a);
    vec2_t pc = vec2_sub(c, p);
    vec2_t pb = vec2_sub(b, p);

    // Compute the area of the full parallelogram/triangle ABC using 2D cross product
    fix16_t area_parallelogram_abc = fix16_mul(ac.x, ab.y) - fix16_mul(ac.y, ab.x); // || AC x AB ||

    // Alpha is the area of the small parallelogram/triangle PBC divided by the area of the full parallelogram/triangle ABC
    fix16_t alpha = fix16_div(fix16_mul(pc.x, pb.y) - fix16_mul(pc.y, pb.x), area_parallelogram_abc);

    // Beta is the area of the small parallelogram/triangle APC divided by the area of the full parallelogram/triangle ABC
    fix16_t beta = fix16_div(fix16_mul(ac.x, ap.y) - fix16_mul(ac.y, ap.x), area_parallelogram_abc);

    // Weight gamma is easily found since barycentric coordinates always add up to 1.0
    fix16_t gamma = fix16_from_float(1) - alpha - beta;

    vec3_t weights = { alpha, beta, gamma };
    return weights;
}

///////////////////////////////////////////////////////////////////////////////
// Function to draw a pixel using depth interpolation
///////////////////////////////////////////////////////////////////////////////
void draw_triangle_pixel(
    int x, int y, uint16_t color,
    vec4_t point_a, vec4_t point_b, vec4_t point_c
) {
    vec2_t p = { fix16_from_int(x), fix16_from_int(y) };
    vec2_t a = vec2_from_vec4(point_a);
    vec2_t b = vec2_from_vec4(point_b);
    vec2_t c = vec2_from_vec4(point_c);

    vec3_t weights = barycentric_weights(a, b, c, p);

    fix16_t alpha = weights.x;
    fix16_t beta = weights.y;
    fix16_t gamma = weights.z;

    // Variable to store the interpolated 1/w for the current pixel
    fix16_t interpolated_reciprocal_w;

    // Interpolate the value of 1/w for the current pixel
    interpolated_reciprocal_w = fix16_mul(fix16_div(fix16_from_float(1), point_a.w), alpha) + fix16_mul(fix16_div(fix16_from_float(1), point_b.w), beta) + fix16_mul(fix16_div(fix16_from_float(1), point_c.w), gamma);

    // Adjust 1/w so the pixels that are closer to the camera have smaller values
    interpolated_reciprocal_w = fix16_from_float(1.0) - interpolated_reciprocal_w;

    // Only draw a pixel if the depth value is less than the one previously stored in the z-buffer
    if (interpolated_reciprocal_w < get_zbuffer_at(x, y)) {
        draw_pixel(x, y, color);

        // Update the z-buffer value with the 1/w of this current pixel
        update_zbuffer_at(x, y, interpolated_reciprocal_w);
    }
}

///////////////////////////////////////////////////////////////////////////////
// Draw a filled triangle with the flat-top/flat-bottom method
// We split the original triangle in two, half flat-bottom and half flat-top
///////////////////////////////////////////////////////////////////////////////
void draw_filled_triangle(
    int x0, int y0, fix16_t z0, fix16_t w0,
    int x1, int y1, fix16_t z1, fix16_t w1,
    int x2, int y2, fix16_t z2, fix16_t w2,
    uint16_t color) {
    // We need to sort the vertices by y-coordinate ascending (y0 < y1 < y2)
    if (y0 > y1) {
        int_swap(&y0, &y1);
        int_swap(&x0, &x1);
        fix16_swap(&z0, &z1);
        fix16_swap(&w0, &w1);        
    }
    if (y1 > y2) {
        int_swap(&y1, &y2);
        int_swap(&x1, &x2);
        fix16_swap(&z1, &z2);
        fix16_swap(&w1, &w2);
    }
    if (y0 > y1) {
        int_swap(&y0, &y1);
        int_swap(&x0, &x1);
        fix16_swap(&z0, &z1);
        fix16_swap(&w0, &w1);
    }

    // Create vector points and texture coordinates after we sort the vertices
    vec4_t point_a = { fix16_from_int(x0), fix16_from_int(y0), z0, w0 };
    vec4_t point_b = { fix16_from_int(x1), fix16_from_int(y1), z1, w1 };
    vec4_t point_c = { fix16_from_int(x2), fix16_from_int(y2), z2, w2 };

    ////////////////////////////////////////////////////////
    // Render the upper part of the triangle (flat-bottom)
    ////////////////////////////////////////////////////////

    fix16_t inv_slope_1 = 0;
    fix16_t inv_slope_2 = 0;

    if (y1 - y0 != 0) inv_slope_1 = fix16_div(fix16_from_int(x1 - x0), fix16_from_int(abs(y1 - y0)));
    if (y2 - y0 != 0) inv_slope_2 = fix16_div(fix16_from_int(x2 - x0), fix16_from_int(abs(y2 - y0)));

    if (y1 - y0 != 0) {
        for (int y = y0; y <= y1; y++) {
          
            int x_start = x1 + fix16_to_int(fix16_mul(fix16_from_int(y - y1), inv_slope_1));
            int x_end = x0 + fix16_to_int(fix16_mul(fix16_from_int(y - y0), inv_slope_2));

            // Swap if x_start is to the right of x_end
            if (x_end < x_start) {
                int_swap(&x_start, &x_end);
            }

            for (int x = x_start; x < x_end; x++) {
                // Draw our pixel with the color
                draw_triangle_pixel(x, y, color, point_a, point_b, point_c);
            }
        }
    }

    ////////////////////////////////////////////////////////
    // Render the bottom part of the triangle (flat-bottom)
    ////////////////////////////////////////////////////////

    inv_slope_1 = 0;
    inv_slope_2 = 0;

    if (y2 - y1 != 0) inv_slope_1 = fix16_div(fix16_from_int(x2 - x1), fix16_from_int(abs(y2 - y1)));
    if (y2 - y0 != 0) inv_slope_2 = fix16_div(fix16_from_int(x2 - x0), fix16_from_int(abs(y2 - y0)));

    if (y2 - y1 != 0) {
        for (int y = y1; y <= y2; y++) {
            int x_start = x1 + fix16_to_int(fix16_mul(fix16_from_int(y - y1), inv_slope_1));
            int x_end = x0 + fix16_to_int(fix16_mul(fix16_from_int(y - y0), inv_slope_2));

            // Swap if x_start is to the right of x_end
            if (x_end < x_start) {
                int_swap(&x_start, &x_end);
            }

            for (int x = x_start; x < x_end; x++) {
                // Draw our pixel with the color
                draw_triangle_pixel(x, y, color, point_a, point_b, point_c);
            }
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
// Function to draw textured pixel at position x and y using interpolation
///////////////////////////////////////////////////////////////////////////////
void draw_texel(
    int x, int y, upng_t* texture,
    vec4_t point_a, vec4_t point_b, vec4_t point_c,
    tex2_t a_uv, tex2_t b_uv, tex2_t c_uv
) {
    vec2_t p = { fix16_from_int(x), fix16_from_int(y) };
    vec2_t a = vec2_from_vec4(point_a);
    vec2_t b = vec2_from_vec4(point_b);
    vec2_t c = vec2_from_vec4(point_c);

    vec3_t weights = barycentric_weights(a, b, c, p);

    fix16_t alpha = weights.x;
    fix16_t beta = weights.y;
    fix16_t gamma = weights.z;

    // Variables to store the interpolated values of U, V and also 1/w for the current pixel
    fix16_t interpolated_u;
    fix16_t interpolated_v;
    fix16_t interpolated_reciprocal_w;

    // Perform the intepolation of all U/w and V/w values using barycentric weights and a factor of 1/w
    interpolated_u = fix16_mul(fix16_div(a_uv.u, point_a.w), alpha) + fix16_mul(fix16_div(b_uv.u, point_b.w), beta) + fix16_mul(fix16_div(c_uv.u, point_c.w), gamma);
    interpolated_v = fix16_mul(fix16_div(a_uv.v, point_a.w), alpha) + fix16_mul(fix16_div(b_uv.v, point_b.w), beta) + fix16_mul(fix16_div(c_uv.v, point_c.w), gamma);

    // Also interpolate the value of 1/w for the current pixel
    interpolated_reciprocal_w = fix16_mul(fix16_div(fix16_from_float(1), point_a.w), alpha) + fix16_mul(fix16_div(fix16_from_float(1), point_b.w), beta) + fix16_mul(fix16_div(fix16_from_float(1), point_c.w), gamma);

    // Now we can divide back both interpolated values by 1/w
    interpolated_u = fix16_div(interpolated_u, interpolated_reciprocal_w);
    interpolated_v = fix16_div(interpolated_v, interpolated_reciprocal_w);

    // Get the mesh texture width and height dimensions
    int texture_width = upng_get_width(texture);
    int texture_height = upng_get_height(texture);

    // Map the UV coordinate to the full texture width and height
    int tex_x = abs(fix16_to_int(fix16_mul(interpolated_u, fix16_from_int(texture_width)))) % texture_width;
    int tex_y = abs(fix16_to_int(fix16_mul(interpolated_v, fix16_from_int(texture_height)))) % texture_height;

    // Adjust 1/w so the pixels that are closer to the camera have smaller values
    interpolated_reciprocal_w = fix16_from_float(1.0) - interpolated_reciprocal_w;

    // Only draw a pixel if the depth value is less than the one previously stored in the z-buffer
    if (interpolated_reciprocal_w < get_zbuffer_at(x, y)) {
        // Get the buffer of colors from the texture
        uint32_t* texture_buffer = (uint32_t *)upng_get_buffer(texture);

        uint8_t* tc = (uint8_t*)(&texture_buffer[(texture_width * tex_y) + tex_x]);
        uint16_t cr = tc[0] >> 4;
        uint16_t cg = tc[1] >> 4;
        uint16_t cb = tc[2] >> 4;
        uint16_t ca = tc[3] >> 4;
        uint16_t color = (ca << 12) | (cr << 8) | (cg << 4) | cb;

        draw_pixel(x, y, color);

        // Update the z-buffer value with the 1/w of this current pixel
        update_zbuffer_at(x, y, interpolated_reciprocal_w);
    }
}

///////////////////////////////////////////////////////////////////////////////
// Draw a textured triangle with the flat-top/flat-bottom method
// We split the original triangle in two, half flat-bottom and half flat-top
///////////////////////////////////////////////////////////////////////////////
void draw_textured_triangle(
    int x0, int y0, fix16_t z0, fix16_t w0, fix16_t u0, fix16_t v0,
    int x1, int y1, fix16_t z1, fix16_t w1, fix16_t u1, fix16_t v1,
    int x2, int y2, fix16_t z2, fix16_t w2, fix16_t u2, fix16_t v2,
    upng_t* texture
) {
    // We need to sort the vertices by y-coordinate ascending (y0 < y1 < y2)
    if (y0 > y1) {
        int_swap(&y0, &y1);
        int_swap(&x0, &x1);
        fix16_swap(&z0, &z1);
        fix16_swap(&w0, &w1);        
        fix16_swap(&u0, &u1);
        fix16_swap(&v0, &v1);
    }
    if (y1 > y2) {
        int_swap(&y1, &y2);
        int_swap(&x1, &x2);
        fix16_swap(&z1, &z2);
        fix16_swap(&w1, &w2);
        fix16_swap(&u1, &u2);
        fix16_swap(&v1, &v2);
    }
    if (y0 > y1) {
        int_swap(&y0, &y1);
        int_swap(&x0, &x1);
        fix16_swap(&z0, &z1);
        fix16_swap(&w0, &w1);
        fix16_swap(&u0, &u1);
        fix16_swap(&v0, &v1);
    }

    // Flip the V component for inverted UV-coordinates (V grows downwards)
    v0 = fix16_from_float(1.0) - v0;
    v1 = fix16_from_float(1.0) - v1;
    v2 = fix16_from_float(1.0) - v2;

    // Create vector points and texture coordinates after we sort the vertices
    vec4_t point_a = { fix16_from_int(x0), fix16_from_int(y0), z0, w0 };
    vec4_t point_b = { fix16_from_int(x1), fix16_from_int(y1), z1, w1 };
    vec4_t point_c = { fix16_from_int(x2), fix16_from_int(y2), z2, w2 };
    tex2_t a_uv = { u0, v0 };
    tex2_t b_uv = { u1, v1 };
    tex2_t c_uv = { u2, v2 };

    ////////////////////////////////////////////////////////
    // Render the upper part of the triangle (flat-bottom)
    ////////////////////////////////////////////////////////

    fix16_t inv_slope_1 = 0;
    fix16_t inv_slope_2 = 0;

    if (y1 - y0 != 0) inv_slope_1 = fix16_div(fix16_from_int(x1 - x0), fix16_from_int(abs(y1 - y0)));
    if (y2 - y0 != 0) inv_slope_2 = fix16_div(fix16_from_int(x2 - x0), fix16_from_int(abs(y2 - y0)));

    if (y1 - y0 != 0) {
        for (int y = y0; y <= y1; y++) {
          
            int x_start = x1 + fix16_to_int(fix16_mul(fix16_from_int(y - y1), inv_slope_1));
            int x_end = x0 + fix16_to_int(fix16_mul(fix16_from_int(y - y0), inv_slope_2));

            // Swap if x_start is to the right of x_end
            if (x_end < x_start) {
                int_swap(&x_start, &x_end);
            }

            for (int x = x_start; x < x_end; x++) {
                // Draw our pixel with the color that comes from the texture
                draw_texel(x, y, texture, point_a, point_b, point_c, a_uv, b_uv, c_uv);
            }
        }
    }

    ////////////////////////////////////////////////////////
    // Render the bottom part of the triangle (flat-bottom)
    ////////////////////////////////////////////////////////

    inv_slope_1 = 0;
    inv_slope_2 = 0;

    if (y2 - y1 != 0) inv_slope_1 = fix16_div(fix16_from_int(x2 - x1), fix16_from_int(abs(y2 - y1)));
    if (y2 - y0 != 0) inv_slope_2 = fix16_div(fix16_from_int(x2 - x0), fix16_from_int(abs(y2 - y0)));

    if (y2 - y1 != 0) {
        for (int y = y1; y <= y2; y++) {
            int x_start = x1 + fix16_to_int(fix16_mul(fix16_from_int(y - y1), inv_slope_1));
            int x_end = x0 + fix16_to_int(fix16_mul(fix16_from_int(y - y0), inv_slope_2));

            // Swap if x_start is to the right of x_end
            if (x_end < x_start) {
                int_swap(&x_start, &x_end);
            }

            for (int x = x_start; x < x_end; x++) {
                // Draw our pixel with the color that comes from the texture
                draw_texel(x, y, texture, point_a, point_b, point_c, a_uv, b_uv, c_uv);
            }
        }
    }
}
