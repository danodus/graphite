#ifndef DISPLAY_H
#define DISPLAY_H

#include <stdint.h>
#include <stdbool.h>
#include <SDL.h>

#define FPS 30
#define FRAME_TARGET_TIME (1000 / FPS)

typedef enum {
    CULL_NONE,
    CULL_BACKFACE
} cull_method_t;

typedef enum {
    RENDER_WIRE,
    RENDER_WIRE_VERTEX,
    RENDER_FILL_TRIANGLE,
    RENDER_FILL_TRIANGLE_WIRE,
    RENDER_TEXTURED,
    RENDER_TEXTURED_WIRE
} render_method_t;

bool initialize_window(void);
int get_window_width(void);
int get_window_height(void);

void set_render_method(render_method_t method);
render_method_t get_render_method();
void set_cull_method(cull_method_t method);
cull_method_t get_cull_method();

void draw_grid(void);
void draw_pixel(int x, int y, uint16_t color);
void draw_horiz_line(int x0, int x1, int y, uint16_t color);
void draw_line(int x0, int y0, int x1, int y1, uint16_t color);
void draw_rect(int x, int y, int width, int height, uint16_t color);

void render_color_buffer(void);
void clear_color_buffer(uint16_t color);
void clear_z_buffer();

fix16_t get_zbuffer_at(int x, int y);
void update_zbuffer_at(int x, int y, fix16_t value);

void destroy_window(void);

#endif
