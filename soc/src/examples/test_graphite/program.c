#include <stdint.h>
#include <graphite.h>
#include <cube.h>
#include <teapot.h>
#include <stdlib.h>
#include <stdio.h>
#include <io.h>

#define BASE_IO 0xE0000000
#define BASE_VIDEO 0x1000000

#define TIMER (BASE_IO + 0)
#define LED (BASE_IO + 4)
#define GRAPHITE (BASE_IO + 32)

#define FB_WIDTH 640
#define FB_HEIGHT 480

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
#define OP_WRITE_TEX 28

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_) *((volatile unsigned int *)(_addr_))

#define PARAM(x) (x)

struct Command {
    uint32_t opcode : 8;
    uint32_t param : 24;
};

uint16_t *img = NULL;

int nb_triangles;
bool rasterizer_ena = true;

bool init_img() {
    img = (uint16_t *)malloc(TEXTURE_WIDTH * TEXTURE_HEIGHT * sizeof(uint16_t));
    if (!img)
        return false;
    uint16_t *p = img;
    for (int v = 0; v < TEXTURE_HEIGHT; ++v) {
        for (int u = 0; u < TEXTURE_WIDTH; ++u) {
            if (u < TEXTURE_WIDTH / 2 && v < TEXTURE_HEIGHT / 2) {
                *p = 0xFFFF;
            } else if (u >= TEXTURE_WIDTH / 2 && v < TEXTURE_HEIGHT / 2) {
                *p = 0xFF00;
            } else if (u < TEXTURE_WIDTH / 2 && v >= TEXTURE_HEIGHT / 2) {
                *p = 0xF0F0;
            } else {
                *p = 0xF00F;
            }
            ++p;
        }
    }
    return true;
}

void dispose_img() {
    free(img);
}

void send_command(struct Command *cmd)
{
    while (!MEM_READ(GRAPHITE));
    MEM_WRITE(GRAPHITE, (cmd->opcode << 24) | cmd->param);
}

void xd_draw_triangle(vec3d p[3], vec2d t[3], vec3d c[3], texture_t* tex, bool clamp_s, bool clamp_t,
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

void write_texture() {
    uint32_t tex_addr = 3 * FB_WIDTH * FB_HEIGHT;

    struct Command cmd;
    cmd.opcode = OP_SET_TEX_ADDR;
    cmd.param = tex_addr & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (tex_addr >> 16);
    send_command(&cmd);

    cmd.opcode = OP_WRITE_TEX;
    const uint16_t* p = img;
    for (int t = 0; t < 32; ++t)
        for (int s = 0; s < 32; ++s) {
            cmd.param = *p;
             send_command(&cmd);
            p++;
        }
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
        "[t]: texture, [l]: lighting, [g]: gouraud shading, [w]: wireframe, [m]: teapot/cube,\r\n"
        "[u]: clamp s, [v] clamp t, [r] rasterizer ena, [p]: perspective correct\r\n");
}

void main(void)
{
    print_help();

    float theta = 0.5f;

    mat4x4 mat_proj = matrix_make_projection(FB_WIDTH, FB_HEIGHT, 60.0f);

    // camera
    vec3d  vec_camera = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
    mat4x4 mat_view   = matrix_make_identity();

    model_t *cube_model = load_cube();
    model_t *teapot_model = load_teapot();

    model_t *model = cube_model;

    if (!init_img()) {
        printf("Out of memory\r\n");
        return;
    }

    write_texture();

    bool quit = false;
    bool print_stats = false;
    bool is_rotating = false;
    bool is_textured = false;
    bool is_lighting_ena = false;
    bool is_wireframe = false;
    bool clamp_s = false;
    bool clamp_t = false;
    bool perspective_correct = true;
    bool gouraud_shading = false;

    clear(0xF333);

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
                is_lighting_ena = !is_lighting_ena;
            } else if (c == 'w') {
                is_wireframe = !is_wireframe;
            } else if (c == 'm') {
                if (model == cube_model) {
                    model = teapot_model;
                } else {
                    model = cube_model;
                }
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
            clear(0x00F333);
        uint32_t t2_clear = MEM_READ(TIMER);

        uint32_t t1_xform = MEM_READ(TIMER);
        // world
        mat4x4 mat_rot_z = matrix_make_rotation_z(theta);
        mat4x4 mat_rot_x = matrix_make_rotation_x(theta);

        mat4x4 mat_trans = matrix_make_translation(FX(0.0f), FX(0.0f), FX(5.0f));
        mat4x4 mat_world, mat_normal;
        mat_world = matrix_make_identity();
        mat_world = mat_normal = matrix_multiply_matrix(&mat_rot_z, &mat_rot_x);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_trans);
        uint32_t t2_xform = MEM_READ(TIMER);

        uint32_t t1_draw = MEM_READ(TIMER);
        texture_t dummy_texture;
        nb_triangles = 0;
        draw_model(FB_WIDTH, FB_HEIGHT, &vec_camera, model, &mat_world, gouraud_shading ? &mat_normal : NULL, &mat_proj, &mat_view, is_lighting_ena, is_wireframe, is_textured ? &dummy_texture : NULL, clamp_s, clamp_t, perspective_correct);
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

    dispose_img();
}
