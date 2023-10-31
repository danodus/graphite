#include <math.h>

#include "matrix.h"

mat4_t mat4_identity(void) {
    // | 1 0 0 0 |
    // | 0 1 0 0 |
    // | 0 0 1 0 |
    // | 0 0 0 1 |
    mat4_t m = {{
        { fix16_from_float(1), 0, 0, 0 },
        { 0, fix16_from_float(1), 0, 0 },
        { 0, 0, fix16_from_float(1), 0 },
        { 0, 0, 0, fix16_from_float(1) }
    }};
    return m;
}

mat4_t mat4_make_scale(fix16_t sx, fix16_t sy, fix16_t sz) {
    // | sx 0  0  0 |
    // | 0  sy 0  0 |
    // | 0  0  sz 0 |
    // | 0  0  0  1 |
    mat4_t m = mat4_identity();
    m.m[0][0] = sx;
    m.m[1][1] = sy;
    m.m[2][2] = sz;
    return m;
}

mat4_t mat4_make_translation(fix16_t tx, fix16_t ty, fix16_t tz) {
    // | 1  0  0  tx |
    // | 0  1  0  ty |
    // | 0  0  1  tz |
    // | 0  0  0  1  |
    mat4_t m = mat4_identity();
    m.m[0][3] = tx;
    m.m[1][3] = ty;
    m.m[2][3] = tz;
    return m;
}

mat4_t mat4_make_rotation_x(fix16_t angle) {
    fix16_t c = fix16_cos(angle);
    fix16_t s = fix16_sin(angle);
    // | 1  0  0  0 |
    // | 0  c  -s 0 |
    // | 0  s  c  0 |
    // | 0  0  0  1 |
    mat4_t m = mat4_identity();
    m.m[1][1] = c;
    m.m[1][2] = -s;
    m.m[2][1] = s;
    m.m[2][2] = c;
    return m;
}

mat4_t mat4_make_rotation_y(fix16_t angle) {
    fix16_t c = fix16_cos(angle);
    fix16_t s = fix16_sin(angle);
    // | c  0  s  0 |
    // | 0  1  0  0 |
    // | -s 0  c  0 |
    // | 0  0  0  1 |
    mat4_t m = mat4_identity();
    m.m[0][0] = c;
    m.m[0][2] = s;
    m.m[2][0] = -s;
    m.m[2][2] = c;
    return m;
}

mat4_t mat4_make_rotation_z(fix16_t angle) {
    fix16_t c = fix16_cos(angle);
    fix16_t s = fix16_sin(angle);
    // | c  -s 0  0 |
    // | s  c  0  0 |
    // | 0  0  1  0 |
    // | 0  0  0  1 |
    mat4_t m = mat4_identity();
    m.m[0][0] = c;
    m.m[0][1] = -s;
    m.m[1][0] = s;
    m.m[1][1] = c;
    return m;
}

mat4_t mat4_make_perspective(fix16_t fov, fix16_t aspect, fix16_t znear, fix16_t zfar)
{
    // | (h/w)*1/tan(fov/2)            0           0                 0 |
    // |                  0  1/tan(fov/2)          0                 0 |
    // |                  0            0  zf/(zf-zn)  (-zf*zn)/(zf-zn) |
    // |                  0            0           1                 0 |
    mat4_t m = {{{ 0 }}};
    m.m[0][0] = fix16_mul(aspect, fix16_div(fix16_from_float(1.0), fix16_tan(fix16_div(fov, fix16_from_float(2)))));
    m.m[1][1] = fix16_div(fix16_from_float(1.0), fix16_tan(fix16_div(fov, fix16_from_float(2))));
    m.m[2][2] = fix16_div(zfar, zfar - znear);
    m.m[2][3] = fix16_div(fix16_mul(-zfar, znear), zfar - znear);
    m.m[3][2] = fix16_from_float(1.0);

    return m;
}

vec4_t mat4_mul_vec4(mat4_t m, vec4_t v) {
    vec4_t result;
    result.x = fix16_mul(m.m[0][0], v.x) + fix16_mul(m.m[0][1], v.y) + fix16_mul(m.m[0][2], v.z) + fix16_mul(m.m[0][3], v.w);
    result.y = fix16_mul(m.m[1][0], v.x) + fix16_mul(m.m[1][1], v.y) + fix16_mul(m.m[1][2], v.z) + fix16_mul(m.m[1][3], v.w);
    result.z = fix16_mul(m.m[2][0], v.x) + fix16_mul(m.m[2][1], v.y) + fix16_mul(m.m[2][2], v.z) + fix16_mul(m.m[2][3], v.w);
    result.w = fix16_mul(m.m[3][0], v.x) + fix16_mul(m.m[3][1], v.y) + fix16_mul(m.m[3][2], v.z) + fix16_mul(m.m[3][3], v.w);
    return result;
}

mat4_t mat4_mul_mat4(mat4_t a, mat4_t b) {
    mat4_t m;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            m.m[i][j] = fix16_mul(a.m[i][0], b.m[0][j]) + fix16_mul(a.m[i][1], b.m[1][j]) + fix16_mul(a.m[i][2], b.m[2][j]) + fix16_mul(a.m[i][3], b.m[3][j]);
        }
    }
    return m;
}

vec4_t mat4_mul_vec4_project(mat4_t mat_proj, vec4_t v) {
    // multiply the projection matrix by our original vector
    vec4_t result = mat4_mul_vec4(mat_proj, v);

    // perform perspective divide with original z-value that is now stored in w
    if (result.w != fix16_from_float(0.0)) {
        result.x = fix16_div(result.x, result.w);
        result.y = fix16_div(result.y, result.w);
        result.z = fix16_div(result.z, result.w);
    }
    return result;
}

mat4_t mat4_look_at(vec3_t eye, vec3_t target, vec3_t up) {
    // Compute the forward (z), right (x) and up (y) vectors
    vec3_t z = vec3_sub(target, eye);
    vec3_normalize(&z);
    vec3_t x = vec3_cross(up, z);
    vec3_normalize(&x);
    vec3_t y = vec3_cross(z, x);

    // | x.x  x.y  x.z  -dot(x,eye) |
    // | y.x  y.y  y.z  -dot(y,eye) |
    // | z.x  z.y  z.z  -dot(z,eye) |
    // |   0    0    0            1 |
    mat4_t view_matrix  = {{
        { x.x, x.y, x.z, -vec3_dot(x, eye) },
        { y.x, y.y, y.z, -vec3_dot(y, eye) },
        { z.x, z.y, z.z, -vec3_dot(z, eye) },
        { 0, 0, 0, fix16_from_float(1) }
    }};
    return view_matrix;
}