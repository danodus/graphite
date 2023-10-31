#include <math.h>

#include "vector.h"

///////////////////////////////////////////////////////////////////////////////
// Implementations of Vector 2 functions
///////////////////////////////////////////////////////////////////////////////

vec2_t vec2_new(fix16_t x, fix16_t y) {
    vec2_t result = { x, y };
    return result;
}

fix16_t vec2_length(vec2_t v) {
    return fix16_sqrt(fix16_mul(v.x, v.x) + fix16_mul(v.y, v.y));
}

vec2_t vec2_add(vec2_t a, vec2_t b) {
    vec2_t result = {
        .x = a.x + b.x,
        .y = a.y + b.y
    };
    return result;
}

vec2_t vec2_sub(vec2_t a, vec2_t b) {
    vec2_t result = {
        .x = a.x - b.x,
        .y = a.y - b.y
    };
    return result;
}

vec2_t vec2_mul(vec2_t v, fix16_t factor) {
    vec2_t result = {
        .x = fix16_mul(v.x, factor),
        .y = fix16_mul(v.y, factor)
    };
    return result;
}

vec2_t vec2_div(vec2_t v, fix16_t factor) {
    vec2_t result = {
        .x = fix16_div(v.x, factor),
        .y = fix16_div(v.y, factor)
    };
    return result;
}

fix16_t vec2_dot(vec2_t a, vec2_t b) {
    return fix16_mul(a.x, b.x) + fix16_mul(a.y, b.y);
}

void vec2_normalize(vec2_t* v) {
    fix16_t length = fix16_sqrt(fix16_mul(v->x, v->x) + fix16_mul(v->y, v->y));
    v->x = fix16_div(v->x, length);
    v->y = fix16_div(v->y, length);
}

///////////////////////////////////////////////////////////////////////////////
// Implementations of Vector 3 functions
///////////////////////////////////////////////////////////////////////////////

vec3_t vec3_new(fix16_t x, fix16_t y, fix16_t z) {
    vec3_t result = { x, y, z };
    return result;
}

vec3_t vec3_clone(vec3_t* v) {
    vec3_t result = { v->x, v->y, v->z };
    return result;
}

fix16_t vec3_length(vec3_t v) {
    return fix16_sqrt(fix16_mul(v.x, v.x) + fix16_mul(v.y, v.y) + fix16_mul(v.z, v.z));
}

vec3_t vec3_add(vec3_t a, vec3_t b) {
    vec3_t result = {
        .x = a.x + b.x,
        .y = a.y + b.y,
        .z = a.z + b.z
    };
    return result;
}

vec3_t vec3_sub(vec3_t a, vec3_t b) {
    vec3_t result = {
        .x = a.x - b.x,
        .y = a.y - b.y,
        .z = a.z - b.z
    };
    return result;
}

vec3_t vec3_mul(vec3_t v, fix16_t factor) {
    vec3_t result = {
        .x = fix16_mul(v.x, factor),
        .y = fix16_mul(v.y, factor),
        .z = fix16_mul(v.z, factor)
    };
    return result;
}

vec3_t vec3_div(vec3_t v, fix16_t factor) {
    vec3_t result = {
        .x = fix16_div(v.x, factor),
        .y = fix16_div(v.y, factor),
        .z = fix16_div(v.z, factor)
    };
    return result;
}

vec3_t vec3_cross(vec3_t a, vec3_t b) {
    vec3_t result = {
        .x = fix16_mul(a.y, b.z) - fix16_mul(a.z, b.y),
        .y = fix16_mul(a.z, b.x) - fix16_mul(a.x, b.z),
        .z = fix16_mul(a.x, b.y) - fix16_mul(a.y, b.x)
    };
    return result;
}

fix16_t vec3_dot(vec3_t a, vec3_t b) {
    return fix16_mul(a.x, b.x) + fix16_mul(a.y, b.y) + fix16_mul(a.z, b.z);
}

void vec3_normalize(vec3_t* v) {
    fix16_t length = fix16_sqrt(fix16_mul(v->x, v->x) + fix16_mul(v->y, v->y) + fix16_mul(v->z, v->z));
    v->x = fix16_div(v->x, length);
    v->y = fix16_div(v->y, length);
    v->z = fix16_div(v->z, length);
}

vec3_t vec3_rotate_x(vec3_t v, fix16_t angle) {
    vec3_t rotated_vector = {
        .x = v.x,
        .y = fix16_mul(v.y, fix16_cos(angle)) - fix16_mul(v.z, fix16_sin(angle)),
        .z = fix16_mul(v.y, fix16_sin(angle)) + fix16_mul(v.z, fix16_cos(angle))
    };
    return rotated_vector;
}

vec3_t vec3_rotate_y(vec3_t v, fix16_t angle) {
    vec3_t rotated_vector = {
        .x = fix16_mul(v.x, fix16_cos(angle)) - fix16_mul(v.z, fix16_sin(angle)),
        .y = v.y,
        .z = fix16_mul(v.x, fix16_sin(angle)) + fix16_mul(v.z, fix16_cos(angle))
    };
    return rotated_vector;
}

vec3_t vec3_rotate_z(vec3_t v, fix16_t angle) {
    vec3_t rotated_vector = {
        .x = fix16_mul(v.x, fix16_cos(angle)) - fix16_mul(v.y, fix16_sin(angle)),
        .y = fix16_mul(v.x, fix16_sin(angle)) + fix16_mul(v.y, fix16_cos(angle)),
        .z = v.z,
    };
    return rotated_vector;
}

///////////////////////////////////////////////////////////////////////////////
// Implementation of vector conversion functions
///////////////////////////////////////////////////////////////////////////////

vec4_t vec4_from_vec3(vec3_t v) {
    vec4_t result = { v.x, v.y, v.z, fix16_from_float(1.0) };
    return result;
}

vec3_t vec3_from_vec4(vec4_t v) {
    vec3_t result = { v.x, v.y, v.z };
    return result;
}

vec2_t vec2_from_vec4(vec4_t v) {
    vec2_t result = { v.x, v.y };
    return result;
}
