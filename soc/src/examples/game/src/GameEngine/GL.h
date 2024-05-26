#ifndef _GL_H_
#define _GL_H_

#include <graphite.h>

#ifdef __cplusplus
extern "C" {
#endif 

void GL_clear(unsigned int color);
void GL_swap(bool vsync);

#ifdef __cplusplus
}
#endif 

#endif // _GL_H_
