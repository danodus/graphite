#ifndef TEXTURE_H
#define TEXTURE_H

#include <libfixmath/fix16.h>

typedef struct {
    fix16_t u;
    fix16_t v;
} tex2_t;

tex2_t tex2_clone(tex2_t* t);

#endif