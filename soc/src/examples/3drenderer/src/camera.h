#ifndef CAMERA_H
#define CAMERA_H

#include "vector.h"

typedef struct {
    vec3_t position;
    vec3_t direction;
    vec3_t forward_velocity;
    fix16_t yaw;
    fix16_t pitch;
} camera_t;

void init_camera(vec3_t position, vec3_t direction, vec3_t forward_velocity, fix16_t yaw, fix16_t pitch);
vec3_t get_camera_position(void);
void set_camera_position(vec3_t position);
vec3_t get_camera_direction(void);
void set_camera_direction(vec3_t direction);
vec3_t get_camera_forward_velocity(void);
void set_camera_forward_velocity(vec3_t forward_velocity);
fix16_t get_camera_yaw(void);
void set_camera_yaw(fix16_t yaw);
fix16_t get_camera_pitch(void);
void set_camera_pitch(fix16_t pitch);

vec3_t get_camera_lookat_target(void);

#endif
