#ifndef MATRIX_H
#define MATRIX_H

#include "vector.h"

typedef struct {
    fix16_t m[4][4]; 
} mat4_t;

mat4_t mat4_identity(void);
mat4_t mat4_make_scale(fix16_t sx, fix16_t sy, fix16_t sz);
mat4_t mat4_make_translation(fix16_t tx, fix16_t ty, fix16_t tz);
mat4_t mat4_make_rotation_x(fix16_t angle);
mat4_t mat4_make_rotation_y(fix16_t angle);
mat4_t mat4_make_rotation_z(fix16_t angle);
mat4_t mat4_make_perspective(fix16_t fov, fix16_t aspect, fix16_t znear, fix16_t zfar);
vec4_t mat4_mul_vec4(mat4_t m, vec4_t v);
mat4_t mat4_mul_mat4(mat4_t a, mat4_t b);
vec4_t mat4_mul_vec4_project(mat4_t mat_proj, vec4_t v);
mat4_t mat4_look_at(vec3_t eye, vec3_t target, vec3_t up);

#endif