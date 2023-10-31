#ifndef DISPLAY_H
#define DISPLAY_H

#include <stdint.h>
#include <stdbool.h>
#include <SDL.h>

#define FPS 30
#define FRAME_TARGET_TIME (1000 / FPS)

extern SDL_Window* window;
extern SDL_Renderer* renderer;
extern uint16_t* color_buffer;
extern fix16_t* z_buffer;
extern SDL_Texture* color_buffer_texture;
extern int window_width;
extern int window_height;

bool initialize_window(void);
void draw_grid(void);
void draw_pixel(int x, int y, uint16_t color);
void draw_horiz_line(int x0, int x1, int y, uint16_t color);
void draw_line(int x0, int y0, int x1, int y1, uint16_t color);
void draw_rect(int x, int y, int width, int height, uint16_t color);
void render_color_buffer(void);
void clear_color_buffer(uint16_t color);
void clear_z_buffer();
void destroy_window(void);

#endif
