// program.c
// Copyright (c) 2023-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <graphite.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <io.h>
#include <sd_card.h>
#include <fat_filelib.h>
#include <upng.h>
#include <array.h>

#define BASE_VIDEO 0x1000000

#define TEXTURE_WIDTH 32
#define TEXTURE_HEIGHT 32

#define OP_SET_X0 0
#define OP_SET_Y0 1
#define OP_SET_Z0 2
#define OP_SET_X1 3
#define OP_SET_Y1 4
#define OP_SET_Z1 5
#define OP_SET_X2 6
#define OP_SET_Y2 7
#define OP_SET_Z2 8
#define OP_SET_R0 9
#define OP_SET_G0 10
#define OP_SET_B0 11
#define OP_SET_R1 12
#define OP_SET_G1 13
#define OP_SET_B1 14
#define OP_SET_R2 15
#define OP_SET_G2 16
#define OP_SET_B2 17
#define OP_SET_S0 18
#define OP_SET_T0 19
#define OP_SET_S1 20
#define OP_SET_T1 21
#define OP_SET_S2 22
#define OP_SET_T2 23
#define OP_CLEAR 24
#define OP_DRAW 25
#define OP_SWAP 26
#define OP_SET_TEX_ADDR 27
#define OP_SET_FB_ADDR 28

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_) *((volatile unsigned int *)(_addr_))

#define PARAM(x) (x)

struct Command {
    uint32_t opcode : 8;
    uint32_t param : 24;
};

int fb_width, fb_height;

uint16_t *img = NULL;

int nb_triangles;
bool rasterizer_ena = true;

sd_context_t sd_ctx;

int read_sector(uint32_t sector, uint8_t *buffer, uint32_t sector_count) {
    for (uint32_t i = 0; i < sector_count; ++i) {
        if (!sd_read_single_block(&sd_ctx, sector + i, buffer))
            return 0;
        buffer += SD_BLOCK_LEN;
    }
    return 1;
}

int write_sector(uint32_t sector, uint8_t *buffer, uint32_t sector_count) {
    for (uint32_t i = 0; i < sector_count; ++i) {
        if (!sd_write_single_block(&sd_ctx, sector + i, buffer))
            return 0;
        buffer += SD_BLOCK_LEN;
    }
    return 1;
}

void send_command(struct Command *cmd)
{
    while (!MEM_READ(GRAPHITE));
    MEM_WRITE(GRAPHITE, (cmd->opcode << 24) | cmd->param);
}

void xd_draw_triangle(vec3d p[3], vec2d t[3], vec3d c[3], texture_t* tex, bool clamp_s, bool clamp_t, int texture_scale_x, int texture_scale_y,
                      bool depth_test, bool perspective_correct)                      
{
    nb_triangles++;
    if (!rasterizer_ena)
        return;

    struct Command cmd;

    cmd.opcode = OP_SET_X0;
    cmd.param = PARAM(p[0].x) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(p[0].x) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_Y0;
    cmd.param = PARAM(p[0].y) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(p[0].y) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_Z0;
    cmd.param = PARAM(t[0].w) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(t[0].w) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_X1;
    cmd.param = PARAM(p[1].x) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(p[1].x) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_Y1;
    cmd.param = PARAM(p[1].y) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(p[1].y) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_Z1;
    cmd.param = PARAM(t[1].w) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(t[1].w) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_X2;
    cmd.param = PARAM(p[2].x) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(p[2].x) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_Y2;
    cmd.param = PARAM(p[2].y) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(p[2].y) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_Z2;
    cmd.param = PARAM(t[2].w) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(p[2].z) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_S0;
    cmd.param = PARAM(t[0].u) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(t[0].u) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_T0;
    cmd.param = PARAM(t[0].v) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(t[0].v) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_S1;
    cmd.param = PARAM(t[1].u) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(t[1].u) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_T1;
    cmd.param = PARAM(t[1].v) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(t[1].v) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_S2;
    cmd.param = PARAM(t[2].u) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(t[2].u) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_T2;
    cmd.param = PARAM(t[2].v) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(t[2].v) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_R0;
    cmd.param = PARAM(c[0].x) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(c[0].x) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_G0;
    cmd.param = PARAM(c[0].y) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(c[0].y) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_B0;
    cmd.param = PARAM(c[0].z) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(c[0].z) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_R1;
    cmd.param = PARAM(c[1].x) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(c[1].x) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_G1;
    cmd.param = PARAM(c[1].y) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(c[1].y) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_B1;
    cmd.param = PARAM(c[1].z) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(c[1].z) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_R2;
    cmd.param = PARAM(c[2].x) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(c[2].x) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_G2;
    cmd.param = PARAM(c[2].y) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(c[2].y) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_SET_B2;
    cmd.param = PARAM(c[2].z) & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (PARAM(c[2].z) >> 16);
    send_command(&cmd);

    cmd.opcode = OP_DRAW;

    cmd.param = (depth_test ? 0b01000 : 0b00000) | (clamp_s ? 0b00100 : 0b00000) | (clamp_t ? 0b00010 : 0b00000) |
              ((tex != NULL) ? 0b00001 : 0b00000) | (perspective_correct ? 0b10000 : 0xb00000);

    cmd.param |= texture_scale_x << 5;
    cmd.param |= texture_scale_y << 8;

    send_command(&cmd);
}

