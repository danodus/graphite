#include "light.h"

light_t light;

///////////////////////////////////////////////////////////////////////////////
// Change color based on a percentage factor to represent light intensity
///////////////////////////////////////////////////////////////////////////////
uint16_t light_apply_intensity(uint16_t original_color, fix16_t percentage_factor) {
    if (percentage_factor < fix16_from_float(0)) percentage_factor = fix16_from_float(0);
    if (percentage_factor > fix16_from_float(1)) percentage_factor = fix16_from_float(1);

    uint16_t a = (original_color & 0xF000);
    uint16_t r = fix16_to_int(fix16_mul(fix16_from_int(original_color & 0x0F00), percentage_factor));
    uint16_t g = fix16_to_int(fix16_mul(fix16_from_int(original_color & 0x00F0), percentage_factor));
    uint16_t b = fix16_to_int(fix16_mul(fix16_from_int(original_color & 0x000F), percentage_factor));

    uint16_t new_color = a | (r & 0x0F00) | (g & 0x00F0) | (b & 0x000F);

    return new_color;
}
