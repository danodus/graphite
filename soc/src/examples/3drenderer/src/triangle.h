#ifndef TRIANGLE_H
#define TRIANGLE_H

#include <stdint.h>

#include "vector.h"
#include "texture.h"
#include "upng.h"

typedef struct {
    int a;
    int b;
    int c;
    tex2_t a_uv;
    tex2_t b_uv;
    tex2_t c_uv;
    uint16_t color;
} face_t;

typedef struct {
    vec4_t points[3];
    tex2_t texcoords[3];
    uint16_t color;
    upng_t* texture;
} triangle_t;

vec3_t get_triangle_normal(vec4_t vertices[3]);

void draw_triangle(int x0, int y0, int x1, int y1, int x2, int y2, uint16_t color);
void draw_filled_triangle(
    int x0, int y0, fix16_t z0, fix16_t w0,
    int x1, int y1, fix16_t z1, fix16_t w1,
    int x2, int y2, fix16_t z2, fix16_t w2,
    uint16_t color
);
void draw_textured_triangle(
    int x0, int y0, fix16_t z0, fix16_t w0, fix16_t u0, fix16_t v0,
    int x1, int y1, fix16_t z1, fix16_t w1, fix16_t u1, fix16_t v1,
    int x2, int y2, fix16_t z2, fix16_t w2, fix16_t u2, fix16_t v2,
    upng_t* texture
);

#endif