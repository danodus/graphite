#ifndef CAMERA_H
#define CAMERA_H

#include "vector.h"

typedef struct {
    vec3_t position;
    vec3_t direction;
    vec3_t forward_velocity;
    fix16_t yaw;
} camera_t;

extern camera_t camera;

#endif
