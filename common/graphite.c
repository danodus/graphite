// graphite.c
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: One Lone Coder's 3D Graphics Engine tutorial available on YouTube
//       and https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation

#include "graphite.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SORT_TRIANGLES 0

#define MAX_NB_TRIANGLES    16      // maximum number of triangles produced by the clipping

void xd_draw_triangle(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 r0, fx32 g0, fx32 b0, fx32 a0, fx32 x1, fx32 y1,
                      fx32 z1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1, fx32 x2, fx32 y2, fx32 z2, fx32 u2,
                      fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2, texture_t* tex, bool clamp_s, bool clamp_t,
                      bool depth_test);

vec3d matrix_multiply_vector(mat4x4* m, vec3d* i) {
    vec3d r = {MUL(i->x, m->m[0][0]) + MUL(i->y, m->m[1][0]) + MUL(i->z, m->m[2][0]) + m->m[3][0],
               MUL(i->x, m->m[0][1]) + MUL(i->y, m->m[1][1]) + MUL(i->z, m->m[2][1]) + m->m[3][1],
               MUL(i->x, m->m[0][2]) + MUL(i->y, m->m[1][2]) + MUL(i->z, m->m[2][2]) + m->m[3][2],
               MUL(i->x, m->m[0][3]) + MUL(i->y, m->m[1][3]) + MUL(i->z, m->m[2][3]) + m->m[3][3]};

    return r;
}

vec3d vector_add(vec3d* v1, vec3d* v2) {
    vec3d r = {v1->x + v2->x, v1->y + v2->y, v1->z + v2->z, FX(1.0f)};
    return r;
}

vec3d vector_sub(vec3d* v1, vec3d* v2) {
    vec3d r = {v1->x - v2->x, v1->y - v2->y, v1->z - v2->z, FX(1.0f)};
    return r;
}

vec3d vector_mul(vec3d* v1, fx32 k) {
    vec3d r = {MUL(v1->x, k), MUL(v1->y, k), MUL(v1->z, k), FX(1.0f)};
    return r;
}

vec3d vector_div(vec3d* v1, fx32 k) {
    vec3d r = {DIV(v1->x, k), DIV(v1->y, k), DIV(v1->z, k), FX(1.0f)};
    return r;
}

fx32 vector_dot_product(vec3d* v1, vec3d* v2) { return MUL(v1->x, v2->x) + MUL(v1->y, v2->y) + MUL(v1->z, v2->z); }

fx32 vector_length(vec3d* v) { return SQRT(vector_dot_product(v, v)); }

vec3d vector_normalize(vec3d* v) {
    fx32 l = vector_length(v);
    if (l > FX(0.0f)) {
        vec3d r = {DIV(v->x, l), DIV(v->y, l), DIV(v->z, l), FX(1.0f)};
        return r;
    } else {
        vec3d r = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
        return r;
    }
}

vec3d vector_cross_product(vec3d* v1, vec3d* v2) {
    vec3d r = {MUL(v1->y, v2->z) - MUL(v1->z, v2->y), MUL(v1->z, v2->x) - MUL(v1->x, v2->z),
               MUL(v1->x, v2->y) - MUL(v1->y, v2->x), FX(1.0f)};
    return r;
}

vec3d vector_intersect_plane(vec3d* plane_p, vec3d* plane_n, vec3d* line_start, vec3d* line_end, fx32* t) {
    *plane_n = vector_normalize(plane_n);
    fx32 plane_d = -vector_dot_product(plane_n, plane_p);
    fx32 ad = vector_dot_product(line_start, plane_n);
    fx32 bd = vector_dot_product(line_end, plane_n);
    *t = DIV(-plane_d - ad, bd - ad);
    vec3d line_start_to_end = vector_sub(line_end, line_start);
    vec3d line_to_intersect = vector_mul(&line_start_to_end, *t);
    return vector_add(line_start, &line_to_intersect);
}

// return signed shortest distance from point to plane, plane normal must be normalized
fx32 dist_point_to_plane(vec3d* plane_p, vec3d* plane_n, vec3d* p) {
    return (MUL(plane_n->x, p->x) + MUL(plane_n->y, p->y) + MUL(plane_n->z, p->z) -
            vector_dot_product(plane_n, plane_p));
}

