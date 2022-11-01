// test2.c
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Draws gouraud shaded lines

#include <SDL2/SDL.h>
#include <assert.h>
#include <glide.h>

#include "tlib.h"

int main(int argc, char* argv[]) {
    SDL_Event e;
    int quit = 0;

    GrScreenResolution_t resolution = GR_RESOLUTION_320x240;
    GrHwConfiguration hwconfig;
    static char version[80];
    grGlideGetVersion(version);
    printf("%s\n", version);

    // initialize Glide
    grGlideInit();
    assert(grSstQueryHardware(&hwconfig));
    grSstSelect(0);
    assert(grSstWinOpen(0, resolution, GR_REFRESH_60Hz, GR_COLORFORMAT_ARGB, GR_ORIGIN_UPPER_LEFT, 2, 1));

    // set up render state - gouraud shading
    grColorCombine(GR_COMBINE_FUNCTION_LOCAL, GR_COMBINE_FACTOR_NONE, GR_COMBINE_LOCAL_ITERATED, GR_COMBINE_OTHER_NONE,
                   FXFALSE);

    while (!quit) {
        GrVertex vtxA, vtxB;

        grBufferClear(0x00, 0, GR_WDEPTHVALUE_FARTHEST);

        vtxA.x = tlScaleX(0.0f), vtxA.y = tlScaleY(0.0f);
        vtxA.r = 255.0f, vtxA.g = 0.0f, vtxA.b = 0.0f;

        vtxB.x = tlScaleX(1.0f), vtxB.y = tlScaleY(1.0f);
        vtxB.r = 0.0f, vtxB.g = 255.0f, vtxB.b = 0.0f;

        grDrawLine(&vtxA, &vtxB);

        grBufferSwap(1);

        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                quit = 1;
            } else if (e.type == SDL_KEYDOWN) {
                switch (e.key.keysym.scancode) {
                    case SDL_SCANCODE_ESCAPE:
                        quit = 1;
                        break;
                    default:
                        // do nothing
                        break;
                }
            }
        }
    }

    grSstWinClose();

    return 0;
}
