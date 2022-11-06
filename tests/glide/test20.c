// test20.c
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Renders two interpenetrating triangles with z-buffering

#include <SDL2/SDL.h>
#include <assert.h>
#include <glide.h>

#include "tlib.h"

uint16_t texData[32 * 32];

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

    // set up render state - decal texture - point sampled
    grColorCombine(GR_COMBINE_FUNCTION_SCALE_OTHER, GR_COMBINE_FACTOR_ONE, GR_COMBINE_LOCAL_NONE,
                   GR_COMBINE_OTHER_TEXTURE, FXFALSE);
    grTexFilterMode(GR_TMU0, GR_TEXTUREFILTER_POINT_SAMPLED, GR_TEXTUREFILTER_POINT_SAMPLED);

    // Load texture data
    GrTexInfo texInfo;

    for (int j = 0; j < 32; ++j) {
        for (int i = 0; i < 32; ++i) {
            texData[j * 32 + i] = i < 16 && j < 16   ? 0xFF00
                                  : i < 16 && j > 16 ? 0xF0F0
                                  : i > 16 && j < 16 ? 0xF00F
                                                     : 0xFFFF;
        }
    }

    texInfo.smallLod = GR_LOD_32;
    texInfo.largeLod = GR_LOD_32;
    texInfo.aspectRatio = GR_ASPECT_1x1;
    texInfo.format = GR_TEXFMT_ARGB_4444;
    texInfo.data = (void*)texData;

    grTexDownloadMipMap(GR_TMU0, grTexMinAddress(GR_TMU0), GR_MIPMAPLEVELMASK_BOTH, &texInfo);

    // select texture as source of all texturing operations
    grTexSource(GR_TMU0, grTexMinAddress(GR_TMU0), GR_MIPMAPLEVELMASK_BOTH, &texInfo);

    TlVertex3D srcVerts[4];
    float distance, dDelta;

    /* Initialize Source 3D data - Rectangle on X/Z Plane
       Centered about Y Axis

       0--1  Z+
       |  |  |
       2--3   - X+

     */
    srcVerts[0].x = -0.5f, srcVerts[0].y = 0.0f, srcVerts[0].z = 0.5f, srcVerts[0].w = 1.0f;
    srcVerts[1].x = 0.5f, srcVerts[1].y = 0.0f, srcVerts[1].z = 0.5f, srcVerts[1].w = 1.0f;
    srcVerts[2].x = -0.5f, srcVerts[2].y = 0.0f, srcVerts[2].z = -0.5f, srcVerts[2].w = 1.0f;
    srcVerts[3].x = 0.5f, srcVerts[3].y = 0.0f, srcVerts[3].z = -0.5f, srcVerts[3].w = 1.0f;

    srcVerts[0].s = 0.0f, srcVerts[0].t = 0.0f;
    srcVerts[1].s = 1.0f, srcVerts[1].t = 0.0f;
    srcVerts[2].s = 0.0f, srcVerts[2].t = 1.0f;
    srcVerts[3].s = 1.0f, srcVerts[3].t = 1.0f;

#define RED 0x00ff0000
#define BLUE 0x000000ff

#define MAX_DIST 2.5f
#define MIN_DIST 1.0f

    distance = 1.0f;
    dDelta = 0.01f;

    while (!quit) {
        GrVertex vtxA, vtxB, vtxC, vtxD;
        TlVertex3D xfVerts[4];
        TlVertex3D prjVerts[4];

        grBufferClear(0x00404040, 0, GR_ZDEPTHVALUE_FARTHEST);

        grTexMipMapMode(GR_TMU0, GR_MIPMAP_DISABLE, FXFALSE);
        grTexCombine(GR_TMU0, GR_COMBINE_FUNCTION_LOCAL, GR_COMBINE_FACTOR_NONE, GR_COMBINE_FUNCTION_LOCAL,
                     GR_COMBINE_FACTOR_NONE, FXFALSE, FXFALSE);

        /*----
          A-B
          |\|
          C-D
          -----*/
        vtxA.oow = 1.0f;
        vtxB = vtxC = vtxD = vtxA;

        distance += dDelta;
        if (distance > MAX_DIST || distance < MIN_DIST) {
            dDelta *= -1.0f;
            distance += dDelta;
        }

        tlSetMatrix(tlIdentity());
        tlMultMatrix(tlXRotation(-20.0f));
        tlMultMatrix(tlTranslation(0.0f, -0.3f, distance));

        tlTransformVertices(xfVerts, srcVerts, 4);
        tlProjectVertices(prjVerts, xfVerts, 4);

        vtxA.x = tlScaleX(prjVerts[0].x);
        vtxA.y = tlScaleY(prjVerts[0].y);
        vtxA.oow = 1.0f / prjVerts[0].w;

        vtxB.x = tlScaleX(prjVerts[1].x);
        vtxB.y = tlScaleY(prjVerts[1].y);
        vtxB.oow = 1.0f / prjVerts[1].w;

        vtxC.x = tlScaleX(prjVerts[2].x);
        vtxC.y = tlScaleY(prjVerts[2].y);
        vtxC.oow = 1.0f / prjVerts[2].w;

        vtxD.x = tlScaleX(prjVerts[3].x);
        vtxD.y = tlScaleY(prjVerts[3].y);
        vtxD.oow = 1.0f / prjVerts[3].w;

        vtxA.tmuvtx[0].sow = prjVerts[0].s * 255.0f * vtxA.oow;
        vtxA.tmuvtx[0].tow = prjVerts[0].t * 255.0f * vtxA.oow;

        vtxB.tmuvtx[0].sow = prjVerts[1].s * 255.0f * vtxB.oow;
        vtxB.tmuvtx[0].tow = prjVerts[1].t * 255.0f * vtxB.oow;

        vtxC.tmuvtx[0].sow = prjVerts[2].s * 255.0f * vtxC.oow;
        vtxC.tmuvtx[0].tow = prjVerts[2].t * 255.0f * vtxC.oow;

        vtxD.tmuvtx[0].sow = prjVerts[3].s * 255.0f * vtxD.oow;
        vtxD.tmuvtx[0].tow = prjVerts[3].t * 255.0f * vtxD.oow;

        grDrawTriangle(&vtxA, &vtxB, &vtxD);
        grDrawTriangle(&vtxA, &vtxD, &vtxC);

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