int triangle_clip_against_plane(vec3d plane_p, vec3d plane_n, triangle_t* in_tri, triangle_t* out_tri1,
                                triangle_t* out_tri2) {
    // make sure plane normal is indeed normal
    plane_n = vector_normalize(&plane_n);

    // create two temporary storage arrays to classify points either side of the plane
    // if distance sign is positive, point lies on the inside of plane
    vec3d* inside_points[3];
    int nb_inside_points = 0;
    vec3d* outside_points[3];
    int nb_outside_points = 0;
    vec2d* inside_texcoords[3];
    int nb_inside_texcoords = 0;
    vec2d* outside_texcoords[3];
    int nb_outside_texcoords = 0;
    vec3d* inside_colors[3];
    int nb_inside_colors = 0;
    vec3d* outside_colors[3];
    int nb_outside_colors = 0;

    // get signed distance of each point in triangle to plane
    fx32 d0 = dist_point_to_plane(&plane_p, &plane_n, &in_tri->p[0]);
    fx32 d1 = dist_point_to_plane(&plane_p, &plane_n, &in_tri->p[1]);
    fx32 d2 = dist_point_to_plane(&plane_p, &plane_n, &in_tri->p[2]);

    if (d0 >= FX(0.0f)) {
        inside_points[nb_inside_points++] = &in_tri->p[0];
        inside_texcoords[nb_inside_texcoords++] = &in_tri->t[0];
        inside_colors[nb_inside_colors++] = &in_tri->c[0];
    } else {
        outside_points[nb_outside_points++] = &in_tri->p[0];
        outside_texcoords[nb_outside_texcoords++] = &in_tri->t[0];
        outside_colors[nb_outside_colors++] = &in_tri->c[0];
    }
    if (d1 >= FX(0.0f)) {
        inside_points[nb_inside_points++] = &in_tri->p[1];
        inside_texcoords[nb_inside_texcoords++] = &in_tri->t[1];
        inside_colors[nb_inside_colors++] = &in_tri->c[1];
    } else {
        outside_points[nb_outside_points++] = &in_tri->p[1];
        outside_texcoords[nb_outside_texcoords++] = &in_tri->t[1];
        outside_colors[nb_outside_colors++] = &in_tri->c[1];
    }
    if (d2 >= FX(0.0f)) {
        inside_points[nb_inside_points++] = &in_tri->p[2];
        inside_texcoords[nb_inside_texcoords++] = &in_tri->t[2];
        inside_colors[nb_inside_colors++] = &in_tri->c[2];
    } else {
        outside_points[nb_outside_points++] = &in_tri->p[2];
        outside_texcoords[nb_outside_texcoords] = &in_tri->t[2];
        outside_colors[nb_outside_colors++] = &in_tri->c[2];
    }

    // classify triangle points and break the input triangle into smaller output triangles if required

    if (nb_inside_points == 0) {
        // all points lie on the outside of the plane, so clip whole triangle
        return 0;  // no returned triangles are valid
    }

    if (nb_inside_points == 3) {
        // all points lie in the inside of plane, so do nothing and allow the triangle to simply pass through
        *out_tri1 = *in_tri;

        return 1;  // just the one returned original triangle is valid
    }

    if (nb_inside_points == 1 && nb_outside_points == 2) {
        // Triangle should be clipped. As two points lie outside the plane, the triangle simply becomes a smaller
        // triangle.

        // the inside point is valid, so keep that
        out_tri1->p[0] = *inside_points[0];
        out_tri1->t[0] = *inside_texcoords[0];
        out_tri1->c[0] = *inside_colors[0];

        // but the two new points are at the location where the original sides of the triangle (lines) intersect with
        // the plane
        fx32 t;
        out_tri1->p[1] = vector_intersect_plane(&plane_p, &plane_n, inside_points[0], outside_points[0], &t);
        out_tri1->t[1].u = MUL(t, outside_texcoords[0]->u - inside_texcoords[0]->u) + inside_texcoords[0]->u;
        out_tri1->t[1].v = MUL(t, outside_texcoords[0]->v - inside_texcoords[0]->v) + inside_texcoords[0]->v;
        out_tri1->t[1].w = MUL(t, outside_texcoords[0]->w - inside_texcoords[0]->w) + inside_texcoords[0]->w;
        out_tri1->c[1].x = MUL(t, outside_colors[0]->x - inside_colors[0]->x) + inside_colors[0]->x;
        out_tri1->c[1].y = MUL(t, outside_colors[0]->y - inside_colors[0]->y) + inside_colors[0]->y;
        out_tri1->c[1].z = MUL(t, outside_colors[0]->z - inside_colors[0]->z) + inside_colors[0]->z;
        out_tri1->c[1].w = MUL(t, outside_colors[0]->w - inside_colors[0]->w) + inside_colors[0]->w;

        out_tri1->p[2] = vector_intersect_plane(&plane_p, &plane_n, inside_points[0], outside_points[1], &t);
        out_tri1->t[2].u = MUL(t, outside_texcoords[1]->u - inside_texcoords[0]->u) + inside_texcoords[0]->u;
        out_tri1->t[2].v = MUL(t, outside_texcoords[1]->v - inside_texcoords[0]->v) + inside_texcoords[0]->v;
        out_tri1->t[2].w = MUL(t, outside_texcoords[1]->w - inside_texcoords[0]->w) + inside_texcoords[0]->w;
        out_tri1->c[2].x = MUL(t, outside_colors[1]->x - inside_colors[0]->x) + inside_colors[0]->x;
        out_tri1->c[2].y = MUL(t, outside_colors[1]->y - inside_colors[0]->y) + inside_colors[0]->y;
        out_tri1->c[2].z = MUL(t, outside_colors[1]->z - inside_colors[0]->z) + inside_colors[0]->z;
        out_tri1->c[2].w = MUL(t, outside_colors[1]->w - inside_colors[0]->w) + inside_colors[0]->w;

        return 1;  // return the newly formed single triangle
    }

    if (nb_inside_points == 2 && nb_outside_points == 1) {
        // Triangle should be clipped. As two points lie inside the plane, the clipped triangle becomes a "quad".
        // Fortunately, we can represent a quad with two new triangles.

        fx32 t;

        // The first triangle consists of the two inside points and a new point determined by the location where one
        // side of the triangle intersects with the plane
        out_tri1->p[0] = *inside_points[0];
        out_tri1->t[0] = *inside_texcoords[0];
        out_tri1->c[0] = *inside_colors[0];
        out_tri1->p[1] = *inside_points[1];
        out_tri1->t[1] = *inside_texcoords[1];
        out_tri1->c[1] = *inside_colors[1];
        out_tri1->p[2] = vector_intersect_plane(&plane_p, &plane_n, inside_points[0], outside_points[0], &t);
        out_tri1->t[2].u = MUL(t, outside_texcoords[0]->u - inside_texcoords[0]->u) + inside_texcoords[0]->u;
        out_tri1->t[2].v = MUL(t, outside_texcoords[0]->v - inside_texcoords[0]->v) + inside_texcoords[0]->v;
        out_tri1->t[2].w = MUL(t, outside_texcoords[0]->w - inside_texcoords[0]->w) + inside_texcoords[0]->w;
        out_tri1->c[2].x = MUL(t, outside_colors[0]->x - inside_colors[0]->x) + inside_colors[0]->x;
        out_tri1->c[2].y = MUL(t, outside_colors[0]->y - inside_colors[0]->y) + inside_colors[0]->y;
        out_tri1->c[2].z = MUL(t, outside_colors[0]->z - inside_colors[0]->z) + inside_colors[0]->z;
        out_tri1->c[2].w = MUL(t, outside_colors[0]->w - inside_colors[0]->w) + inside_colors[0]->w;

        // The second triangle is composed of one the the inside points, a new point determined by the intersection
        // of the other side of the triangle and the plane, and the newly created point above
        out_tri2->p[0] = *inside_points[1];
        out_tri2->t[0] = *inside_texcoords[1];
        out_tri2->c[0] = *inside_colors[1];
        out_tri2->p[1] = vector_intersect_plane(&plane_p, &plane_n, inside_points[1], outside_points[0], &t);
        out_tri2->t[1].u = MUL(t, outside_texcoords[0]->u - inside_texcoords[1]->u) + inside_texcoords[1]->u;
        out_tri2->t[1].v = MUL(t, outside_texcoords[0]->v - inside_texcoords[1]->v) + inside_texcoords[1]->v;
        out_tri2->t[1].w = MUL(t, outside_texcoords[0]->w - inside_texcoords[1]->w) + inside_texcoords[1]->w;
        out_tri2->c[1].x = MUL(t, outside_colors[0]->x - inside_colors[1]->x) + inside_colors[1]->x;
        out_tri2->c[1].y = MUL(t, outside_colors[0]->y - inside_colors[1]->y) + inside_colors[1]->y;
        out_tri2->c[1].z = MUL(t, outside_colors[0]->z - inside_colors[1]->z) + inside_colors[1]->z;
        out_tri2->c[1].w = MUL(t, outside_colors[0]->w - inside_colors[1]->w) + inside_colors[1]->w;
        out_tri2->p[2] = out_tri1->p[2];
        out_tri2->t[2] = out_tri1->t[2];
        out_tri2->c[2] = out_tri1->c[2];

        return 2;  // return two newly formed triangles which form a quad
    }

    return 0;  // should not happen
}

