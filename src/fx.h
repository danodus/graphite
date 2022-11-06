// fx.h
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef FX_H
#define FX_H

#include <math.h>
#include <stdint.h>

#ifndef FIXED_POINT
#define FIXED_POINT 0
#endif

#define _FRACTION_MASK(scale) (0xffffffff >> (32 - scale))
#define _WHOLE_MASK(scale) (0xffffffff ^ FRACTION_MASK(scale))

#define _FLOAT_TO_FIXED(x, scale) ((int32_t)((x) * (float)(1 << scale)))
#define _FLOAT_TO_FIXED_UNSIGNED(x, scale) ((uint32_t)((x) * (float)(1 << scale)))
#define _FIXED_TO_FLOAT(x, scale) ((float)(x) / (double)(1 << scale))
#define _INT_TO_FIXED(x, scale) ((x) << scale)
#define _FIXED_TO_INT(x, scale) ((x) >> scale)
#define _FRACTION_PART(x, scale) ((x)&FRACTION_MASK(scale))
#define _WHOLE_PART(x, scale) ((x)&WHOLE_MASK(scale))

#define _MUL(x, y, scale) (int32_t)(((int64_t)(x) * (int64_t)(y)) >> scale)
#define _MUL_UNSIGNED(x, y, scale) (uint32_t)(((uint64_t)(x) * (uint64_t)(y)) >> scale)
//#define _MUL(x, y, scale) ((int32_t)((x) >> (scale / 2)) * (int32_t)((y) >> (scale / 2)))

#define _DIV(x, y, scale) (int32_t)(((int64_t)(x) << scale) / (y))
#define _DIV_UNSIGNED(x, y, scale) (uint32_t)(((uint64_t)(x) << scale) / (y))
//#define _DIV(x, y, scale) (((int32_t)(x) << (scale / 2)) / (int32_t)((y) >> (scale / 2)))
//#define _DIV2(x, y, scale, adj) (((int32_t)(x) << (scale / 2 - (adj))) / (int32_t)((y) >> (scale / 2 + (adj))))

#if FIXED_POINT

typedef int32_t fx32;

#define SCALE 16

#define FX(x) ((fx32)_FLOAT_TO_FIXED(x, SCALE))
#define FX_UNSIGNED(x) ((fx32)_FLOAT_TO_FIXED_UNSIGNED(x, SCALE))
#define FXI(x) ((fx32)_INT_TO_FIXED(x, SCALE))
#define INT(x) ((int)_FIXED_TO_INT(x, SCALE))
#define FLT(x) ((float)_FIXED_TO_FLOAT(x, SCALE))
#define MUL(x, y) _MUL(x, y, SCALE)
#define MUL_UNSIGNED(x, y) _MUL_UNSIGNED(x, y, SCALE)
#define DIV(x, y) _DIV(x, y, SCALE)
#define DIV_UNSIGNED(x, y) _DIV(x, y, SCALE)

#define SIN(x) FX(sinf(_FIXED_TO_FLOAT(x, SCALE)))
#define COS(x) FX(cosf(_FIXED_TO_FLOAT(x, SCALE)))
#define TAN(x) FX(tanf(_FIXED_TO_FLOAT(x, SCALE)))
#define SQRT(x) FX(sqrtf(_FIXED_TO_FLOAT(x, SCALE)))

#else

typedef float fx32;

#define FX(x) (x)
#define FX_UNSIGNED(x) FX(x)
#define FXI(x) ((float)(x))
#define INT(x) ((int)(x))
#define FLT(x) (x)
#define MUL(x, y) ((x) * (y))
#define MUL_UNSIGNED(x, y) MUL(x, y)
#define DIV(x, y) ((x) / (y))
#define DIV_UNSIGNED(x, y) DIV(x, y)

#define SIN(x) (sinf(x))
#define COS(x) (cosf(x))
#define TAN(x) (tanf(x))
#define SQRT(x) (sqrtf(x))

#endif

#ifndef RASTERIZER_FIXED_POINT
#define RASTERIZER_FIXED_POINT 1
#endif

#if RASTERIZER_FIXED_POINT

typedef int32_t rfx32;

#define RSCALE 16

#define RFX(x) ((rfx32)_FLOAT_TO_FIXED(x, RSCALE))
#define RFXI(x) ((rfx32)_INT_TO_FIXED(x, RSCALE))
#define RINT(x) ((int)_FIXED_TO_INT(x, RSCALE))
#define RFLT(x) ((float)_FIXED_TO_FLOAT(x, RSCALE))
#define RMUL(x, y) _MUL(x, y, RSCALE)
#define RDIV(x, y) _DIV(x, y, RSCALE)

#define RSIN(x) RFX(sinf(_FIXED_TO_FLOAT(x, RSCALE)))
#define RCOS(x) RFX(cosf(_FIXED_TO_FLOAT(x, RSCALE)))
#define RTAN(x) RFX(tanf(_FIXED_TO_FLOAT(x, RSCALE)))
#define RSQRT(x) RFX(sqrtf(_FIXED_TO_FLOAT(x, RSCALE)))

#if FIXED_POINT
#define RFXP(x) (x)
#else
#define RFXP(x) ((rfx32)_FLOAT_TO_FIXED(x, RSCALE))
#endif

#else  // RASTERIZER_FIXED_POINT

typedef float rfx32;

#define RFX(x) (x)
#define RFXI(x) ((float)(x))
#define RINT(x) ((int)(x))
#define RFLT(x) (x)
#define RMUL(x, y) ((x) * (y))
#define RDIV(x, y) ((x) / (y))

#define RSIN(x) (sinf(x))
#define RCOS(x) (cosf(x))
#define RTAN(x) (tanf(x))
#define RSQRT(x) (sqrtf(x))

#if FIXED_POINT
#define RFXP(x) ((float)_FIXED_TO_FLOAT(x, SCALE))
#else
#define RFXP(x) (x)
#endif

#endif  // RASTERIZER_FIXED_POINT

#endif  // FX_H