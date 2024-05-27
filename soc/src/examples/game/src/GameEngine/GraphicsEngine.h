#pragma once

#include "Vec4.h"
#include "Rect.h"

class GraphicsEngine {
public:
    GraphicsEngine();
    ~GraphicsEngine();

    VertexArrayObjectPtr createVertexArrayObject(const VertexBufferData& data);

    void clear(const Vec4& color);
    void setViewport(const Rect& size);
    void setVertexArrayObject(const VertexArrayObjectPtr& vao);
    void drawTriangles(ui32 vertexCount, ui32 offset);
};