mat4x4 matrix_make_identity() {
    mat4x4 mat;
    memset(&mat, 0, sizeof(mat4x4));
    mat.m[0][0] = FX(1.0f);
    mat.m[1][1] = FX(1.0f);
    mat.m[2][2] = FX(1.0f);
    mat.m[3][3] = FX(1.0f);
    return mat;
}

mat4x4 matrix_make_projection(int viewport_width, int viewport_height, float fov) {
    mat4x4 mat_proj;

    // projection matrix
    fx32 near = FX(0.1f);
    fx32 far = FX(1000.0f);
    fx32 aspect_ratio = FX((float)viewport_height / (float)viewport_width);
    fx32 fov_rad = FX(1.0f / tanf(fov * 0.5f / 180.0f * 3.14159f));

    memset(&mat_proj, 0, sizeof(mat4x4));
    mat_proj.m[0][0] = MUL(aspect_ratio, fov_rad);
    mat_proj.m[1][1] = fov_rad;
    mat_proj.m[2][2] = DIV(far, (far - near));
    mat_proj.m[3][2] = DIV(MUL(-far, near), (far - near));
    mat_proj.m[2][3] = FX(1.0f);
    mat_proj.m[3][3] = FX(0.0f);

    return mat_proj;
}

mat4x4 matrix_make_rotation_x(float theta) {
    mat4x4 mat_rot_x;
    memset(&mat_rot_x, 0, sizeof(mat4x4));

    // rotation X
    mat_rot_x.m[0][0] = FX(1.0f);
    mat_rot_x.m[1][1] = FX(cosf(theta));
    mat_rot_x.m[1][2] = FX(sinf(theta));
    mat_rot_x.m[2][1] = FX(-sinf(theta));
    mat_rot_x.m[2][2] = FX(cosf(theta));
    mat_rot_x.m[3][3] = FX(1.0f);

    return mat_rot_x;
}

