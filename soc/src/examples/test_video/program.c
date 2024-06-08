// program.c
// Copyright (c) 2023-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

#define BASE_IO 0xE0000000
#define BASE_VIDEO 0x1000000

#define TIMER (BASE_IO + 0)
#define LED (BASE_IO + 4)
#define RES (BASE_IO + 36)

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_) *((volatile unsigned int *)(_addr_))

void delay(unsigned int ms)
{
    unsigned int t = MEM_READ(TIMER) + ms;
    while (MEM_READ(TIMER) < t);
}

unsigned int val(int hres, int vres, int x, int y, unsigned int c)
{
    if (x == 0)
        return 0xf800f800;
    if (x == hres/2-1)
        return 0x07e007e0;
    if (y == 0)
        return 0x001f001f;
    if (y == vres-1)
        return 0xffffffff;
    return c;
}

void main(void)
{
    unsigned int res = MEM_READ(RES);
    int hres = res >> 16;
    int vres = res & 0xffff;

    unsigned int counter = 0;
    int error_detected = 0;
    for (;;) {

        for (int y = 0; y < vres; ++y) {
            for (int x = 0; x < hres/2; ++x) {
                unsigned int i = y * (hres * 2) + x * 4;
                MEM_WRITE(BASE_VIDEO + i, val(hres, vres, x, y, counter));
            }
        }

        for (int y = 0; y < vres; ++y) {
            for (int x = 0; x < hres/2; ++x) {
                unsigned int i = y * (hres * 2) + x * 4;
                unsigned int v = MEM_READ(BASE_VIDEO + i);
                if (v != val(hres, vres, x, y, counter))
                    error_detected = 1;
            }
        }

        MEM_WRITE(LED, error_detected ? 0xFF : 0x01);

        counter++;
    }
}
