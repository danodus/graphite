#ifndef VECTOR_H
#define VECTOR_H

#include <libfixmath/fix16.h>

typedef struct {
    fix16_t x, y;
} vec2_t;

typedef struct {
    fix16_t x, y, z;
} vec3_t;

typedef struct {
    fix16_t x, y, z, w;
} vec4_t;

///////////////////////////////////////////////////////////////////////////////
// Vector 2 functions
///////////////////////////////////////////////////////////////////////////////
vec2_t vec2_new(fix16_t x, fix16_t y);
fix16_t vec2_length(vec2_t v);
vec2_t vec2_add(vec2_t a, vec2_t b);
vec2_t vec2_sub(vec2_t a, vec2_t b);
vec2_t vec2_mul(vec2_t v, fix16_t factor);
vec2_t vec2_div(vec2_t v, fix16_t factor);
fix16_t vec2_dot(vec2_t a, vec2_t b);
void vec2_normalize(vec2_t* v);

///////////////////////////////////////////////////////////////////////////////
// Vector 3 functions
///////////////////////////////////////////////////////////////////////////////
vec3_t vec3_new(fix16_t x, fix16_t y, fix16_t z);
vec3_t vec3_clone(vec3_t* v);
fix16_t vec3_length(vec3_t v);
vec3_t vec3_add(vec3_t a, vec3_t b);
vec3_t vec3_sub(vec3_t a, vec3_t b);
vec3_t vec3_mul(vec3_t v, fix16_t factor);
vec3_t vec3_div(vec3_t v, fix16_t factor);
vec3_t vec3_cross(vec3_t a, vec3_t b);
fix16_t vec3_dot(vec3_t a, vec3_t b);
void vec3_normalize(vec3_t* v);

vec3_t vec3_rotate_x(vec3_t v, fix16_t angle);
vec3_t vec3_rotate_y(vec3_t v, fix16_t angle);
vec3_t vec3_rotate_z(vec3_t v, fix16_t angle);

///////////////////////////////////////////////////////////////////////////////
// Vector conversion functions
///////////////////////////////////////////////////////////////////////////////
vec4_t vec4_from_vec3(vec3_t v);
vec3_t vec3_from_vec4(vec4_t v);
vec2_t vec2_from_vec4(vec4_t v);

#endif
