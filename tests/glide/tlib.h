// tlib.h
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef TLIB_H
#define TLIB_H

typedef struct {
    float x;
    float y;
    float z;
    float w;
    float s;
    float t;
    float r;
    float g;
    float b;
    float a;
} TlVertex3D;

typedef float TlMatrix[4][4];

float tlScaleX(float coord);
float tlScaleY(float coord);

const float* tlIdentity(void);
const float* tlYRotation(float degrees);
const float* tlXRotation(float degrees);
const float* tlTranslation(float x, float y, float z);
void tlSetMatrix(const float* m);
void tlMultMatrix(const float* m);
void tlTransformVertices(TlVertex3D* dstList, TlVertex3D* srcList, unsigned length);
void tlProjectVertices(TlVertex3D* dstList, TlVertex3D* srcList, unsigned length);

#endif  // TLIB_H
