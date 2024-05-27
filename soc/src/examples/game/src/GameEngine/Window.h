#pragma once

#include <SDL2/SDL.h>
#include "Rect.h"

class Window {
public:
    Window();
    ~Window();

    Rect getInnerSize();

    void makeCurrentContext();
    void present(bool vsync);
private:
    SDL_Window* m_window = nullptr;
    SDL_Renderer* m_renderer = nullptr;
};