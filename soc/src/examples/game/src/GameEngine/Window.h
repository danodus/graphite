#pragma once

#include <SDL2/SDL.h>

class Window {
public:
    Window();
    ~Window();

    void makeCurrentContext();
    void present(bool vsync);
private:
    SDL_Window* m_window = nullptr;
    SDL_Renderer* m_renderer = nullptr;
};