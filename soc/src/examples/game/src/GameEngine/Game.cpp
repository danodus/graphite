#include "Game.h"
#include "GraphicsEngine.h"
#include "Window.h"

#include "SDL2/SDL.h"

Game::Game() {
    m_graphicsEngine = std::make_unique<GraphicsEngine>();
    m_display = std::make_unique<Window>();

    m_display->makeCurrentContext();
}

Game::~Game() {
}

void Game::onCreate() {
}

void Game::onUpdate() {
    m_graphicsEngine->clear({FX(1.0f), FX(0.0f), FX(0.0f), FX(1.0f)});
    m_display->present(false);
}

void Game::onQuit() {

}

void Game::run() {

    onCreate();

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

        onUpdate();
    }

    onQuit();
}

void Game::quit() {
    m_isRunning = false;
}
