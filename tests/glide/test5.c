// test5.c
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Renders two interpenetrating triangles with z-buffering

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

    GrVertex vtxA, vtxB, vtxC;
    float zDist;

    // set up render state - flat shading + Z-buffering
    grColorCombine(GR_COMBINE_FUNCTION_LOCAL, GR_COMBINE_FACTOR_NONE, GR_COMBINE_LOCAL_CONSTANT, GR_COMBINE_OTHER_NONE,
                   FXFALSE);
    grDepthBufferMode(GR_DEPTHBUFFER_ZBUFFER);
    grDepthBufferFunction(GR_CMP_GREATER);
    grDepthMask(FXTRUE);

    while (!quit) {
        vtxA.x = tlScaleX(0.25f), vtxA.y = tlScaleY(0.21f);
        vtxB.x = tlScaleX(0.75f), vtxB.y = tlScaleY(0.21f);
        vtxC.x = tlScaleX(0.5f), vtxC.y = tlScaleY(0.79f);

        /*-----------------------------------------------------------
          Depth values should be scaled from reciprocated Depth Value
          then scaled from 0 to 65535.0.

          ooz = ( 1.0f / Z ) * 65535.0f = 65535.0f / Z
          -----------------------------------------------------------*/

        zDist = 10.0f;
        vtxA.ooz = vtxB.ooz = vtxC.ooz = (65535.0f / zDist);

        grConstantColorValue(0x00808080);

        grDrawTriangle(&vtxA, &vtxB, &vtxC);

        vtxA.x = tlScaleX(0.86f), vtxA.y = tlScaleY(0.21f);
        vtxB.x = tlScaleX(0.86f), vtxB.y = tlScaleY(0.79f);
        vtxC.x = tlScaleX(0.14f), vtxC.y = tlScaleY(0.5f);

        /*-----------------------------------------------------------
          Depth values should be scaled from reciprocated Depth Value
          then scaled to ( 0, 65535 )

          ooz = ( 1.0f / Z ) * 65535.0f = 65535.0f / Z
          -----------------------------------------------------------*/

        zDist = 12.5f;
        vtxA.ooz = vtxB.ooz = (65535.0f / zDist);
        zDist = 7.5f;
        vtxC.ooz = (65535.0f / zDist);

        grConstantColorValue(0x0000FF00);

        grDrawTriangle(&vtxA, &vtxB, &vtxC);

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