mat4x4 matrix_make_rotation_y(float theta) {
    mat4x4 mat_rot_y;
    memset(&mat_rot_y, 0, sizeof(mat4x4));

    // rotation Y
    mat_rot_y.m[0][0] = FX(cos(theta));
    mat_rot_y.m[0][2] = FX(-sinf(theta));
    mat_rot_y.m[1][1] = FX(1.0f);
    mat_rot_y.m[2][0] = FX(sinf(theta));
    mat_rot_y.m[2][2] = FX(cosf(theta));

    return mat_rot_y;
}

mat4x4 matrix_make_rotation_z(float theta) {
    mat4x4 mat_rot_z;
    memset(&mat_rot_z, 0, sizeof(mat4x4));

    // rotation Z
    mat_rot_z.m[0][0] = FX(cosf(theta));
    mat_rot_z.m[0][1] = FX(sinf(theta));
    mat_rot_z.m[1][0] = FX(-sinf(theta));
    mat_rot_z.m[1][1] = FX(cosf(theta));
    mat_rot_z.m[2][2] = FX(1.0f);
    mat_rot_z.m[3][3] = FX(1.0f);

    return mat_rot_z;
}

mat4x4 matrix_make_translation(fx32 x, fx32 y, fx32 z) {
    mat4x4 mat;
    memset(&mat, 0, sizeof(mat4x4));

    mat.m[0][0] = FX(1.0f);
    mat.m[1][1] = FX(1.0f);
    mat.m[2][2] = FX(1.0f);
    mat.m[3][3] = FX(1.0f);
    mat.m[3][0] = x;
    mat.m[3][1] = y;
    mat.m[3][2] = z;

    return mat;
}

mat4x4 matrix_make_scale(fx32 x, fx32 y, fx32 z) {
    mat4x4 mat;
    memset(&mat, 0, sizeof(mat4x4));

    mat.m[0][0] = x;
    mat.m[1][1] = y;
    mat.m[2][2] = z;
    mat.m[3][3] = FX(1.0f);

    return mat;
}

mat4x4 matrix_multiply_matrix(mat4x4* m1, mat4x4* m2) {
    mat4x4 mat;
    for (int c = 0; c < 4; ++c)
        for (int r = 0; r < 4; ++r)
            mat.m[c][r] = MUL(m1->m[c][0], m2->m[0][r]) + MUL(m1->m[c][1], m2->m[1][r]) +
                          MUL(m1->m[c][2], m2->m[2][r]) + MUL(m1->m[c][3], m2->m[3][r]);
    return mat;
}

mat4x4 matrix_point_at(vec3d* pos, vec3d* target, vec3d* up) {
    // calculate new forward direction
    vec3d new_forward = vector_sub(target, pos);
    new_forward = vector_normalize(&new_forward);

    // calculate new up direction
    fx32 dp = vector_dot_product(up, &new_forward);
    vec3d a = vector_mul(&new_forward, dp);
    vec3d new_up = vector_sub(up, &a);
    new_up = vector_normalize(&new_up);

    // new right direction is easy, just cross product
    vec3d new_right = vector_cross_product(&new_up, &new_forward);

    // construct dimensioning and translation matrix
    mat4x4 mat;
    mat.m[0][0] = new_right.x;
    mat.m[0][1] = new_right.y;
    mat.m[0][2] = new_right.z;
    mat.m[0][3] = FX(0.0f);
    mat.m[1][0] = new_up.x;
    mat.m[1][1] = new_up.y;
    mat.m[1][2] = new_up.z;
    mat.m[1][3] = FX(0.0f);
    mat.m[2][0] = new_forward.x;
    mat.m[2][1] = new_forward.y;
    mat.m[2][2] = new_forward.z;
    mat.m[2][3] = FX(0.0f);
    mat.m[3][0] = pos->x;
    mat.m[3][1] = pos->y;
    mat.m[3][2] = pos->z;
    mat.m[3][3] = FX(1.0f);
    return mat;
}

mat4x4 matrix_quick_inverse(mat4x4* m) {
    mat4x4 mat;
    mat.m[0][0] = m->m[0][0];
    mat.m[0][1] = m->m[1][0];
    mat.m[0][2] = m->m[2][0];
    mat.m[0][3] = FX(0.0f);
    mat.m[1][0] = m->m[0][1];
    mat.m[1][1] = m->m[1][1];
    mat.m[1][2] = m->m[2][1];
    mat.m[1][3] = FX(0.0f);
    mat.m[2][0] = m->m[0][2];
    mat.m[2][1] = m->m[1][2];
    mat.m[2][2] = m->m[2][2];
    mat.m[2][3] = FX(0.0f);
    mat.m[3][0] = -(MUL(m->m[3][0], mat.m[0][0]) + MUL(m->m[3][1], mat.m[1][0]) + MUL(m->m[3][2], mat.m[2][0]));
    mat.m[3][1] = -(MUL(m->m[3][0], mat.m[0][1]) + MUL(m->m[3][1], mat.m[1][1]) + MUL(m->m[3][2], mat.m[2][1]));
    mat.m[3][2] = -(MUL(m->m[3][0], mat.m[0][2]) + MUL(m->m[3][1], mat.m[1][2]) + MUL(m->m[3][2], mat.m[2][2]));
    mat.m[3][3] = FX(1.0f);
    return mat;
}

