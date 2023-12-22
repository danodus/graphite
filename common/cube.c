
#include "cube.h"

#include <stdlib.h>

static vec3d vertices[] = {
    {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)},  // 0
    {FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)},  // 1
    {FX(1.0f), FX(1.0f), FX(0.0f), FX(1.0f)},  // 2
    {FX(1.0f), FX(0.0f), FX(0.0f), FX(1.0f)},  // 3
    {FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)},  // 4
    {FX(1.0f), FX(0.0f), FX(1.0f), FX(1.0f)},  // 5
    {FX(0.0f), FX(1.0f), FX(1.0f), FX(1.0f)},  // 6
    {FX(0.0f), FX(0.0f), FX(1.0f), FX(1.0f)}   // 7
};

static vec2d texcoords[] = {
    {FX(0.0f), FX(0.0f), FX(1.0f)},  // 0
    {FX(0.0f), FX(1.0f), FX(1.0f)},  // 1
    {FX(1.0f), FX(0.0f), FX(1.0f)},  // 2
    {FX(1.0f), FX(1.0f), FX(1.0f)}   // 3
};

static vec3d colors[] = {
    {FX(1.0f), FX(0.0f), FX(0.0f), FX(1.0f)},  // 0
    {FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)},  // 1
    {FX(0.0f), FX(0.0f), FX(1.0f), FX(1.0f)},  // 2
    {FX(1.0f), FX(1.0f), FX(0.0f), FX(1.0f)}   // 3
};

face_t faces[] = {
    // South
    {{0, 1, 2}, {1, 0, 2}, {1, 0, 2}},
    {{0, 2, 3}, {1, 2, 3}, {1, 2, 3}},

    // East
    {{3, 2, 4}, {1, 0, 2}, {1, 0, 2}},
    {{3, 4, 5}, {1, 2, 3}, {1, 2, 3}},

    // North
    {{5, 4, 6}, {1, 0, 2}, {1, 0, 2}},
    {{5, 6, 7}, {1, 2, 3}, {1, 2, 3}},

    // West
    {{7, 6, 1}, {1, 0, 2}, {1, 0, 2}},
    {{7, 1, 0}, {1, 2, 3}, {1, 2, 3}},

    // Top
    {{1, 6, 4}, {1, 0, 2}, {1, 0, 2}},
    {{1, 4, 2}, {1, 2, 3}, {1, 2, 3}},

    // Bottom
    {{5, 7, 0}, {1, 0, 2}, {1, 0, 2}},
    {{5, 0, 3}, {1, 2, 3}, {1, 2, 3}}};

static model_t g_model;
// note: clipping can produce an additional triangle
static triangle_t g_triangles_to_raster[2 * sizeof(faces) / sizeof(face_t)];

model_t* load_cube() {
    g_model.mesh.nb_faces = sizeof(faces) / sizeof(face_t);
    g_model.mesh.nb_vertices = sizeof(vertices) / sizeof(vec3d);
    g_model.mesh.nb_texcoords = sizeof(texcoords) / sizeof(vec2d);
    g_model.mesh.nb_colors = sizeof(colors) / sizeof(vec3d);
    g_model.mesh.nb_normals = 0;
    g_model.mesh.faces = faces;
    g_model.mesh.vertices = vertices;
    g_model.mesh.texcoords = texcoords;
    g_model.mesh.colors = colors;
    g_model.mesh.normals = NULL;
    g_model.triangles_to_raster = g_triangles_to_raster;

    return &g_model;
}
