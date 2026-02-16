#include "gr.h"

static void RenderSceneCB() {
    grClear();
    grutSwapBuffers();
}

int main(int argc, char** argv) {
    grutInit("Tutorial 01");
    grClearColor(0.0f, 0.0f, 0.0f);
    grutDisplayFunc(RenderSceneCB);
    grutMainLoop();
    return 0;
}