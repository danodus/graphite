// test0.h
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Clear screen to blue

#include <SDL2/SDL.h>
#include <assert.h>
#include <glide.h>

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

    while (!quit) {
        grBufferClear(0x0000ff, 0, GR_WDEPTHVALUE_FARTHEST);
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