void clear(unsigned int color)
{
    struct Command cmd;

    // Clear framebuffer
    cmd.opcode = OP_CLEAR;
    cmd.param = color;
    send_command(&cmd);
    // Clear depth buffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x010000;
    send_command(&cmd);
}

bool load_texture(const char *path, int *texture_scale_x, int *texture_scale_y) {
    uint32_t tex_addr = (0x1000000 >> 1) + 3 * fb_width * fb_height;

    upng_t* png_image = upng_new_from_file(path);
    if (png_image != NULL) {
        upng_decode(png_image);
        if (upng_get_error(png_image) != UPNG_EOK) {
            printf("Unable to open %s\r\n", path);
            return false;
        }
    }

    struct Command cmd;
    cmd.opcode = OP_SET_TEX_ADDR;
    cmd.param = tex_addr & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (tex_addr >> 16);
    send_command(&cmd);

    int texture_width = upng_get_width(png_image);
    int texture_height = upng_get_height(png_image);

    uint32_t* texture_buffer = (uint32_t *)upng_get_buffer(png_image);

    uint16_t* vram = 0;
    for (int t = 0; t < texture_height; ++t)
        for (int s = 0; s < texture_width; ++s) {

            uint8_t* tc = (uint8_t*)(&texture_buffer[(texture_width * t) + s]);
            uint16_t cr = tc[0] >> 4;
            uint16_t cg = tc[1] >> 4;
            uint16_t cb = tc[2] >> 4;
            uint16_t ca = tc[3] >> 4;

            vram[tex_addr++] = (ca << 12) | (cr << 8) | (cg << 4) | cb;
        }

    upng_free(png_image);

    *texture_scale_x = -5;
    while (texture_width >>= 1) (*texture_scale_x)++;

    *texture_scale_y = -5;
    while (texture_height >>= 1) (*texture_scale_y)++;

    if (*texture_scale_x < 0 || *texture_scale_y < 0) {
        printf("Invalid texture size\r\n");
        return false;
    }

    return true;
}

bool load_mesh_obj_data(mesh_t *mesh, char *obj_filename) {
    FL_FILE* file;
    file = fl_fopen(obj_filename, "r");

    if (file == NULL) {
        printf("Unable to open %s\r\n", obj_filename);
        return false;
    }

    memset(mesh, 0, sizeof(mesh_t));

    char line[1024];
    while (fl_fgets(line, 1024, file)) {
        // Vertex information
        if (strncmp(line, "v ", 2) == 0) {
            float x, y, z;
            sscanf(line, "v %f %f %f", &x, &y, &z);
            vec3d v = {
                .x = FX(x),
                .y = FX(y),
                .z = FX(z),
                .w = FX(1.0f)
            };
            array_push(mesh->vertices, v);
            mesh->nb_vertices++;
        }
        // Vertex normal information
        if (strncmp(line, "vn ", 3) == 0) {
            float x, y, z;
            sscanf(line, "vn %f %f %f", &x, &y, &z);
            vec3d v = {
                .x = FX(x),
                .y = FX(y),
                .z = FX(z),
                .w = FX(0.0f)
            };
            array_push(mesh->normals, v);
            mesh->nb_normals++;
        }        
        // Texture coordinate information
        if (strncmp(line, "vt ", 3) == 0) {
            float u, v;
            sscanf(line, "vt %f %f", &u, &v);
            vec2d t = {
                .u = FX(u),
                .v = FX(1.0f - v),
                .w = FX(1.0f)
            };
            array_push(mesh->texcoords, t);
            mesh->nb_texcoords++;
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
            face_t face = {0};
            for (int i = 0; i < 3; i++) {
                face.indices[i] = vertex_indices[i] - 1;
                face.col_indices[i] = 0;
                face.tex_indices[i] = texture_indices[i] - 1;
                face.norm_indices[i] = normal_indices[i] - 1;
            }
            array_push(mesh->faces, face);
            mesh->nb_faces++;
        }
    }

    fl_fclose(file);
    return true;
}

