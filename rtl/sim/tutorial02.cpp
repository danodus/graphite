#include "gr.h"
#include "math.h"

static void RenderSceneCB() {
    grClear();
    grDrawArrays();
    grutSwapBuffers();
}

static void CreateVertexBuffer() {
    Vector3f vertices[1];
    vertices[0] = Vector3f(0.0f, 0.0f, 0.0f);

    grBufferData(sizeof(vertices), vertices);
}

int main(int argc, char** argv) {
    grutInit("Tutorial 02");
    grClearColor(0.0f, 0.0f, 0.0f);
    CreateVertexBuffer();
    grutDisplayFunc(RenderSceneCB);
    grutMainLoop();
    return 0;
}