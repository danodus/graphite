#pragma once
#include <memory>

class Window;
class Game {
public:
    Game();
    ~Game();

    void run();
    void quit();

protected:
    bool m_isRunning = true;
    std::unique_ptr<Window> m_display;
};