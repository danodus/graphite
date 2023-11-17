#include "SDL.h"

#include "../io.h"

#include <string.h>

#define BASE_VIDEO  0x1000000

static Uint32 init_timer;

int SDL_Init(
    Uint32 flags
) {
    init_timer = MEM_READ(TIMER);
    return 0;
}

int SDL_GetCurrentDisplayMode(int displayIndex, SDL_DisplayMode * mode) {
    mode->w = 640;
    mode->h = 480;
    return 0;
}

int SDL_SetWindowFullscreen(SDL_Window * window, Uint32 flags) {
    return 0;
}


SDL_Window * SDL_CreateWindow(
    const char * title,
    int x,
    int y,
    int w,
    int h,
    Uint32 flags
) {
    // clear the framebuffer
    for (unsigned int i = 0; i < 640*480*2; i += 4)
        MEM_WRITE(BASE_VIDEO + i, 0x00000000);

    SDL_Window * window = (SDL_Window *) malloc(sizeof(SDL_Window));

    return window;
}

SDL_Renderer * SDL_CreateRenderer(
    SDL_Window * window,
    int index,
    Uint32 flags) {

    SDL_Renderer *renderer = (SDL_Renderer *) malloc(sizeof(renderer));
    renderer->draw_color[0] = 0;
    renderer->draw_color[1] = 0;
    renderer->draw_color[2] = 0;
    renderer->draw_color[3] = 255;

    return renderer;
}

SDL_Texture * SDL_CreateTexture(SDL_Renderer * renderer,
    Uint32 format,
    int access,
    int w,
    int h) {
    SDL_Texture * texture = (SDL_Texture *)malloc(sizeof(SDL_Texture));
    texture->w = w;
    texture->h = h;
    texture->data = malloc(w * h * sizeof(uint16_t));
    return texture;
}

int SDL_UpdateTexture(SDL_Texture * texture,
    const SDL_Rect * rect,
    const void *pixels, int pitch) {
    if (rect)
        return -1;

    memcpy(texture->data, pixels, texture->w * texture->h * sizeof(uint16_t));
    return 0;
}

int SDL_RenderCopy(SDL_Renderer * renderer,
    SDL_Texture * texture,
    const SDL_Rect * srcrect,
    const SDL_Rect * dstrect) {
    if (srcrect || dstrect)
        return -1;
    
    memcpy((uint16_t *)BASE_VIDEO, texture->data, texture->w * texture->h * sizeof(uint16_t));
    return 0;
}

static SDL_Keycode get_keycode(int scancode) {
    switch (scancode) {
        case 0x76:
            return SDLK_ESCAPE;
        case 0x16:
            return SDLK_1;
        case 0x1E:
            return SDLK_2;
        case 0x26:
            return SDLK_3;
        case 0x25:
            return SDLK_4;
        case 0x2E:
            return SDLK_5;
        case 0x36:
            return SDLK_6;
        case 0x21:
            return SDLK_c;
        case 0x23:
            return SDLK_d;
        default:
            return SDLK_UNKNOWN;
    }
}

int SDL_PollEvent(SDL_Event * event) {
    event->type = SDL_FIRSTEVENT;
    if (key_avail()) {
        int scancode = get_key();
        if (scancode == 0xF0) {
            event->type = SDL_KEYUP;
            scancode = get_key();
            event->key.keysym.sym = get_keycode(scancode);
        } else {
            event->type = SDL_KEYDOWN;
            event->key.keysym.sym = get_keycode(scancode);
        }
        return 1;
    }
    return 0;
}

int SDL_SetRenderDrawColor(SDL_Renderer * renderer,
                   Uint8 r, Uint8 g, Uint8 b,
                   Uint8 a) {
    renderer->draw_color[0] = r;
    renderer->draw_color[1] = g;
    renderer->draw_color[2] = b;
    renderer->draw_color[3] = a;
    return 0;
}

int SDL_RenderClear(SDL_Renderer * renderer) {
    uint32_t c;
    c = renderer->draw_color[3] >> 4;
    c = (c << 4) | (renderer->draw_color[0] >> 4);
    c = (c << 4) | (renderer->draw_color[1] >> 4);
    c = (c << 4) | (renderer->draw_color[2] >> 4);
    c = (c << 4) | (renderer->draw_color[3] >> 4);
    c = (c << 4) | (renderer->draw_color[0] >> 4);
    c = (c << 4) | (renderer->draw_color[1] >> 4);
    c = (c << 4) | (renderer->draw_color[2] >> 4);

    for (unsigned int i = 0; i < 640*480*2; i += 4)
        MEM_WRITE(BASE_VIDEO + i, c);

    return 0;
}

void SDL_RenderPresent(SDL_Renderer * renderer) {
}

void SDL_DestroyWindow(SDL_Window * window) {
    if (window)
        free(window);
}

void SDL_DestroyRenderer(SDL_Renderer * renderer) {
    if (renderer)
        free(renderer);
}

void SDL_DestroyTexture(SDL_Texture * texture) {
    if (texture && texture->data)
        free(texture->data);
    if (texture)
        free(texture);
}

void SDL_Quit(void) {
}

Uint32 SDL_GetTicks(void) {
    return MEM_READ(TIMER) - init_timer;
}

void SDL_Delay(Uint32 ms) {
    Uint32 target_time = SDL_GetTicks() + ms;
    while (!SDL_TICKS_PASSED(SDL_GetTicks(), target_time));
}