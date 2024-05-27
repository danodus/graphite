#pragma once
#include <memory>

#include "VertexArrayObject.h"

class GraphicsEngine;
class Window;
class Game {
public:
    Game();
    ~Game();

    virtual void onCreate();
    virtual void onUpdate();
    virtual void onQuit();

    void run();
    void quit();

protected:
    bool m_isRunning = true;
    std::unique_ptr<GraphicsEngine> m_graphicsEngine;
    std::unique_ptr<Window> m_display;

    VertexArrayObjectPtr m_trianglesVAO;
};