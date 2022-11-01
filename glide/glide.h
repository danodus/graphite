// glide.h
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://www.gamers.org/dEngine/xf3D/glide/glideref.htm

#ifndef GLIDE_H
#define GLIDE_H

#include <stdint.h>

#define FXFALSE 0
#define FXTRUE 1

typedef int32_t FxBool;
typedef uint8_t FxU8;
typedef uint16_t FxU16;
typedef int32_t FxI32;
typedef uint32_t FxU32;

typedef FxI32 GrScreenRefresh_t;
#define GR_REFRESH_60Hz 0x0

typedef FxI32 GrScreenResolution_t;
#define GR_RESOLUTION_320x240 0x1

typedef FxI32 GrColorFormat_t;
#define GR_COLORFORMAT_ARGB 0x0

typedef FxI32 GrOriginLocation_t;
#define GR_ORIGIN_UPPER_LEFT 0x0

typedef FxU32 GrColor_t;
typedef FxU8 GrAlpha_t;

#define MAX_NUM_SST 1
#define GLIDE_NUM_TMU 1  // number of texture mapping units

#define GR_WDEPTHVALUE_FARTHEST 0xFFFF

typedef int GrSstType;
#define GR_SSTTYPE_GRAPHITE 1

typedef struct GrGraphiteContig_St {
    int fbRam;  // frame buffer size in MB
} GrGraphiteConfig_t;

typedef struct {
    int num_sst;  // number of hardware units in the system
    struct {
        GrSstType type;
        union DevBoard_u {
            GrGraphiteConfig_t GraphiteConfig;
        } sstBoard;
    } SSTs[MAX_NUM_SST];
} GrHwConfiguration;

typedef struct {
    float sow;  // s texture coordinate (s over w)
    float tow;  // t texture coordinate (t over w)
    float oow;  // 1/w (used mipmapping - really 0xfff/w)
} GrTmuVertex;

typedef struct {
    float x, y, z;  // x, y and z in screen space, z is ignored
    float r, g, b;  // red, green, blue [0..255.0]
    float ooz;      // 65535/Z (used for Z-buffering)
    float a;        // alpha [0..255.0]
    float oow;      // 1/W (used for texturing)
    GrTmuVertex tmuvtx[GLIDE_NUM_TMU];
} GrVertex;

typedef FxI32 GrCombineFunction_t;
#define GR_COMBINE_FUNCTION_LOCAL 0x1

typedef FxI32 GrCombineFactor_t;
#define GR_COMBINE_FACTOR_ZERO 0x0
#define GR_COMBINE_FACTOR_NONE GR_COMBINE_FACTOR_ZERO

typedef FxI32 GrCombineLocal_t;
#define GR_COMBINE_LOCAL_CONSTANT 0x1

typedef FxI32 GrCombineOther_t;
#define GR_COMBINE_OTHER_CONSTANT 0x2
#define GR_COMBINE_OTHER_NONE GR_COMBINE_OTHER_CONSTANT

//
// Rendering functions
//

void grDrawPoint(const GrVertex* pt);
void grDrawLine(const GrVertex* a, const GrVertex* b);

//
// Buffer management
//

void grBufferClear(GrColor_t color, GrAlpha_t alpha, FxU16 depth);
void grBufferSwap(int swap_interval);

//
// SST routines
//

FxBool grSstWinOpen(FxU32 hwnd, GrScreenResolution_t res, GrScreenRefresh_t ref, GrColorFormat_t cformat,
                    GrOriginLocation_t org_loc, int num_buffers, int num_aux_buffers);
void grSstWinClose(void);
FxBool grSstQueryHardware(GrHwConfiguration* hwConfig);
void grSstSelect(int which_sst);

//
// Glide management functions
//

void grGlideInit(void);
void grGlideGetVersion(char version[80]);

//
// Glide configuration and special effect maintenance functions
//

void grColorCombine(GrCombineFunction_t func, GrCombineFactor_t factor, GrCombineLocal_t local, GrCombineOther_t other,
                    FxBool invert);
void grConstantColorValue(GrColor_t value);

#endif  // GLIDE_H