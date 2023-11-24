#include <stdio.h>
#include <math.h>

#include <libfixmath/fix16.h>

#include "display.h"

static SDL_Window* window = NULL;
static SDL_Renderer* renderer = NULL;
static uint16_t* color_buffer = NULL;
static fix16_t* z_buffer = NULL;
static SDL_Texture* color_buffer_texture = NULL;
static int window_width = 640;
static int window_height = 480;

static render_method_t render_method = RENDER_WIRE;
static cull_method_t cull_method = CULL_NONE;

int get_window_width(void) {
    return window_width;
}

int get_window_height(void) {
    return window_height;
}

void set_render_method(render_method_t method) {
    render_method = method;
}

render_method_t get_render_method() {
    return render_method;
}

void set_cull_method(cull_method_t method) {
    cull_method = method;
}

cull_method_t get_cull_method() {
    return cull_method;
}

bool initialize_window(void) {
    if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
        fprintf(stderr, "Error initializing SDL.\n");
        return false;
    }

    // Use SDL to query what is the fullscreen max. width and height
    SDL_DisplayMode display_mode;
    SDL_GetCurrentDisplayMode(0, &display_mode);
    window_width = display_mode.w;
    window_height = display_mode.h;

    // Create a SDL window
    window = SDL_CreateWindow(
        NULL,
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        window_width,
        window_height,
        SDL_WINDOW_BORDERLESS
    );
    if (!window) {
        fprintf(stderr, "Error creating SDL window.\n");
        return false;
    }

    // Create a SDL renderer
    renderer = SDL_CreateRenderer(window, -1, 0);
    if (!renderer) {
        fprintf(stderr, "Error creating SDL renderer.\n");
        return false;
    }
    SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN);

    // Allocate the required memory in bytes to hold the color buffer
    color_buffer = (uint16_t*)malloc(sizeof(uint16_t) * window_width * window_height);
    z_buffer = (fix16_t*)malloc(sizeof(fix16_t) * window_width * window_height);

    // Creating a SDL texture that is used to display the color buffer
    color_buffer_texture = SDL_CreateTexture(
        renderer,
        SDL_PIXELFORMAT_ARGB4444,
        SDL_TEXTUREACCESS_STREAMING,
        window_width,
        window_height
    );    

    return true;
}

void draw_grid(void) {
    for (int y = 0; y < window_height; y += 10)
        for (int x = 0; x < window_width; x += 10)
            color_buffer[(window_width * y) + x] = 0xF333;
}

void draw_pixel(int x, int y, uint16_t color) {
    if (x < 0 || x >= window_width || y < 0 && y >= window_height)
        return;
    color_buffer[(window_width * y) + x] = color;
}

void draw_horiz_line(int x0, int x1, int y, uint16_t color) {
    if (x1 < x0) {
        int t = x0;
        x0 = x1;
        x1 = t;
    }    
    for (int x = x0; x <= x1; x++)
        draw_pixel(x, y, color);
}

void draw_line(int x0, int y0, int x1, int y1, uint16_t color) {
    int delta_x = x1 - x0;
    int delta_y = y1 - y0;

    int longest_side_length = (abs(delta_x) >= abs(delta_y)) ? abs(delta_x) : abs(delta_y);

    fix16_t x_inc = fix16_div(fix16_from_int(delta_x), fix16_from_int(longest_side_length));
    fix16_t y_inc = fix16_div(fix16_from_int(delta_y), fix16_from_int(longest_side_length));

    fix16_t x = fix16_from_int(x0);
    fix16_t y = fix16_from_int(y0);
    for (int i = 0; i <= longest_side_length; i++) {
        draw_pixel(fix16_to_int(x), fix16_to_int(y), color);
        x += x_inc;
        y += y_inc;        
    }
}

void draw_rect(int x, int y, int width, int height, uint16_t color) {
    for (int j = y; j < y + height; j++)
        for (int i = x; i < x + width; i++)
            draw_pixel(i, j, color);
}

void render_color_buffer(void) {
    SDL_UpdateTexture(
        color_buffer_texture,
        NULL,
        color_buffer,
        (int)(window_width * sizeof(uint16_t))
    );
    SDL_RenderCopy(renderer, color_buffer_texture, NULL, NULL);
    SDL_RenderPresent(renderer);    
}

void clear_color_buffer(uint16_t color) {
    for (int i = 0; i < window_width * window_height; i++) {
        color_buffer[i] = color;
    }
}

void clear_z_buffer(void) {
    for (int i = 0; i < window_width * window_height; i++) {
        z_buffer[i] = fix16_from_float(1.0);
    }
}

fix16_t get_zbuffer_at(int x, int y) {
    if (x < 0 || x >= window_width || y < 0 || y >= window_height)
        return fix16_from_float(1.0);
    return z_buffer[(window_width * y) + x];
}

void update_zbuffer_at(int x, int y, fix16_t value) {
    if (x < 0 || x >= window_width || y < 0 || y >= window_height)
        return;
    z_buffer[(window_width * y) + x] = value;
}

void destroy_window(void) {
    free(z_buffer);
    free(color_buffer);
    SDL_DestroyTexture(color_buffer_texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
}