#if SORT_TRIANGLES

void swap_triangle(triangle_t* a, triangle_t* b) {
    triangle_t c = *a;
    *a = *b;
    *b = c;
}

fx32 triangle_depth(triangle_t* tri) { return DIV(tri->p[0].z + tri->p[1].z + tri->p[2].z, FX(3.0f)); }

size_t sort_triangles_partition(triangle_t triangles[], size_t nb_triangles, size_t l, size_t h) {
    size_t i, j;
    fx32 pivot;
    pivot = triangle_depth(&triangles[l]);
    i = l;
    j = h;

    while (i < j) {
        do {
            i++;
        } while (i < nb_triangles && triangle_depth(&triangles[i]) <= pivot);
        do {
            j--;
        } while (triangle_depth(&triangles[j]) > pivot);
        if (i < j) {
            swap_triangle(&triangles[i], &triangles[j]);
        }
    }
    swap_triangle(&triangles[l], &triangles[j]);
    return j;
}

void sort_triangles_lh(triangle_t triangles[], size_t nb_triangles, size_t l, size_t h) {
    size_t j;

    if (l < h) {
        j = sort_triangles_partition(triangles, nb_triangles, l, h);
        sort_triangles_lh(triangles, nb_triangles, l, j);
        sort_triangles_lh(triangles, nb_triangles, j + 1, h);
    }
}

void sort_triangles(triangle_t triangles[], size_t nb_triangles) {
    sort_triangles_lh(triangles, nb_triangles, 0, nb_triangles);
}
#endif // SORT_TRIANGLES

static fx32 clamp(fx32 x) {
    if (x < FX(0.0f)) return FX(0.0f);
    if (x > FX(1.0f)) return FX(1.0f);
    return x;
}

void draw_line(vec3d v0, vec3d v1, vec2d uv0, vec2d uv1, vec3d c0, vec3d c1, fx32 thickness, texture_t* texture,
                bool clamp_s, bool clamp_t) {
    // skip if zero thickness or length
    if (thickness == FX(0.0f) || (v0.x == v1.x && v0.y == v1.y)) return;

    thickness = DIV(thickness, FX(2.0f));

    // define the line between the two points
    vec3d line = vector_sub(&v1, &v0);

    // find the normal vector of this line
    vec3d normal = (vec3d){-line.y, line.x, FX(0.0f), FX(0.0f)};
    normal = vector_normalize(&normal);

    vec3d miter = vector_mul(&normal, thickness);

    vec3d vv0 = vector_add(&v0, &miter);
    vec3d vv1 = vector_sub(&v0, &miter);
    vec3d vv2 = vector_add(&v1, &miter);
    vec3d vv3 = vector_sub(&v1, &miter);

    xd_draw_triangle(vv0.x, vv0.y, vv0.z, uv0.u, uv0.v, c0.x, c0.y, c0.z, c0.w, vv2.x, vv2.y, vv2.z, uv1.u,
                     uv1.v, c1.x, c1.y, c1.z, c1.w, vv3.x, vv3.y, vv3.z, uv1.u, uv1.v, c1.x, c1.y, c1.z, c1.w,
                     texture, clamp_s, clamp_t, false);
    xd_draw_triangle(vv1.x, vv1.y, vv1.z, uv0.u, uv0.v, c0.x, c0.y, c0.z, c0.w, vv0.x, vv0.y, vv0.z, uv0.u,
                     uv0.v, c0.x, c0.y, c0.z, c0.w, vv3.x, vv3.y, vv3.z, uv1.u, uv1.v, c1.x, c1.y, c1.z, c1.w,
                     texture, clamp_s, clamp_t, false);
}

