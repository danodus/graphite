// SDL.h
// Copyright (c) 2024 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef _SDL_H_
#define _SDL_H_

#include <stdint.h>
#include <stdlib.h>

typedef uint32_t Uint32;
typedef int32_t Sint32;
typedef uint8_t Uint8;

#define SDL_TICKS_PASSED(A, B)  ((Sint32)((B) - (A)) <= 0)

#define SDL_INIT_EVERYTHING 0
#define SDL_WINDOWPOS_CENTERED 0
#define SDL_WINDOW_BORDERLESS 0

#define SDL_DEFINE_PIXELFORMAT(type, order, layout, bits, bytes) \
    ((1 << 28) | ((type) << 24) | ((order) << 20) | ((layout) << 16) | \
     ((bits) << 8) | ((bytes) << 0))

#define SDLK_SCANCODE_MASK (1<<30)
#define SDL_SCANCODE_TO_KEYCODE(x) (x | SDLK_SCANCODE_MASK)

typedef enum {
    SDL_SCANCODE_RIGHT = 79,
    SDL_SCANCODE_LEFT = 80,
    SDL_SCANCODE_DOWN = 81,
    SDL_SCANCODE_UP = 82
} SDL_Scancode;

enum {
    SDLK_UNKNOWN = 0,
    SDLK_ESCAPE = '\033',
    SDLK_1 = '1',
    SDLK_2 = '2',
    SDLK_3 = '3',
    SDLK_4 = '4',
    SDLK_5 = '5',
    SDLK_6 = '6',
    SDLK_a = 'a',
    SDLK_c = 'c',
    SDLK_d = 'd',
    SDLK_s = 's',
    SDLK_w = 'w',
    SDLK_x = 'x',

    SDLK_RIGHT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RIGHT),
    SDLK_LEFT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LEFT),
    SDLK_DOWN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_DOWN),
    SDLK_UP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_UP)
};

typedef enum {
    SDL_FIRSTEVENT = 0,
    SDL_QUIT = 0x100,
    SDL_KEYDOWN = 0x300,
    SDL_KEYUP
} SDL_EventType;

typedef enum {
    SDL_PIXELTYPE_PACKED16 = 5
} SDL_PixelType;

typedef enum {
    SDL_PACKEDORDER_XRGB = 1
} SDL_PackedOrder;

typedef enum {
    SDL_PACKEDLAYOUT_565 = 5
} SDL_PackedLayout;

typedef enum {
    SDL_PIXELFORMAT_RGB565 = SDL_DEFINE_PIXELFORMAT(SDL_PIXELTYPE_PACKED16, SDL_PACKEDORDER_XRGB,
                               SDL_PACKEDLAYOUT_565, 16, 2)
} SDL_PixelFormatEnum;

typedef enum {
    SDL_TEXTUREACCESS_STREAMING = 1
} SDL_TextureAccess;

typedef enum
{
    SDL_WINDOW_FULLSCREEN = 0x00000001
} SDL_WindowFlags;

typedef Sint32 SDL_Keycode;

typedef struct {
    int w;
    int h;
} SDL_DisplayMode;

typedef struct {
} SDL_Window;

typedef struct {
    Uint8 draw_color[4];
} SDL_Renderer;

typedef struct {
    int w, h;
    uint16_t *data;
} SDL_Texture;

typedef struct SDL_Keysym {
    SDL_Keycode sym;
} SDL_Keysym;

typedef struct {
    SDL_Keysym keysym;
} SDL_KeyboardEvent;

typedef struct {
    SDL_EventType type;
    SDL_KeyboardEvent key;
} SDL_Event;

typedef struct {
} SDL_Rect;

int SDL_Init(Uint32 flags);

int SDL_GetCurrentDisplayMode(int displayIndex, SDL_DisplayMode * mode);
int SDL_SetWindowFullscreen(SDL_Window * window, Uint32 flags);

SDL_Window * SDL_CreateWindow(
    const char * title,
    int x,
    int y,
    int w,
    int h,
    Uint32 flags
);

SDL_Renderer * SDL_CreateRenderer(
    SDL_Window * window,
    int index,
    Uint32 flags);

SDL_Texture * SDL_CreateTexture(SDL_Renderer * renderer,
    Uint32 format,
    int access, int w,
    int h);

int SDL_UpdateTexture(SDL_Texture * texture,
    const SDL_Rect * rect,
    const void *pixels, int pitch);

int SDL_RenderCopy(SDL_Renderer * renderer,
    SDL_Texture * texture,
    const SDL_Rect * srcrect,
    const SDL_Rect * dstrect);

int SDL_PollEvent(SDL_Event * event);

int SDL_SetRenderDrawColor(SDL_Renderer * renderer,
                   Uint8 r, Uint8 g, Uint8 b,
                   Uint8 a);

int SDL_RenderClear(SDL_Renderer * renderer);                   

void SDL_RenderPresent(SDL_Renderer * renderer);

void SDL_DestroyWindow(SDL_Window * window);
void SDL_DestroyRenderer(SDL_Renderer * renderer);
void SDL_DestroyTexture(SDL_Texture * texture);

void SDL_Quit(void);

Uint32 SDL_GetTicks(void);
void SDL_Delay(Uint32 ms);

#endif // _SDL_H_
