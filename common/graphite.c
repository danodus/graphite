#include "graphite.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void xd_draw_triangle(int x0, int y0, int x1, int y1, int x2, int y2, int color);
void xd_draw_filled_triangle(int x0, int y0, int x1, int y1, int x2, int y2, int color);
void xd_draw_textured_triangle(int x0, int y0, fx32 u0, fx32 v0, int x1, int y1, fx32 u1, fx32 v1, int x2, int y2,
                               fx32 u2, fx32 v2, texture_t* tex);

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
    *t = DIV2(-plane_d - ad, bd - ad);
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

    // get signed distance of each point in triangle to plane
    fx32 d0 = dist_point_to_plane(&plane_p, &plane_n, &in_tri->p[0]);
    fx32 d1 = dist_point_to_plane(&plane_p, &plane_n, &in_tri->p[1]);
    fx32 d2 = dist_point_to_plane(&plane_p, &plane_n, &in_tri->p[2]);

    if (d0 >= FX(0.0f)) {
        inside_points[nb_inside_points++] = &in_tri->p[0];
        inside_texcoords[nb_inside_texcoords++] = &in_tri->t[0];
    } else {
        outside_points[nb_outside_points++] = &in_tri->p[0];
        outside_texcoords[nb_outside_texcoords++] = &in_tri->t[0];
    }
    if (d1 >= FX(0.0f)) {
        inside_points[nb_inside_points++] = &in_tri->p[1];
        inside_texcoords[nb_inside_texcoords++] = &in_tri->t[1];
    } else {
        outside_points[nb_outside_points++] = &in_tri->p[1];
        outside_texcoords[nb_outside_texcoords++] = &in_tri->t[1];
    }
    if (d2 >= FX(0.0f)) {
        inside_points[nb_inside_points++] = &in_tri->p[2];
        inside_texcoords[nb_inside_texcoords++] = &in_tri->t[2];
    } else {
        outside_points[nb_outside_points++] = &in_tri->p[2];
        outside_texcoords[nb_outside_texcoords] = &in_tri->t[2];
    }

    // classify triangle points and break the input triangle into smaller output triangles if required

    if (nb_inside_points == 0) {
        // all points lie on the outside of the plane, so clip whole triangle
        return 0;  // no returned triangles are valid
    }

    // TODO: Partial clipping is currently disabled due to improper winding order with new triangles.
    if (true /*nb_inside_points == 3*/) {
        // all points lie in the inside of plane, so do nothing and allow the triangle to simply pass through
        *out_tri1 = *in_tri;

        return 1;  // just the one returned original triangle is valid
    }

    if (nb_inside_points == 1 && nb_outside_points == 2) {
        // Triangle should be clipped. As two points lie outside the plane, the triangle simply becomes a smaller
        // triangle.

        // copy appearance info to the new triangle
        out_tri1->col = in_tri->col;

        // the inside point is valid, so keep that
        out_tri1->p[0] = *inside_points[0];
        out_tri1->t[0] = *inside_texcoords[0];

        // but the two new points are at the location where the original sides of the triangle (lines) intersect with
        // the plane
        fx32 t;
        out_tri1->p[1] = vector_intersect_plane(&plane_p, &plane_n, inside_points[0], outside_points[0], &t);
        out_tri1->t[1].u = MUL(t, outside_texcoords[0]->u - inside_texcoords[0]->u) + inside_texcoords[0]->u;
        out_tri1->t[1].v = MUL(t, outside_texcoords[0]->v - inside_texcoords[0]->v) + inside_texcoords[0]->v;

        out_tri1->p[2] = vector_intersect_plane(&plane_p, &plane_n, inside_points[0], outside_points[1], &t);
        out_tri1->t[2].u = MUL(t, outside_texcoords[1]->u - inside_texcoords[0]->u) + inside_texcoords[0]->u;
        out_tri1->t[2].v = MUL(t, outside_texcoords[1]->v - inside_texcoords[0]->v) + inside_texcoords[0]->v;

        return 1;  // return the newly formed single triangle
    }

    if (nb_inside_points == 2 && nb_outside_points == 1) {
        // Triangle should be clipped. As two points lie inside the plane, the clipped triangle becomes a "quad".
        // Fortunately, we can represent a quad with two new triangles.

        // Copy appearance info to new triangle
        out_tri1->col = in_tri->col;
        out_tri2->col = in_tri->col;

        fx32 t;

        // The first triangle consists of the two inside points and a new point determined by the location where one
        // side of the triangle intersects with the plane
        out_tri1->p[0] = *inside_points[0];
        out_tri1->t[0] = *inside_texcoords[0];
        out_tri1->p[1] = *inside_points[1];
        out_tri1->t[1] = *inside_texcoords[1];
        out_tri1->p[2] = vector_intersect_plane(&plane_p, &plane_n, inside_points[0], outside_points[0], &t);
        out_tri1->t[2].u = MUL(t, outside_texcoords[0]->u - inside_texcoords[0]->u) + inside_texcoords[0]->u;
        out_tri1->t[2].v = MUL(t, outside_texcoords[0]->v - inside_texcoords[0]->v) + inside_texcoords[0]->v;

        // The second triangle is composed of one the the inside points, a new point determined by the intersection
        // of the other side of the triangle and the plane, and the newly created point above
        out_tri2->p[0] = *inside_points[1];
        out_tri2->t[0] = *inside_texcoords[1];
        out_tri2->p[1] = out_tri1->p[2];
        out_tri2->t[1] = out_tri1->t[2];
        out_tri2->p[2] = vector_intersect_plane(&plane_p, &plane_n, inside_points[1], outside_points[0], &t);
        out_tri2->t[2].u = MUL(t, outside_texcoords[0]->u - inside_texcoords[1]->u) + inside_texcoords[1]->u;
        out_tri2->t[2].v = MUL(t, outside_texcoords[0]->v - inside_texcoords[1]->v) + inside_texcoords[1]->v;

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

void draw_model(int viewport_width, int viewport_height, vec3d* vec_camera, model_t* model, mat4x4* mat_world,
                mat4x4* mat_proj, mat4x4* mat_view, bool is_lighting_ena, bool is_wireframe, texture_t* texture) {
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
        tri.col = face->col;

        triangle_t tri_viewed, tri_projected, tri_transformed;

        tri_transformed.p[0] = matrix_multiply_vector(mat_world, &tri.p[0]);
        tri_transformed.p[1] = matrix_multiply_vector(mat_world, &tri.p[1]);
        tri_transformed.p[2] = matrix_multiply_vector(mat_world, &tri.p[2]);
        tri_transformed.t[0] = tri.t[0];
        tri_transformed.t[1] = tri.t[1];
        tri_transformed.t[2] = tri.t[2];

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

        if (is_lighting_ena) {
            normal = vector_normalize(&normal);
        }

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
                dp = vector_dot_product(&light_direction, &normal);

                if (dp < FX(0.0f)) dp = FX(0.0f);
            }
            tri_transformed.col.x = dp;
            tri_transformed.col.y = dp;
            tri_transformed.col.z = dp;

            // convert world space to view space
            tri_viewed.p[0] = matrix_multiply_vector(mat_view, &tri_transformed.p[0]);
            tri_viewed.p[1] = matrix_multiply_vector(mat_view, &tri_transformed.p[1]);
            tri_viewed.p[2] = matrix_multiply_vector(mat_view, &tri_transformed.p[2]);
            tri_viewed.t[0] = tri_transformed.t[0];
            tri_viewed.t[1] = tri_transformed.t[1];
            tri_viewed.t[2] = tri_transformed.t[2];

            // clip viewed triangle against near plane, this could form two additional triangles
            int nb_clipped_triangles = 0;
            triangle_t clipped[2];
            const fx32 z_near = FX(1.0f);
            vec3d plane_p = {FX(0.0f), FX(0.0f), z_near, FX(1.0f)};
            vec3d plane_n = {FX(0.0f), FX(0.0f), FX(1.0f), FX(1.0f)};
            nb_clipped_triangles = triangle_clip_against_plane(plane_p, plane_n, &tri_viewed, &clipped[0], &clipped[1]);

            for (int n = 0; n < nb_clipped_triangles; ++n) {
                // project triangles from 3D to 2D
                tri_projected.p[0] = matrix_multiply_vector(mat_proj, &clipped[n].p[0]);
                tri_projected.p[1] = matrix_multiply_vector(mat_proj, &clipped[n].p[1]);
                tri_projected.p[2] = matrix_multiply_vector(mat_proj, &clipped[n].p[2]);
                tri_projected.col = tri_transformed.col;
                tri_projected.t[0] = clipped[n].t[0];
                tri_projected.t[1] = clipped[n].t[1];
                tri_projected.t[2] = clipped[n].t[2];

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

    // sort triangles from front to back
    sort_triangles(model->triangles_to_raster, triangle_to_raster_index);

    for (size_t i = 0; i < triangle_to_raster_index; ++i) {
        triangle_t tri_to_raster = model->triangles_to_raster[triangle_to_raster_index - i - 1];

        // clip triangles against all four screen edges, this could yield a bunch of triangles
        triangle_t clipped[2];
        triangle_t triangles[8];
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
                for (int w = 0; w < nb_tris_to_add; ++w) triangles[nb_triangles++] = clipped[w];
            }
            nb_new_triangles = nb_triangles;
        }

        for (int i = 0; i < nb_triangles; ++i) {
            triangle_t* t = &triangles[i];
            // rasterize triangle
            fx32 col = MUL(t->col.x, FX(255.0f));

            if (is_wireframe) {
                xd_draw_triangle(INT(t->p[0].x), INT(t->p[0].y), INT(t->p[1].x), INT(t->p[1].y), INT(t->p[2].x),
                                 INT(t->p[2].y), 0xFFF);
            } else {
                xd_draw_textured_triangle(INT(t->p[0].x), INT(t->p[0].y), t->t[0].u, t->t[0].v, INT(t->p[1].x),
                                          INT(t->p[1].y), t->t[1].u, t->t[1].v, INT(t->p[2].x), INT(t->p[2].y),
                                          t->t[2].u, t->t[2].v, texture);
            }
        }
    }
}