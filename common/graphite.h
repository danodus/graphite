// graphite.h
// Copyright (c) 2021-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef GRAPHITE_H
#define GRAPHITE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifndef FIXED_POINT
#define FIXED_POINT 1
#endif

#define _FRACTION_MASK(scale) (0xffffffff >> (32 - scale))
#define _WHOLE_MASK(scale) (0xffffffff ^ FRACTION_MASK(scale))

#define _FLOAT_TO_FIXED(x, scale) ((int32_t)((x) * (float)(1 << scale)))
#define _FIXED_TO_FLOAT(x, scale) ((float)(x) / (double)(1 << scale))
#define _INT_TO_FIXED(x, scale) ((x) << scale)
#define _FIXED_TO_INT(x, scale) ((x) >> scale)
#define _FRACTION_PART(x, scale) ((x)&FRACTION_MASK(scale))
#define _WHOLE_PART(x, scale) ((x)&WHOLE_MASK(scale))

#define _MUL(x, y, scale) (int32_t)(((int64_t)(x) * (int64_t)(y)) >> scale)
#define _DIV(x, y, scale) (int32_t)(((int64_t)(x) << scale) / (y))

#if FIXED_POINT

typedef int32_t fx32;

#define SCALE 14

#define FX(x) ((fx32)_FLOAT_TO_FIXED(x, SCALE))
#define FXI(x) ((fx32)_INT_TO_FIXED(x, SCALE))
#define INT(x) ((int)_FIXED_TO_INT(x, SCALE))
#define FLT(x) ((float)_FIXED_TO_FLOAT(x, SCALE))
#define DIV(x, y) _DIV(x, y, SCALE)

#define SIN(x) FX(sinf(_FIXED_TO_FLOAT(x, SCALE)))
#define COS(x) FX(cosf(_FIXED_TO_FLOAT(x, SCALE)))
#define TAN(x) FX(tanf(_FIXED_TO_FLOAT(x, SCALE)))
#define SQRT(x) FX(sqrtf(_FIXED_TO_FLOAT(x, SCALE)))

#if RV_FIXED_POINT_EXTENSION
// Accelerated
inline fx32 fix_mul(fx32 a, fx32 b) {
    int result;
    // .insn r opcode6, func3, func7, rd, rs1, rs2
    asm (".insn r 0x0b, 0, 0, %0, %1, %2" : "=r" (result) : "r" (a), "r" (b)); 
    return result; 
}
#define MUL(x, y) fix_mul(x, y)
#else
#define MUL(x, y) _MUL(x, y, SCALE)
#endif

#else

typedef float fx32;

#define FX(x) (x)
#define FXI(x) ((float)(x))
#define INT(x) ((int)(x))
#define FLT(x) (x)
#define MUL(x, y) ((x) * (y))
#define DIV(x, y) ((x) / (y))

#define SIN(x) (sinf(x))
#define COS(x) (cosf(x))
#define TAN(x) (tanf(x))
#define SQRT(x) (sqrtf(x))

#endif

typedef struct {
    fx32 u, v, w;
} vec2d;

typedef struct {
    fx32 x, y, z, w;
} vec3d;

typedef struct {
    fx32 m[4][4];
} mat4x4;

typedef struct {
    int indices[3];
    int tex_indices[3];
    int col_indices[3];
    int norm_indices[3];
} face_t;

typedef struct {
    vec3d p[3];
    vec2d t[3];
    vec3d c[3];
    vec3d n[3];
} triangle_t;

typedef struct {
    size_t nb_vertices;
    size_t nb_texcoords;
    size_t nb_colors;
    size_t nb_normals;
    size_t nb_faces;
    vec3d* vertices;
    vec2d* texcoords;
    vec3d* colors;
    vec3d* normals;
    face_t* faces;
} mesh_t;

typedef struct {
    mesh_t mesh;

    // Internal buffers
    triangle_t* triangles_to_raster;
} model_t;

typedef struct {
    size_t width, height;
    unsigned char* data;
} texture_t;

typedef struct {
    vec3d direction;
    vec3d ambient_color;
    vec3d diffuse_color;
} light_t;

vec3d matrix_multiply_vector(mat4x4* m, vec3d* i);
vec3d vector_add(vec3d* v1, vec3d* v2);
vec3d vector_sub(vec3d* v1, vec3d* v2);
vec3d vector_mul(vec3d* v1, fx32 k);
vec3d vector_div(vec3d* v1, fx32 k);
fx32 vector_dot_product(vec3d* v1, vec3d* v2);
fx32 vector_length(vec3d* v);
vec3d vector_normalize(vec3d* v);
vec3d vector_cross_product(vec3d* v1, vec3d* v2);
vec3d vector_clamp(vec3d* v);

mat4x4 matrix_make_identity();
mat4x4 matrix_make_projection(int viewport_width, int viewport_height, float fov);
mat4x4 matrix_make_rotation_x(float theta);
mat4x4 matrix_make_rotation_y(float theta);
mat4x4 matrix_make_rotation_z(float theta);
mat4x4 matrix_make_translation(fx32 x, fx32 y, fx32 z);
mat4x4 matrix_make_scale(fx32 x, fx32 y, fx32 z);
mat4x4 matrix_multiply_matrix(mat4x4* m1, mat4x4* m2);
mat4x4 matrix_point_at(vec3d* pos, vec3d* target, vec3d* up);
mat4x4 matrix_quick_inverse(mat4x4* m);

void draw_line(vec3d v0, vec3d v1, vec2d uv0, vec2d uv1, vec3d c0, vec3d c1, fx32 thickness, texture_t* texture,
                bool clamp_s, bool clamp_t, int texture_scale_x, int texture_scale_y, bool perspective_correct);

void draw_model(int viewport_width, int viewport_height, vec3d* vec_camera, model_t* model, mat4x4* mat_world,
                mat4x4* mat_normal, mat4x4* mat_projection, mat4x4* mat_view, light_t* lights, size_t nb_lights, bool is_wireframe, texture_t* texture,
                bool clamp_s, bool clamp_t, int texture_scale_x, int texture_scale_y, bool perspective_correct);

#endif