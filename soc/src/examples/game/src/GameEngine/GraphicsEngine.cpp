#include "GraphicsEngine.h"
#include "VertexArrayObject.h"

#include "GL.h"
#include <stdexcept>

GraphicsEngine::GraphicsEngine() {
}

GraphicsEngine::~GraphicsEngine() {
}

VertexArrayObjectPtr GraphicsEngine::createVertexArrayObject(const VertexBufferData& data) {
    return std::make_shared<VertexArrayObject>(data);
}

void GraphicsEngine::clear(const Vec4& color) {
    glClearColorx(color.x(), color.y(), color.z(), color.w());
    //glClear(GL_COLOR_BUFFER_BIT);
    // TODO: Remove this hack
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

void GraphicsEngine::setViewport(const Rect& size) {
    glViewport(size.left, size.top, size.width, size.height);
}

void GraphicsEngine::setVertexArrayObject(const VertexArrayObjectPtr& vao) {
    glBindBuffer(GL_ARRAY_BUFFER, vao->getId());
}

void GraphicsEngine::drawTriangles(ui32 vertexCount, ui32 offset) {
    glDrawArrays(GL_TRIANGLES, offset, vertexCount);
}
