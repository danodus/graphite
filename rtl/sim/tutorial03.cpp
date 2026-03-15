#include "gr.h"
#include "math.h"

static void RenderSceneCB() {
    grClear();
    grDrawArrays(GR_TRIANGLES);
    grutSwapBuffers();
}

static void CreateVertexBuffer() {
    Vector3f vertices[3];
    vertices[0] = Vector3f(-1.0f, -1.0f, 0.0f);
    vertices[1] = Vector3f(1.0f, -1.0f, 0.0f);
    vertices[2] = Vector3f(0.0f, 1.0f, 0.0f);

    grBufferData(sizeof(vertices), vertices);
}

int main(int argc, char** argv) {
    grutInit("Tutorial 03");
    grClearColor(0.0f, 0.0f, 0.0f);
    CreateVertexBuffer();
    grutDisplayFunc(RenderSceneCB);
    grutMainLoop();
    return 0;
}