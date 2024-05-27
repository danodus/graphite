#include "VertexArrayObject.h"
#include "GL.h"

VertexArrayObject::VertexArrayObject(const VertexBufferData& data) {
    glGenBuffers(1, &m_vertexBufferId);
    printf("Buffer generated: %d\n", m_vertexBufferId);
    glBindBuffer(GL_ARRAY_BUFFER, m_vertexBufferId);
    glBufferData(GL_ARRAY_BUFFER, data.vertexSize * data.listSize, data.verticesList, GL_STATIC_DRAW);
    
    //glBindBuffer(GL_ARRAY_BUFFER, 0);

    m_vertexBufferData = data;
}

VertexArrayObject::~VertexArrayObject() {
    glDeleteBuffers(1, &m_vertexBufferId);
}

ui32 VertexArrayObject::getId() {
    return m_vertexBufferId;
}

ui32 VertexArrayObject::getVertexBufferSize() {
    return m_vertexBufferData.listSize;
}

ui32 VertexArrayObject::getVertexSize() { 
    return m_vertexBufferData.vertexSize;
}
