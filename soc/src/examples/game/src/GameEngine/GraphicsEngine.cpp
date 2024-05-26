#include "GraphicsEngine.h"

#include <stdexcept>

GraphicsEngine::GraphicsEngine() {
}

GraphicsEngine::~GraphicsEngine() {
}

void GraphicsEngine::clear(const vec3d& color) {
    unsigned int r = INT(MUL(color.x, FX(15)));
    unsigned int g = INT(MUL(color.y, FX(15)));
    unsigned int b = INT(MUL(color.z, FX(15)));
    unsigned int a = INT(MUL(color.w, FX(15)));
    GL_clear((a << 12) | (r << 8) | (g << 4) | b);
}
