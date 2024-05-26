#include "Game.h"
#include "Window.h"

#include "SDL2/SDL.h"

Game::Game() {
    m_display = std::make_unique<Window>();
}

Game::~Game() {
}

void Game::run() {

    while (m_isRunning) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            switch (event.type) {
                case SDL_QUIT:
                    m_isRunning = false;
                    break;
                case SDL_KEYDOWN:
                    switch (event.key.keysym.sym) {
                        case SDLK_ESCAPE:
                            m_isRunning = false;
                            break;
                    }
                    break;
            }
        }
    }
}

void Game::quit() {
    m_isRunning = false;
}
