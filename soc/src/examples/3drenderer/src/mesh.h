#ifndef MESH_H
#define MESH_H

#include "vector.h"
#include "triangle.h"

typedef struct {
    vec3_t* vertices; // dynamic array of vertices
    face_t* faces;    // dynamic array of faces
    vec3_t rotation;  // rotation with x, y and z values
} mesh_t;

extern mesh_t mesh;

void load_cube_mesh_data(void);
void load_f22_mesh_data(void);
#ifdef LOCAL
void load_obj_file_data(char* filename);
#endif

#endif