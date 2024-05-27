#include "Game.h"
#include "GraphicsEngine.h"
#include "Window.h"
#include "VertexArrayObject.h"

#include "SDL2/SDL.h"

Game::Game() {
    m_graphicsEngine = std::make_unique<GraphicsEngine>();
    m_display = std::make_unique<Window>();

    m_display->makeCurrentContext();

    m_graphicsEngine->setViewport(m_display->getInnerSize());
}

Game::~Game() {
}

void Game::onCreate() {
    /*
    const fx32 triangleVertices[] = {
        FX(-0.5f), FX(-0.5f), FX(0.0f),
        FX(0.5f), FX(-0.5f), FX(0.0f),
        FX(0.0f), FX(0.5f), FX(0.0f)
    };
    */

    const fx32 triangleVertices[] = {
        FX(-0.5f), FX(-0.5f), FX(15.0f),
        FX(0.0f), FX(0.5f), FX(15.0f),
        FX(0.5f), FX(-0.5f), FX(15.0f)
    };

    m_trianglesVAO = m_graphicsEngine->createVertexArrayObject({
        (void*)triangleVertices,
        sizeof(fx32)*3,
        3
    });
}

void Game::onUpdate() {
    m_graphicsEngine->clear(Vec4(FX(1.0f), FX(0.0f), FX(0.0f), FX(1.0f)));
    m_graphicsEngine->setVertexArrayObject(m_trianglesVAO);
    m_graphicsEngine->drawTriangles(m_trianglesVAO->getVertexBufferSize(), 0);
    m_display->present(true);
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
