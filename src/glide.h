// glide.h
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: - https://www.gamers.org/dEngine/xf3D/glide/glidepgm.htm
//       - https://www.gamers.org/dEngine/xf3D/glide/glideref.htm

#ifndef GLIDE_H
#define GLIDE_H

#include <stdint.h>

#include "fx.h"

#define FXFALSE 0
#define FXTRUE 1

#define FXBIT(_x_) (1 << (_x_))

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

#define GR_ZDEPTHVALUE_FARTHEST 0x0000
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
    fx32 sow;  // s texture coordinate (s over w)
    fx32 tow;  // t texture coordinate (t over w)
    fx32 oow;  // 1/w (used mipmapping - really 0xfff/w)
} GrTmuVertex;

typedef struct {
    fx32 x, y, z;  // x, y and z in screen space, z is ignored
    fx32 r, g, b;  // red, green, blue [0..255.0]
    fx32 ooz;      // 65535/Z (used for Z-buffering)
    fx32 a;        // alpha [0..255.0]
    fx32 oow;      // 1/W (used for texturing)
    GrTmuVertex tmuvtx[GLIDE_NUM_TMU];
} GrVertex;

typedef FxI32 GrLOD_t;
#define GR_LOD_32 0x3

typedef FxI32 GrMipMapMode_t;
#define GR_MIPMAP_DISABLE 0x0  // no mip mapping

typedef FxI32 GrAspectRatio_t;
#define GR_ASPECT_1x1 0x3  // 1W x 1H

typedef FxI32 GrTextureFormat_t;
#define GR_TEXFMT_ARGB_4444 0xC

typedef struct {
    GrLOD_t smallLod;
    GrLOD_t largeLod;
    GrAspectRatio_t aspectRatio;
    GrTextureFormat_t format;
    void* data;
} GrTexInfo;

#define GR_MIPMAPLEVELMASK_EVEN FXBIT(0)
#define GR_MIPMAPLEVELMASK_ODD FXBIT(1)
#define GR_MIPMAPLEVELMASK_BOTH (GR_MIPMAPLEVELMASK_EVEN | GR_MIPMAPLEVELMASK_ODD)

typedef FxI32 GrChipID_t;
#define GR_TMU0 0x0

typedef FxI32 GrCombineFunction_t;
#define GR_COMBINE_FUNCTION_LOCAL 0x1
#define GR_COMBINE_FUNCTION_SCALE_OTHER 0x3

typedef FxI32 GrCombineFactor_t;
#define GR_COMBINE_FACTOR_ZERO 0x0
#define GR_COMBINE_FACTOR_NONE GR_COMBINE_FACTOR_ZERO
#define GR_COMBINE_FACTOR_ONE 0x8

typedef FxI32 GrCombineLocal_t;
#define GR_COMBINE_LOCAL_ITERATED 0x0
#define GR_COMBINE_LOCAL_CONSTANT 0x1
#define GR_COMBINE_LOCAL_NONE GR_COMBINE_LOCAL_CONSTANT
#define GR_COMBINE_LOCAL_ITERATED_PERSP_CORRECT 0x4  // extension for Graphite

typedef FxI32 GrCombineOther_t;
#define GR_COMBINE_OTHER_TEXTURE 0x1
#define GR_COMBINE_OTHER_CONSTANT 0x2
#define GR_COMBINE_OTHER_NONE GR_COMBINE_OTHER_CONSTANT

typedef FxI32 GrCmpFnc_t;
#define GR_CMP_GREATER 0x4

typedef FxI32 GrDepthBufferMode_t;
#define GR_DEPTHBUFFER_DISABLE 0x0
#define GR_DEPTHBUFFER_ZBUFFER 0x1

typedef FxI32 GrTextureFilterMode_t;
#define GR_TEXTUREFILTER_POINT_SAMPLED 0x0

//
// Rendering functions
//

void grDrawPoint(const GrVertex* pt);
void grDrawLine(const GrVertex* a, const GrVertex* b);
void grDrawTriangle(const GrVertex* a, const GrVertex* b, const GrVertex* c);

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
void grDepthBufferFunction(GrCmpFnc_t function);
void grDepthBufferMode(GrDepthBufferMode_t mode);
void grDepthMask(FxBool mask);

//
// Texture mapping control functions
//

FxU32 grTexMinAddress(GrChipID_t tmu);
void grTexSource(GrChipID_t tmu, FxU32 startAddress, FxU32 evenOdd, GrTexInfo* info);
void grTexCombine(GrChipID_t tmu, GrCombineFunction_t rgb_function, GrCombineFactor_t rgb_factor,
                  GrCombineFunction_t alpha_function, GrCombineFactor_t alpha_factor, FxBool rgb_invert,
                  FxBool alpha_invert);
void grTexFilterMode(GrChipID_t tmu, GrTextureFilterMode_t minfilter_mode, GrTextureFilterMode_t magfilter_mode);
void grTexDownloadMipMap(GrChipID_t tmu, FxU32 startAddress, FxU32 evenOdd, GrTexInfo* info);
void grTexMipMapMode(GrChipID_t tmu, GrMipMapMode_t mode, FxBool lodBlend);

#endif  // GLIDE_H