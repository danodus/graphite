// fx.h
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef FX_H
#define FX_H

#ifndef FIXED_POINT
#define FIXED_POINT 1
#endif

#define _FRACTION_MASK(scale) (0xffffffff >> (32 - scale))
#define _WHOLE_MASK(scale) (0xffffffff ^ FRACTION_MASK(scale))

#define _FLOAT_TO_FIXED(x, scale) ((int)((x) * (float)(1 << scale)))
#define _FIXED_TO_FLOAT(x, scale) ((float)(x) / (double)(1 << scale))
#define _INT_TO_FIXED(x, scale) ((x) << scale)
#define _FIXED_TO_INT(x, scale) ((x) >> scale)
#define _FRACTION_PART(x, scale) ((x)&FRACTION_MASK(scale))
#define _WHOLE_PART(x, scale) ((x)&WHOLE_MASK(scale))

#define _MUL(x, y, scale) (int)(((long long)(x) * (long long)(y)) >> scale)
//#define _MUL(x, y, scale) ((int)((x) >> (scale / 2)) * (int)((y) >> (scale / 2)))

#define _DIV(x, y, scale) (int)(((long long)(x) << scale) / (y))
//#define _DIV(x, y, scale) (((int)(x) << (scale / 2)) / (int)((y) >> (scale / 2)))
//#define _DIV2(x, y, scale, adj) (((int)(x) << (scale / 2 - (adj))) / (int)((y) >> (scale / 2 + (adj))))

#if FIXED_POINT

typedef int fx32;

#define SCALE 16

#define FX(x) ((fx32)_FLOAT_TO_FIXED(x, SCALE))
#define FXI(x) ((fx32)_INT_TO_FIXED(x, SCALE))
#define INT(x) ((int)_FIXED_TO_INT(x, SCALE))
#define FLT(x) ((float)_FIXED_TO_FLOAT(x, SCALE))
#ifdef HW_MULT
fx32 xd_hw_mult(fx32 x, fx32 y);
#define MUL(x, y) xd_hw_mult(x, y)
#else
#define MUL(x, y) _MUL(x, y, SCALE)
#endif
#define DIV(x, y) _DIV(x, y, SCALE)
#define DIV2(x, y) _DIV2(x, y, SCALE, 2)

#define SIN(x) FX(sinf(_FIXED_TO_FLOAT(x, SCALE)))
#define COS(x) FX(cosf(_FIXED_TO_FLOAT(x, SCALE)))
#define TAN(x) FX(tanf(_FIXED_TO_FLOAT(x, SCALE)))
#define SQRT(x) FX(sqrtf(_FIXED_TO_FLOAT(x, SCALE)))

#else

typedef float fx32;

#define FX(x) (x)
#define FXI(x) ((float)(x))
#define INT(x) ((int)(x))
#define FLT(x) (x)
#define MUL(x, y) ((x) * (y))
#define DIV(x, y) ((x) / (y))
#define DIV2(x, y) DIV(x, y)

#define SIN(x) (sinf(x))
#define COS(x) (cosf(x))
#define TAN(x) (tanf(x))
#define SQRT(x) (sqrtf(x))

#endif

#endif  // FX_H