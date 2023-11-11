#define N_CUBE_VERTICES (sizeof(cube_vertices)/sizeof(cube_vertices[0]))
#define N_CUBE_FACES (sizeof(cube_faces)/sizeof(cube_faces[0]))
vec3_t cube_vertices[] = {
{.x=-1.0, .y=-1.0, .z=1.0},
{.x=1.0, .y=-1.0, .z=1.0},
{.x=-1.0, .y=1.0, .z=1.0},
{.x=1.0, .y=1.0, .z=1.0},
{.x=-1.0, .y=1.0, .z=-1.0},
{.x=1.0, .y=1.0, .z=-1.0},
{.x=-1.0, .y=-1.0, .z=-1.0},
{.x=1.0, .y=-1.0, .z=-1.0}
};
face_t cube_faces[] = {
{.a=1, .b=2, .c=3, .color = 0xFFFF},
{.a=3, .b=2, .c=4, .color = 0xFFFF},
{.a=3, .b=4, .c=5, .color = 0xFFFF},
{.a=5, .b=4, .c=6, .color = 0xFFFF},
{.a=5, .b=6, .c=7, .color = 0xFFFF},
{.a=7, .b=6, .c=8, .color = 0xFFFF},
{.a=7, .b=8, .c=1, .color = 0xFFFF},
{.a=1, .b=8, .c=2, .color = 0xFFFF},
{.a=2, .b=8, .c=4, .color = 0xFFFF},
{.a=4, .b=8, .c=6, .color = 0xFFFF},
{.a=7, .b=1, .c=5, .color = 0xFFFF},
{.a=5, .b=1, .c=3, .color = 0xFFFF}
};
