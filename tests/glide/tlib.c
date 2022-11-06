// tlib.c
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Based on tlib.c from the Glide SDK

#include "tlib.h"

#include <math.h>
#include <string.h>

static TlMatrix currentMatrix;

float tlScaleX(float coord) { return coord * 320.0f; };
float tlScaleY(float coord) { return coord * 240.0f; };

#define DEGREE (.01745328f)

const float* tlIdentity(void) {
    static TlMatrix m;
    m[0][0] = 1.0f, m[0][1] = 0.0f, m[0][2] = 0.0f, m[0][3] = 0.0f;
    m[1][0] = 0.0f, m[1][1] = 1.0f, m[1][2] = 0.0f, m[1][3] = 0.0f;
    m[2][0] = 0.0f, m[2][1] = 0.0f, m[2][2] = 1.0f, m[2][3] = 0.0f;
    m[3][0] = 0.0f, m[3][1] = 0.0f, m[3][2] = 0.0f, m[3][3] = 1.0f;
    return &m[0][0];
}

const float* tlXRotation(float degrees) {
    static TlMatrix m;
    float c = (float)cos(degrees * DEGREE);
    float s = (float)sin(degrees * DEGREE);
    m[0][0] = 1.0f, m[0][1] = 0.0f, m[0][2] = 0.0f, m[0][3] = 0.0f;
    m[1][0] = 0.0f, m[1][1] = c, m[1][2] = s, m[1][3] = 0.0f;
    m[2][0] = 0.0f, m[2][1] = -s, m[2][2] = c, m[2][3] = 0.0f;
    m[3][0] = 0.0f, m[3][1] = 0.0f, m[3][2] = 0.0f, m[3][3] = 1.0f;
    return &m[0][0];
}

const float* tlYRotation(float degrees) {
    static TlMatrix m;
    float c = (float)cos(degrees * DEGREE);
    float s = (float)sin(degrees * DEGREE);
    m[0][0] = c, m[0][1] = 0.0f, m[0][2] = -s, m[0][3] = 0.0f;
    m[1][0] = 0.0f, m[1][1] = 1.0f, m[1][2] = 0.0f, m[1][3] = 0.0f;
    m[2][0] = s, m[2][1] = 0.0f, m[2][2] = c, m[2][3] = 0.0f;
    m[3][0] = 0.0f, m[3][1] = 0.0f, m[3][2] = 0.0f, m[3][3] = 1.0f;
    return &m[0][0];
}

const float* tlZRotation(float degrees) {
    static TlMatrix m;
    float c = (float)cos(degrees * DEGREE);
    float s = (float)sin(degrees * DEGREE);
    m[0][0] = c, m[0][1] = s, m[0][2] = 0.0f, m[0][3] = 0.0f;
    m[1][0] = -s, m[1][1] = c, m[1][2] = 0.0f, m[1][3] = 0.0f;
    m[2][0] = 0.0f, m[2][1] = 0.0f, m[2][2] = 1.0f, m[2][3] = 0.0f;
    m[3][0] = 0.0f, m[3][1] = 0.0f, m[3][2] = 0.0f, m[3][3] = 1.0f;
    return &m[0][0];
}

const float* tlTranslation(float x, float y, float z) {
    static TlMatrix m;
    m[0][0] = 1.0f, m[0][1] = 0.0f, m[0][2] = 0.0f, m[0][3] = 0.0f;
    m[1][0] = 0.0f, m[1][1] = 1.0f, m[1][2] = 0.0f, m[1][3] = 0.0f;
    m[2][0] = 0.0f, m[2][1] = 0.0f, m[2][2] = 1.0f, m[2][3] = 0.0f;
    m[3][0] = x, m[3][1] = y, m[3][2] = z, m[3][3] = 1.0f;
    return &m[0][0];
}

void tlSetMatrix(const float* m) {
    memcpy(currentMatrix, m, sizeof(TlMatrix));
    return;
}

void tlMultMatrix(const float* m) {
    TlMatrix result;
    TlMatrix mat;
    int i, j;

    memcpy(mat, m, sizeof(TlMatrix));

    for (j = 0; j < 4; j++) {
        for (i = 0; i < 4; i++) {
            result[j][i] = currentMatrix[j][0] * mat[0][i] + currentMatrix[j][1] * mat[1][i] +
                           currentMatrix[j][2] * mat[2][i] + currentMatrix[j][3] * mat[3][i];
        }
    }
    memcpy(currentMatrix, result, sizeof(TlMatrix));
}

void tlTransformVertices(TlVertex3D* dstVerts, TlVertex3D* srcVerts, unsigned length) {
    TlVertex3D tmp, v;
    TlMatrix m;
    unsigned i;

    memcpy(m, currentMatrix, sizeof(TlMatrix));
    for (i = 0; i < length; i++) {
        v = srcVerts[i];
        tmp = v;
        tmp.x = v.x * m[0][0] + v.y * m[1][0] + v.z * m[2][0] + v.w * m[3][0];
        tmp.y = v.x * m[0][1] + v.y * m[1][1] + v.z * m[2][1] + v.w * m[3][1];
        tmp.z = v.x * m[0][2] + v.y * m[1][2] + v.z * m[2][2] + v.w * m[3][2];
        tmp.w = v.x * m[0][3] + v.y * m[1][3] + v.z * m[2][3] + v.w * m[3][3];
        dstVerts[i] = tmp;
    }
    return;
}

#define VP_OFFSET 1.0f
#define VP_SCALE 0.5f

void tlProjectVertices(TlVertex3D* dstVerts, TlVertex3D* srcVerts, unsigned length) {
    TlVertex3D tmp, v;
    TlMatrix m;
    unsigned i;

    /* simplified perspective proj matrix assume unit clip volume */
    m[0][0] = 1.0f, m[0][1] = 0.0f, m[0][2] = 0.0f, m[0][3] = 0.0f;
    m[1][0] = 0.0f, m[1][1] = 1.0f, m[1][2] = 0.0f, m[1][3] = 0.0f;
    m[2][0] = 0.0f, m[2][1] = 0.0f, m[2][2] = 1.0f, m[2][3] = 1.0f;
    m[3][0] = 0.0f, m[3][1] = 0.0f, m[3][2] = 0.0f, m[3][3] = 0.0f;

    for (i = 0; i < length; i++) {
        v = srcVerts[i];
        tmp = v;
        tmp.x = v.x * m[0][0] + v.y * m[1][0] + v.z * m[2][0] + v.w * m[3][0];
        tmp.y = v.x * m[0][1] + v.y * m[1][1] + v.z * m[2][1] + v.w * m[3][1];
        tmp.z = v.x * m[0][2] + v.y * m[1][2] + v.z * m[2][2] + v.w * m[3][2];
        tmp.w = v.x * m[0][3] + v.y * m[1][3] + v.z * m[2][3] + v.w * m[3][3];
        tmp.x /= tmp.w, tmp.y /= tmp.w, tmp.z /= tmp.w;
        tmp.x += VP_OFFSET, tmp.x *= VP_SCALE;
        tmp.y += VP_OFFSET, tmp.y *= VP_SCALE;
        dstVerts[i] = tmp;
    }
}