void draw_model(int viewport_width, int viewport_height, vec3d* vec_camera, model_t* model, mat4x4* mat_world,
                mat4x4* mat_proj, mat4x4* mat_view, bool is_lighting_ena, bool is_wireframe, texture_t* texture,
                bool clamp_s, bool clamp_t) {
    size_t triangle_to_raster_index = 0;

    // draw faces
    for (size_t i = 0; i < model->mesh.nb_faces; ++i) {
        face_t* face = &model->mesh.faces[i];
        triangle_t tri;
        tri.p[0] = model->mesh.vertices[face->indices[0]];
        tri.p[1] = model->mesh.vertices[face->indices[1]];
        tri.p[2] = model->mesh.vertices[face->indices[2]];
        if (model->mesh.texcoords) {
            tri.t[0] = model->mesh.texcoords[face->tex_indices[0]];
            tri.t[1] = model->mesh.texcoords[face->tex_indices[1]];
            tri.t[2] = model->mesh.texcoords[face->tex_indices[2]];
        } else {
            tri.t[0] = (vec2d){FX(0.0f), FX(0.0f)};
            tri.t[1] = (vec2d){FX(0.0f), FX(0.0f)};
            tri.t[2] = (vec2d){FX(0.0f), FX(0.0f)};
        }
        if (model->mesh.colors) {
            tri.c[0] = model->mesh.colors[face->col_indices[0]];
            tri.c[1] = model->mesh.colors[face->col_indices[1]];
            tri.c[2] = model->mesh.colors[face->col_indices[2]];
        } else {
            tri.c[0] = (vec3d){FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)};
            tri.c[1] = (vec3d){FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)};
            tri.c[2] = (vec3d){FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)};
        }

        triangle_t tri_viewed, tri_projected, tri_transformed;

        tri_transformed.p[0] = matrix_multiply_vector(mat_world, &tri.p[0]);
        tri_transformed.p[1] = matrix_multiply_vector(mat_world, &tri.p[1]);
        tri_transformed.p[2] = matrix_multiply_vector(mat_world, &tri.p[2]);
        tri_transformed.t[0] = tri.t[0];
        tri_transformed.t[1] = tri.t[1];
        tri_transformed.t[2] = tri.t[2];
        tri_transformed.c[0] = tri.c[0];
        tri_transformed.c[1] = tri.c[1];
        tri_transformed.c[2] = tri.c[2];

        // calculate the normal
        vec3d normal, line1, line2;
        line1.x = tri_transformed.p[1].x - tri_transformed.p[0].x;
        line1.y = tri_transformed.p[1].y - tri_transformed.p[0].y;
        line1.z = tri_transformed.p[1].z - tri_transformed.p[0].z;

        line2.x = tri_transformed.p[2].x - tri_transformed.p[0].x;
        line2.y = tri_transformed.p[2].y - tri_transformed.p[0].y;
        line2.z = tri_transformed.p[2].z - tri_transformed.p[0].z;

        // take the cross product of lines to get normal to triangle surface
        normal = vector_cross_product(&line1, &line2);

        // get ray from triangle to camera
        vec3d vec_camera_ray = vector_sub(&tri_transformed.p[0], vec_camera);

        // if ray is aligned with normal, then triangle is visible
        if (vector_dot_product(&normal, &vec_camera_ray) < FX(0.0f)) {
            fx32 dp = FX(1.0f);
            if (is_lighting_ena) {
                // illumination
                vec3d light_direction = {FX(0.0f), FX(0.0f), FX(-1.0f), FX(1.0f)};
                light_direction = vector_normalize(&light_direction);

                // how "aligned" are light direction and triangle surface normal?
                vec3d n = vector_mul(&normal, FXI(16)); // to fix precision issue with small triangles in fixed point
                n = vector_normalize(&n);
                dp = vector_dot_product(&light_direction, &n);

                if (dp < FX(0.0f)) dp = FX(0.0f);

                // note: alpha is currently forced to 1 here
                tri_transformed.c[0] = vector_mul(&tri_transformed.c[0], dp);
                tri_transformed.c[1] = vector_mul(&tri_transformed.c[1], dp);
                tri_transformed.c[2] = vector_mul(&tri_transformed.c[2], dp);
            }

            // convert world space to view space
            tri_viewed.p[0] = matrix_multiply_vector(mat_view, &tri_transformed.p[0]);
            tri_viewed.p[1] = matrix_multiply_vector(mat_view, &tri_transformed.p[1]);
            tri_viewed.p[2] = matrix_multiply_vector(mat_view, &tri_transformed.p[2]);
            tri_viewed.t[0] = tri_transformed.t[0];
            tri_viewed.t[1] = tri_transformed.t[1];
            tri_viewed.t[2] = tri_transformed.t[2];
            tri_viewed.c[0] = tri_transformed.c[0];
            tri_viewed.c[1] = tri_transformed.c[1];
            tri_viewed.c[2] = tri_transformed.c[2];

            // clip viewed triangle against near plane, this could form two additional triangles
            int nb_clipped_triangles = 0;
            triangle_t clipped[2];
            const fx32 z_near = FX(0.1f);
            vec3d plane_p = {FX(0.0f), FX(0.0f), z_near, FX(1.0f)};
            vec3d plane_n = {FX(0.0f), FX(0.0f), FX(1.0f), FX(1.0f)};
            nb_clipped_triangles = triangle_clip_against_plane(plane_p, plane_n, &tri_viewed, &clipped[0], &clipped[1]);

            for (int n = 0; n < nb_clipped_triangles; ++n) {
                // project triangles from 3D to 2D
                tri_projected.p[0] = matrix_multiply_vector(mat_proj, &clipped[n].p[0]);
                tri_projected.p[1] = matrix_multiply_vector(mat_proj, &clipped[n].p[1]);
                tri_projected.p[2] = matrix_multiply_vector(mat_proj, &clipped[n].p[2]);
                tri_projected.t[0] = clipped[n].t[0];
                tri_projected.t[1] = clipped[n].t[1];
                tri_projected.t[2] = clipped[n].t[2];
                tri_projected.c[0] = clipped[n].c[0];
                tri_projected.c[1] = clipped[n].c[1];
                tri_projected.c[2] = clipped[n].c[2];

                tri_projected.t[0].u = DIV(tri_projected.t[0].u, tri_projected.p[0].w);
                tri_projected.t[1].u = DIV(tri_projected.t[1].u, tri_projected.p[1].w);
                tri_projected.t[2].u = DIV(tri_projected.t[2].u, tri_projected.p[2].w);

                tri_projected.t[0].v = DIV(tri_projected.t[0].v, tri_projected.p[0].w);
                tri_projected.t[1].v = DIV(tri_projected.t[1].v, tri_projected.p[1].w);
                tri_projected.t[2].v = DIV(tri_projected.t[2].v, tri_projected.p[2].w);

                tri_projected.t[0].w = DIV(FX(1.0f), tri_projected.p[0].w);
                tri_projected.t[1].w = DIV(FX(1.0f), tri_projected.p[1].w);
                tri_projected.t[2].w = DIV(FX(1.0f), tri_projected.p[2].w);

                tri_projected.c[0].x = DIV(tri_projected.c[0].x, tri_projected.p[0].w);
                tri_projected.c[1].x = DIV(tri_projected.c[1].x, tri_projected.p[1].w);
                tri_projected.c[2].x = DIV(tri_projected.c[2].x, tri_projected.p[2].w);

                tri_projected.c[0].y = DIV(tri_projected.c[0].y, tri_projected.p[0].w);
                tri_projected.c[1].y = DIV(tri_projected.c[1].y, tri_projected.p[1].w);
                tri_projected.c[2].y = DIV(tri_projected.c[2].y, tri_projected.p[2].w);

                tri_projected.c[0].z = DIV(tri_projected.c[0].z, tri_projected.p[0].w);
                tri_projected.c[1].z = DIV(tri_projected.c[1].z, tri_projected.p[1].w);
                tri_projected.c[2].z = DIV(tri_projected.c[2].z, tri_projected.p[2].w);

                tri_projected.c[0].w = DIV(tri_projected.c[0].w, tri_projected.p[0].w);
                tri_projected.c[1].w = DIV(tri_projected.c[1].w, tri_projected.p[1].w);
                tri_projected.c[2].w = DIV(tri_projected.c[2].w, tri_projected.p[2].w);

                // scale into view
                tri_projected.p[0] = vector_div(&tri_projected.p[0], tri_projected.p[0].w);
                tri_projected.p[1] = vector_div(&tri_projected.p[1], tri_projected.p[1].w);
                tri_projected.p[2] = vector_div(&tri_projected.p[2], tri_projected.p[2].w);

                // offset vertices into visible normalized space
                vec3d vec_offset_view = {FX(1.0f), FX(1.0f), FX(0.0f), FX(1.0f)};
                tri_projected.p[0] = vector_add(&tri_projected.p[0], &vec_offset_view);
                tri_projected.p[1] = vector_add(&tri_projected.p[1], &vec_offset_view);
                tri_projected.p[2] = vector_add(&tri_projected.p[2], &vec_offset_view);

                fx32 w = FX(0.5f * (float)viewport_width);
                fx32 h = FX(0.5f * (float)viewport_height);
                tri_projected.p[0].x = MUL(tri_projected.p[0].x, w);
                tri_projected.p[0].y = MUL(tri_projected.p[0].y, h);
                tri_projected.p[1].x = MUL(tri_projected.p[1].x, w);
                tri_projected.p[1].y = MUL(tri_projected.p[1].y, h);
                tri_projected.p[2].x = MUL(tri_projected.p[2].x, w);
                tri_projected.p[2].y = MUL(tri_projected.p[2].y, h);

                // store triangle for sorting
                model->triangles_to_raster[triangle_to_raster_index] = tri_projected;
                triangle_to_raster_index++;
            }
        }
    }