void swap()
{
    struct Command cmd;

    cmd.opcode = OP_SWAP;
    cmd.param = 0x1;
    send_command(&cmd);
}

void print_help(void)
{
    printf("[h]: help, [q]: quit, [s]: stats, [SPACE]: rotation,\r\n"
        "[t]: texture, [l]: lighting, [g]: gouraud shading, [w]: wireframe, [m]: model,\r\n"
        "[u]: clamp s, [v] clamp t, [r] rasterizer ena, [p]: perspective correct\r\n");
}

void main(void)
{
    print("Demo\r\n");

    if (!sd_init(&sd_ctx)) {
        printf("SD card initialization failed.\r\n");
        return;
    }

    fl_init();

    // Attach media access functions to library
    if (fl_attach_media(read_sector, write_sector) != FAT_INIT_OK)
    {
        printf("Failed to init file system\r\n");
        return;
    }    

    unsigned int res = MEM_READ(RES);
    fb_width = res >> 16;
    fb_height = res & 0xffff;

    float theta = 0.5f;

    mat4x4 mat_proj = matrix_make_projection(fb_width, fb_height, 60.0f);

    // camera
    vec3d  vec_camera = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
    mat4x4 mat_view   = matrix_make_identity();

    model_t f22_model = {0};

    if (!load_mesh_obj_data(&f22_model.mesh, "/assets/f22.obj")) {
        fl_shutdown();
        return;
    }

    int texture_scale_x, texture_scale_y;
    if (!load_texture("/assets/f22.png", &texture_scale_x, &texture_scale_y)) {
        fl_shutdown();
        return;
    }

    printf("texture scale x,y: %d, %d\r\n", texture_scale_x, texture_scale_y);

    f22_model.triangles_to_raster = malloc(2 * f22_model.mesh.nb_faces * sizeof(triangle_t));

    model_t *model = &f22_model;

    bool quit = false;
    bool print_stats = false;
    bool is_rotating = false;
    bool is_textured = true;
    size_t nb_lights = 0;
    bool is_wireframe = false;
    bool clamp_s = false;
    bool clamp_t = false;
    bool perspective_correct = true;
    bool gouraud_shading = false;

    light_t lights[5];
    lights[0].direction = (vec3d){FX(0.0f), FX(0.0f), FX(1.0f), FX(0.0f)};
    lights[0].ambient_color = (vec3d){FX(0.1f), FX(0.1f), FX(0.1f), FX(1.0f)};
    lights[0].diffuse_color = (vec3d){FX(0.5f), FX(0.5f), FX(0.5f), FX(1.0f)};
    lights[1].direction = (vec3d){FX(1.0f), FX(0.0f), FX(0.0f), FX(0.0f)};
    lights[1].ambient_color = (vec3d){FX(0.1f), FX(0.0f), FX(0.0f), FX(1.0f)};
    lights[1].diffuse_color = (vec3d){FX(0.2f), FX(0.0f), FX(0.0f), FX(1.0f)};
    lights[2].direction = (vec3d){FX(0.0f), FX(1.0f), FX(0.0f), FX(0.0f)};
    lights[2].ambient_color = (vec3d){FX(0.0f), FX(0.1f), FX(0.0f), FX(1.0f)};
    lights[2].diffuse_color = (vec3d){FX(0.0f), FX(0.2f), FX(0.0f), FX(1.0f)};
    lights[3].direction = (vec3d){FX(0.0f), FX(-1.0f), FX(0.0f), FX(0.0f)};
    lights[3].ambient_color = (vec3d){FX(0.0f), FX(0.0f), FX(0.1f), FX(1.0f)};
    lights[3].diffuse_color = (vec3d){FX(0.0f), FX(0.0f), FX(0.2f), FX(1.0f)};
    lights[4].direction = (vec3d){FX(-1.0f), FX(0.0f), FX(0.0f), FX(0.0f)};
    lights[4].ambient_color = (vec3d){FX(0.1f), FX(0.1f), FX(0.0f), FX(1.0f)};
    lights[4].diffuse_color = (vec3d){FX(0.2f), FX(0.2f), FX(0.0f), FX(1.0f)};      

    print_help();

    uint32_t counter = 0;
    while(!quit) {
        MEM_WRITE(LED, counter >> 2);
        counter++;

        if (chr_avail()) {
            char c = get_chr();
            if (c == 'h') {
                print_help();
            } else if (c == 'q') {
                quit = true;
            } else if (c == 's') {
                print_stats = !print_stats;
            } else if (c == ' ') {
                is_rotating = !is_rotating;
            } else if (c == 't') {
                is_textured = !is_textured;
            } else if (c == 'l') {
                nb_lights = (nb_lights + 1) % 6;
            } else if (c == 'w') {
                is_wireframe = !is_wireframe;
            } else if (c == 'm') {
                // TODO
            } else if (c == 'u') {
                clamp_s = !clamp_s;
            } else if (c == 'v') {
                clamp_t = !clamp_t;
            } else if (c == 'r') {
                rasterizer_ena = !rasterizer_ena;
            } else if (c == 'p') {
                perspective_correct = !perspective_correct;
            } else if (c == 'g') {
                gouraud_shading = !gouraud_shading;
            }
        }        

        uint32_t t1 = MEM_READ(TIMER);

        uint32_t t1_clear = MEM_READ(TIMER);
        if (rasterizer_ena)
            clear(0x0006);
        uint32_t t2_clear = MEM_READ(TIMER);

        uint32_t t1_xform = MEM_READ(TIMER);
        // world
        mat4x4 mat_rot_z = matrix_make_rotation_z(theta);
        mat4x4 mat_rot_x = matrix_make_rotation_x(theta);
        mat4x4 mat_scale = matrix_make_scale(FX(2.0f), FX(2.0f), FX(2.0f));

        mat4x4 mat_trans = matrix_make_translation(FX(0.0f), FX(0.0f), FX(5.0f));
        mat4x4 mat_world, mat_normal;
        mat_world = matrix_make_identity();
        mat_world = mat_normal = matrix_multiply_matrix(&mat_rot_z, &mat_rot_x);
        //mat_world = matrix_multiply_matrix(&mat_world, &mat_scale);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_trans);
        uint32_t t2_xform = MEM_READ(TIMER);

        uint32_t t1_draw = MEM_READ(TIMER);
        texture_t dummy_texture;
        nb_triangles = 0;
        draw_model(fb_width, fb_height, &vec_camera, model, &mat_world, gouraud_shading ? &mat_normal : NULL, &mat_proj, &mat_view, lights, nb_lights, is_wireframe, is_textured ? &dummy_texture : NULL, clamp_s, clamp_t, texture_scale_x, texture_scale_y, perspective_correct);
        uint32_t t2_draw = MEM_READ(TIMER);

        swap();

        if (is_rotating) {
            theta += 0.1f;
            if (theta > 6.28f)
                theta = 0.0f;
        }

        uint32_t t2 = MEM_READ(TIMER);

        if (print_stats)
            printf("xform: %d ms, clear: %d ms, draw: %d ms, total: %d ms, nb triangles: %d, tri/sec: %d\r\n", t2_xform - t1_xform, t2_clear - t1_clear, t2_draw - t1_draw, t2 - t1, nb_triangles, nb_triangles * 1000 / (t2 - t1));
    }

    fl_shutdown();
}
