#ifndef GR_H
#define GR_H

#include <stddef.h>

void grutInit(const char* title);
void grutSwapBuffers(void);
void grutDisplayFunc(void (*fn)(void));
void grutMainLoop(void);

void grClearColor(float red, float green, float blue);
void grClear(void);

void grBufferData(size_t bufferSize, void* data);
void grDrawArrays(void);

#endif