#if SORT_TRIANGLES
    // sort triangles from front to back
    sort_triangles(model->triangles_to_raster, triangle_to_raster_index);
#endif

    for (size_t i = 0; i < triangle_to_raster_index; ++i) {
        triangle_t tri_to_raster = model->triangles_to_raster[triangle_to_raster_index - i - 1];

        // clip triangles against all four screen edges, this could yield a bunch of triangles
        triangle_t clipped[2];
        triangle_t triangles[MAX_NB_TRIANGLES];
        int nb_triangles = 0;
        triangles[nb_triangles++] = tri_to_raster;

        int nb_new_triangles = 1;

        for (int p = 0; p < 4; ++p) {
            int nb_tris_to_add = 0;
            while (nb_new_triangles > 0) {
                // pop front
                triangle_t test = triangles[0];
                for (int j = 1; j < nb_triangles; ++j) triangles[j - 1] = triangles[j];
                nb_triangles--;

                nb_new_triangles--;

                switch (p) {
                    case 0: {
                        vec3d p = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
                        vec3d n = {FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)};
                        nb_tris_to_add = triangle_clip_against_plane(p, n, &test, &clipped[0], &clipped[1]);
                        break;
                    }
                    case 1: {
                        vec3d p = {FX(0.0f), FX((float)(viewport_height - 1)), FX(0.0f), FX(1.0f)};
                        vec3d n = {FX(0.0f), FX(-1.0f), FX(0.0f), FX(1.0f)};
                        nb_tris_to_add = triangle_clip_against_plane(p, n, &test, &clipped[0], &clipped[1]);
                        break;
                    }
                    case 2: {
                        vec3d p = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
                        vec3d n = {FX(1.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
                        nb_tris_to_add = triangle_clip_against_plane(p, n, &test, &clipped[0], &clipped[1]);
                        break;
                    }
                    case 3: {
                        vec3d p = {FX((float)(viewport_width - 1)), FX(0.0f), FX(0.0f), FX(1.0f)};
                        vec3d n = {FX(-1.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
                        nb_tris_to_add = triangle_clip_against_plane(p, n, &test, &clipped[0], &clipped[1]);
                        break;
                    }
                }

                // push back
                if (nb_triangles + nb_tris_to_add > MAX_NB_TRIANGLES) break;    // safety net
                for (int w = 0; w < nb_tris_to_add; ++w) triangles[nb_triangles++] = clipped[w];
            }
            nb_new_triangles = nb_triangles;
        }

        for (int i = 0; i < nb_triangles; ++i) {
            triangle_t* t = &triangles[i];

            // calculate the normal
            vec3d normal, line1, line2;
            line1.x = t->p[1].x - t->p[0].x;
            line1.y = t->p[1].y - t->p[0].y;
            line1.z = t->p[1].z - t->p[0].z;

            line2.x = t->p[2].x - t->p[0].x;
            line2.y = t->p[2].y - t->p[0].y;
            line2.z = t->p[2].z - t->p[0].z;

            // take the cross product of lines to get normal to triangle surface
            normal = vector_cross_product(&line1, &line2);

            if (normal.z > FX(0.0f)) {
                vec3d tp = t->p[0];
                vec2d tt = t->t[0];
                vec3d tc = t->c[0];
                t->p[0] = t->p[1];
                t->t[0] = t->t[1];
                t->c[0] = t->c[1];
                t->p[1] = tp;
                t->t[1] = tt;
                t->c[1] = tc;
            }

            // rasterize triangle
            if (is_wireframe) {
                draw_line((vec3d){t->p[0].x, t->p[0].y, t->t[0].w, FX(0.0f)},
                          (vec3d){t->p[1].x, t->p[1].y, t->t[1].w, FX(0.0f)},
                          (vec2d){t->t[0].u, t->t[0].v, FX(0.0f)},
                          (vec2d){t->t[1].u, t->t[1].v, FX(0.0f)},
                          (vec3d){t->c[0].x, t->c[0].y, t->c[0].z, t->c[0].w},
                          (vec3d){t->c[1].x, t->c[1].y, t->c[1].z, t->c[1].w}, FX(1.0f), texture, clamp_s, clamp_t);
                draw_line((vec3d){t->p[1].x, t->p[1].y, t->t[1].w, FX(0.0f)},
                          (vec3d){t->p[2].x, t->p[2].y, t->t[2].w, FX(0.0f)},
                          (vec2d){t->t[1].u, t->t[1].v, FX(0.0f)},
                          (vec2d){t->t[2].u, t->t[2].v, FX(0.0f)},
                          (vec3d){t->c[1].x, t->c[1].y, t->c[1].z, t->c[1].w},
                          (vec3d){t->c[2].x, t->c[2].y, t->c[2].z, t->c[2].w}, FX(1.0f), texture, clamp_s, clamp_t);
                draw_line((vec3d){t->p[2].x, t->p[2].y, t->t[2].w, FX(0.0f)},
                          (vec3d){t->p[0].x, t->p[0].y, t->t[0].w, FX(0.0f)},
                          (vec2d){t->t[2].u, t->t[2].v, FX(0.0f)},
                          (vec2d){t->t[0].u, t->t[0].v, FX(0.0f)},
                          (vec3d){t->c[2].x, t->c[2].y, t->c[2].z, t->c[2].w},
                          (vec3d){t->c[0].x, t->c[0].y, t->c[0].z, t->c[0].w}, FX(1.0f), texture, clamp_s, clamp_t);
            } else {
                xd_draw_triangle(t->p[0].x, t->p[0].y, t->t[0].w, t->t[0].u, t->t[0].v, t->c[0].x, t->c[0].y, t->c[0].z,
                                 t->c[0].w, t->p[1].x, t->p[1].y, t->t[1].w, t->t[1].u, t->t[1].v, t->c[1].x, t->c[1].y,
                                 t->c[1].z, t->c[1].w, t->p[2].x, t->p[2].y, t->t[2].w, t->t[2].u, t->t[2].v, t->c[2].x,
                                 t->c[2].y, t->c[2].z, t->c[2].w, texture, clamp_s, clamp_t, true);
            }
        }
    }
}