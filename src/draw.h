// draw.h
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef DRAW_H
#define DRAW_H

#include <stdbool.h>
#include <stddef.h>

#include "fx.h"
#include "glide.h"

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
} face_t;

typedef struct {
    vec3d p[3];
    vec2d t[3];
    vec3d c[3];
} triangle_t;

typedef struct {
    size_t nb_vertices;
    size_t nb_texcoords;
    size_t nb_colors;
    size_t nb_faces;
    vec3d* vertices;
    vec2d* texcoords;
    vec3d* colors;
    face_t* faces;
} mesh_t;

typedef struct {
    mesh_t mesh;

    // Internal buffers
    triangle_t* triangles_to_raster;
} model_t;

vec3d matrix_multiply_vector(mat4x4* m, vec3d* i);
vec3d vector_add(vec3d* v1, vec3d* v2);
vec3d vector_sub(vec3d* v1, vec3d* v2);
vec3d vector_mul(vec3d* v1, fx32 k);
vec3d vector_div(vec3d* v1, fx32 k);
fx32 vector_dot_product(vec3d* v1, vec3d* v2);
fx32 vector_length(vec3d* v);
vec3d vector_normalize(vec3d* v);
vec3d vector_cross_product(vec3d* v1, vec3d* v2);

mat4x4 matrix_make_identity();
mat4x4 matrix_make_projection(int viewport_width, int viewport_height, float fov);
mat4x4 matrix_make_rotation_x(float theta);
mat4x4 matrix_make_rotation_y(float theta);
mat4x4 matrix_make_rotation_z(float theta);
mat4x4 matrix_make_translation(fx32 x, fx32 y, fx32 z);
mat4x4 matrix_multiply_matrix(mat4x4* m1, mat4x4* m2);
mat4x4 matrix_point_at(vec3d* pos, vec3d* target, vec3d* up);
mat4x4 matrix_quick_inverse(mat4x4* m);

void draw_line(vec3d v0, vec3d v1, vec2d uv0, vec2d uv1, vec3d c0, vec3d c1, fx32 thickness, bool texture, bool clamp_s,
               bool clamp_t);

void draw_model(int viewport_width, int viewport_height, vec3d* vec_camera, model_t* model, mat4x4* mat_world,
                mat4x4* mat_projection, mat4x4* mat_view, bool is_lighting_ena, bool is_wireframe, bool texture,
                bool clamp_s, bool clamp_t);

#endif  // DRAW_H