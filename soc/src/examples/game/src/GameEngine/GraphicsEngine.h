#pragma once

#include "GL.h"

class GraphicsEngine {
public:
    GraphicsEngine();
    ~GraphicsEngine();

    void clear(const vec3d& color);
};