#include <stddef.h>

#include "texture.h"

tex2_t tex2_clone(tex2_t* t) {
    tex2_t result = { t->u, t->v };
    return result;
}