#pragma once
#include <memory>
#include <cstdio>

class VertexArrayObject;

typedef std::shared_ptr<VertexArrayObject> VertexArrayObjectPtr;

typedef float f32;
typedef int i32;
typedef unsigned int ui32;

struct VertexBufferData {
    void* verticesList = nullptr;
    ui32 vertexSize = 0;
    ui32 listSize = 0;
};