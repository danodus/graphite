// test2.c
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Draws a parabolic envelope of lines

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

    // set up render state - flat shading
    grColorCombine(GR_COMBINE_FUNCTION_LOCAL, GR_COMBINE_FACTOR_NONE, GR_COMBINE_LOCAL_CONSTANT, GR_COMBINE_OTHER_NONE,
                   FXFALSE);
    grConstantColorValue(0xFFFFFF);

    while (!quit) {
        grBufferClear(0x000000, 0, GR_WDEPTHVALUE_FARTHEST);

        GrVertex vtxA, vtxB;
        for (int i = 0; i < 100; i++) {
            float pos = ((float)i) / 100.0f;

            vtxA.x = tlScaleX(pos), vtxA.y = tlScaleY(0.0f);
            vtxB.x = tlScaleX(1.0f), vtxB.y = tlScaleY(pos);

            grDrawLine(&vtxA, &vtxB);
        }

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
