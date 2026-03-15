#ifndef GR_H
#define GR_H

#include <stddef.h>

#define GR_POINTS 0
#define GR_TRIANGLES 1

void grutInit(const char* title);
void grutSwapBuffers(void);
void grutDisplayFunc(void (*fn)(void));
void grutMainLoop(void);

void grClearColor(float red, float green, float blue);
void grClear(void);

void grBufferData(size_t bufferSize, void* data);
void grDrawArrays(int type);

#endif
