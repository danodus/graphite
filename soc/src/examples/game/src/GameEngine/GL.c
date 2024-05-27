#include "GL.h"

#include <io.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

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

struct Buffer {
    GLuint name;
    void *data;
    struct Buffer *next;
};

struct Context {
    GLclampx clear_color_r, clear_color_g, clear_color_b, clear_color_a;
    GLint viewport_x, viewport_y;
    GLsizei viewport_width, viewport_height;
    struct Buffer *buffers;
    struct Buffer *current_buffer;
};

struct Context ctx = {0};

static void send_command(struct Command *cmd)
{
    while (!MEM_READ(GRAPHITE));
    MEM_WRITE(GRAPHITE, (cmd->opcode << 24) | cmd->param);
}

void xd_draw_triangle(vec3d p[3], vec2d t[3], vec3d c[3], texture_t* tex, bool clamp_s, bool clamp_t, int texture_scale_x, int texture_scale_y,
                      bool depth_test, bool perspective_correct)                      
{
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

void gglSwap(GLboolean vsync)
{
    struct Command cmd;

    cmd.opcode = OP_SWAP;
    cmd.param = vsync ? 0x1 : 0x0;
    send_command(&cmd);
}

void glBindBuffer(GLenum target, GLuint buffer)
{
    bool found = false;
    struct Buffer *b = ctx.buffers;
    while (b != NULL) {
        if (b->name == buffer) {
            ctx.current_buffer = b;
            found = true;
            break;
        }
        b = b->next;
    }
    if (!found) {
        fprintf(stderr, "glBindBuffer: buffer named %d not found\n", buffer);
    } else {
        //printf("glBindBuffer: buffer named %d bound\n", buffer);
    }
}

void glBufferData(GLenum target, GLsizeiptr size, const void *data, GLenum usage)
{
    if (data != NULL) {
        ctx.current_buffer->data = malloc(size);
        memcpy(ctx.current_buffer->data, data, size);
    } else {
        ctx.current_buffer->data = NULL;
    }
}

void glClear(GLbitfield mask)
{
    struct Command cmd;

    if (mask & GL_COLOR_BUFFER_BIT) {
        // Clear framebuffer

        unsigned int r = INT(MUL(ctx.clear_color_r, FX(15)));
        unsigned int g = INT(MUL(ctx.clear_color_g, FX(15)));
        unsigned int b = INT(MUL(ctx.clear_color_b, FX(15)));
        unsigned int a = INT(MUL(ctx.clear_color_a, FX(15)));
        uint32_t color = (a << 12) | (r << 8) | (g << 4) | b;

        cmd.opcode = OP_CLEAR;
        cmd.param = color;
        send_command(&cmd);
    }
    if (mask & GL_DEPTH_BUFFER_BIT) {
        // Clear depth buffer
        cmd.opcode = OP_CLEAR;
        cmd.param = 0x010000;
        send_command(&cmd);
    }
}

void glClearColorx(GLclampx red, GLclampx green, GLclampx blue, GLclampx alpha)
{
    ctx.clear_color_r = red;
    ctx.clear_color_g = green;
    ctx.clear_color_b = blue;
    ctx.clear_color_a = alpha;
}

static void deleteBuffer(GLuint name)
{
    struct Buffer *b = ctx.buffers, *pb = NULL;
    while (b != NULL) {
        if (b->name == name) {
            if (pb != NULL) {
                pb->next = b->next;
            } else {
                ctx.buffers = b->next;
            }
            if (b->data)
                free(b->data);
            free(b);
            break;
        }
        pb = b;
        b = b->next;
    }
}

void glDeleteBuffers(GLsizei n, const GLuint *buffers)
{
    for (GLsizei i = 0; i < n; ++i)
        deleteBuffer(buffers[i]);
}

static void drawTriangle(fx32 v[9])
{
    vec3d vertices[3];
    vertices[0] = (vec3d){v[0], v[1], v[2], FX(1.0f)};
    vertices[1] = (vec3d){v[3], v[4], v[5], FX(1.0f)};
    vertices[2] = (vec3d){v[6], v[7], v[8], FX(1.0f)};

    vec3d vec_camera = {
        FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)
    };

    face_t face = {0};
    face.indices[0] = 0;
    face.indices[1] = 1;
    face.indices[2] = 2;

    triangle_t triangles_to_raster[2];

    model_t model = {0};
    model.mesh.nb_vertices = 9;
    model.mesh.nb_faces = 1;
    model.mesh.vertices = vertices;
    model.mesh.faces = &face;
    model.triangles_to_raster = triangles_to_raster;

    //mat4x4 mat_proj = matrix_make_projection(ctx.viewport_width, ctx.viewport_height, 60.0f);
    mat4x4 mat_proj = matrix_make_identity();
    mat4x4 mat_world = matrix_make_identity();
    mat4x4 mat_view = matrix_make_identity();
    
    draw_model(ctx.viewport_width, ctx.viewport_height, &vec_camera, &model, &mat_world, NULL, &mat_proj, &mat_view, NULL, 0, false, NULL, false, false, 0, 0, false);
}

void glDrawArrays(GLenum mode, GLint first, GLsizei count)
{
    struct Buffer *b = ctx.current_buffer;
    if (b != NULL) {
        if (b->data != NULL) {
            GLfixed *d = b->data;
            d += first;
            for (GLsizei i = 0; i < count / 3; ++i) {
                //printf("glDrawArrays: draw triangle (%x,%x,%x), (%x,%x,%x), (%x,%x,%x)\n", d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8]);
                drawTriangle((fx32 *)d);
                d += 9;
            }
        } else {
            printf("glDrawArrays: no data\n");
        }
    } else {
        fprintf(stderr, "glDrawArrays: no bound buffer\n");
    }
}

static GLuint genBuffer()
{
    struct Buffer *b = ctx.buffers, *pb = NULL;
    GLuint name = 1;
    while (b != NULL) {
        if (b->name > name)
            name = b->name + 1;
        pb = b;
        b = b->next;
    }
    struct Buffer *nb = malloc(sizeof(struct Buffer));
    nb->name = name;
    nb->data = NULL;
    nb->next = NULL;
    if (pb == NULL) {
        ctx.buffers = nb;
    } else {
        pb->next = nb;
    }
    return name;
}

void glGenBuffers(GLsizei n, GLuint *buffers)
{
    for (GLsizei i = 0; i < n; ++i)
        buffers[i] = genBuffer();
}

void glViewport(int left, int top, int width, int height)
{
    ctx.viewport_x = left;
    ctx.viewport_y = top;
    ctx.viewport_width = width;
    ctx.viewport_height = height;
}
