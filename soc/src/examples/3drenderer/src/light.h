#ifndef LIGHT_H
#define LIGHT_H

#include <stdint.h>
#include "vector.h"

typedef struct {
    vec3_t direction;
} light_t;

void init_light(vec3_t direction);
vec3_t get_light_direction(void);
uint16_t light_apply_intensity(uint16_t original_color, fix16_t percentage_factor);

#endif