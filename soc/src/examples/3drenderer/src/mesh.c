#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <fat_filelib.h>

#include "mesh.h"
#include "array.h"

mesh_t mesh = {
    .vertices = NULL,
    .faces = NULL,
    .rotation = { 0, 0, 0 },
    .scale = { 1, 1, 1 },
    .translation = { 0, 0, 0 }
};

void load_obj_file_data(char* filename) {
    FL_FILE* file;
    file = fl_fopen(filename, "r");

    if (file == NULL) {
        printf("Unable to open %s\r\n", filename);
        return;
    }

    tex2_t* texcoords = NULL;

    char line[1024];
    while (fl_fgets(line, 1024, file)) {
        // Vertex information
        if (strncmp(line, "v ", 2) == 0) {
            vec3_t vertex;
            sscanf(line, "v %f %f %f", &vertex.x, &vertex.y, &vertex.z);
            array_push(mesh.vertices, vertex);
        }
        // Texture coordinate information
        if (strncmp(line, "vt ", 3) == 0) {
            tex2_t texcoord;
            sscanf(line, "vt %f %f", &texcoord.u, &texcoord.v);
            array_push(texcoords, texcoord);
        }
        // Face information
        if (strncmp(line, "f ", 2) == 0) {
            int vertex_indices[3];
            int texture_indices[3];
            int normal_indices[3];
            sscanf(line,
                "f %d/%d/%d %d/%d/%d %d/%d/%d",
                &vertex_indices[0], &texture_indices[0], &normal_indices[0],
                &vertex_indices[1], &texture_indices[1], &normal_indices[1],
                &vertex_indices[2], &texture_indices[2], &normal_indices[2]
            );
            face_t face = {
                .a = vertex_indices[0],
                .b = vertex_indices[1],
                .c = vertex_indices[2],
                .a_uv = texcoords[texture_indices[0] - 1],
                .b_uv = texcoords[texture_indices[1] - 1],
                .c_uv = texcoords[texture_indices[2] - 1],
                .color = 0xFFFF
            };
            array_push(mesh.faces, face);
        }
    }
    array_free(texcoords);

    fl_fclose(file);
}
