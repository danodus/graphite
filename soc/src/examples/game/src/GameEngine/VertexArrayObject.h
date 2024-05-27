#pragma once

#include "Prerequisites.h"

class VertexArrayObject {
public:
    VertexArrayObject(const VertexBufferData& data);
    ~VertexArrayObject();

    ui32 getId();

    ui32 getVertexBufferSize();
    ui32 getVertexSize();
private:
    ui32 m_vertexBufferId = 0;
    VertexBufferData m_vertexBufferData;
};