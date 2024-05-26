#include "GL.h"

#include <io.h>

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

void GL_clear(unsigned int color)
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

void GL_swap(bool vsync)
{
    struct Command cmd;

    cmd.opcode = OP_SWAP;
    cmd.param = vsync ? 0x1 : 0x0;
    send_command(&cmd);
}
