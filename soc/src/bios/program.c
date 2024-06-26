// program.c
// Copyright (c) 2023-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <stddef.h>

#define RAM_START   0x00000000

#define BASE_IO     0xE0000000
#define BASE_VIDEO  0x1000000

#define LED         (BASE_IO + 4)
#define UART_DATA   (BASE_IO + 8)
#define UART_STATUS (BASE_IO + 12)
#define CONFIG      (BASE_IO + 36)

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_) *((volatile unsigned int *)(_addr_))

unsigned int val(int x, int y, unsigned int c)
{
    if (x == 0 || x == 19 || y == 0 || y == 479)
        return 0xFFFFFFFF;
    return c;
}

void print_chr(char c)
{
    while(!(MEM_READ(UART_STATUS) & 2));
    MEM_WRITE(UART_DATA, c);
}

void print(const char *s)
{
    while (*s) {
        print_chr(*s);        
        s++;
    }
}

void start_prog()
{
    asm volatile(
        "li x15,0x00000000\n"
        "jalr x0,x15,0\n"
    );
}

unsigned int read_word()
{
    unsigned int word = 0;
    for (int i = 0; i < 4; ++i) {
        word <<= 8;
        while(!(MEM_READ(UART_STATUS) & 1));
        MEM_WRITE(UART_STATUS, 1);  // Dequeue
        unsigned int c = MEM_READ(UART_DATA);
        word |= c;
    }
    return word;
}

void echo()
{
    for (;;) {
        while(!(MEM_READ(UART_STATUS) & 1));
        MEM_WRITE(UART_STATUS, 1);  // Dequeue
        unsigned int c = MEM_READ(UART_DATA);
        while(!(MEM_READ(UART_STATUS) & 2));
        MEM_WRITE(UART_DATA, c);
    }
}

int receive_program()
{
    MEM_WRITE(LED, 0xFF);
    print("Ready to receive...\r\n");

    // Read program
    unsigned int addr = RAM_START;
    unsigned int size;
    size = read_word();

    if (size == 0) {
        MEM_WRITE(LED, 0x01);
        return 0;
    }

    for (unsigned int i = 0; i < size; ++i) {
        unsigned int word = read_word();
        MEM_WRITE(addr, word);
        addr += 4;
        MEM_WRITE(LED, i >> 4);        
    }
    MEM_WRITE(LED, 0x00);

    return 1;
}

void flush_cache(void)
{
    // Flush cache
    MEM_WRITE(CONFIG, 0x1);
}

void clear(int color)
{
    unsigned int res = MEM_READ(CONFIG);
    unsigned hres = res >> 16;
    unsigned vres = res & 0xffff;

    unsigned int *fb = (unsigned int *)BASE_VIDEO;
    unsigned int c = color << 16 | color;
    for (unsigned int y = 0; y < vres; y++)
        for (unsigned int x = 0; x < hres / 2; x++) {
            *fb = c;
            fb++;
        }

    flush_cache();
}

void main(void)
{
    clear(0x8410);  // Gray

    if (receive_program())
        start_prog();
}
