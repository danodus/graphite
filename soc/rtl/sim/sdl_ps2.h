// Ref.: https://fruttenboel.verhoeven272.nl/Oberon/

#ifndef SDL_PS2_H
#define SDL_PS2_H

#include <stdbool.h>
#include <stdint.h>

#define MAX_PS2_CODE_LEN 8

int ps2_encode(int sdl_scancode, bool make, uint8_t out[MAX_PS2_CODE_LEN]);

#endif  // SDL_PS2_H