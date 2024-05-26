#include "Window.h"

#include <cassert>

Window::Window() {

    int window_width, window_height;

    // Use SDL to query what is the fullscreen max. width and height
    SDL_DisplayMode display_mode;
    SDL_GetCurrentDisplayMode(0, &display_mode);
    window_width = display_mode.w;
    window_height = display_mode.h;

    // Create a SDL window
    m_window = SDL_CreateWindow(
        NULL,
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        window_width,
        window_height,
        SDL_WINDOW_BORDERLESS
    );
    assert(m_window);

    // Create a SDL renderer
    m_renderer = SDL_CreateRenderer(m_window, -1, 0);
    assert(m_renderer);
    SDL_SetWindowFullscreen(m_window, SDL_WINDOW_FULLSCREEN);
}

Window::~Window() {
    SDL_DestroyRenderer(m_renderer);
    SDL_DestroyWindow(m_window);
}
