#include "io.h"

// ref: https://stackoverflow.com/questions/8257714/how-to-convert-an-int-to-string-in-c
char *uitoa(unsigned int value, char* result, int base)
{
    // check that the base if valid
    if (base < 2 || base > 36) { *result = '\0'; return result; }

    char* ptr = result, *ptr1 = result, tmp_char;
    int tmp_value;

    for (int i = 0; i < 8; ++i) {
        tmp_value = value;
        value /= base;
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz" [35 + (tmp_value - value * base)];
    }

    *ptr-- = '\0';
    while(ptr1 < ptr) {
        tmp_char = *ptr;
        *ptr--= *ptr1;
        *ptr1++ = tmp_char;
    }
    return result;
}

int chr_avail()
{
    return MEM_READ(UART_STATUS) & 1;
}

char get_chr()
{
    while (1) {
        if (MEM_READ(UART_STATUS) & 1) {
            MEM_WRITE(UART_STATUS, 1);  // Dequeue
            unsigned int c = MEM_READ(UART_DATA);
            return (char)c;
        }
    }
}

void print_chr(char c)
{
    while(!(MEM_READ(UART_STATUS) & 2));
    MEM_WRITE(UART_DATA, c);
}

void print_buf(const char *s, size_t len)
{
    while (len > 0) {
        while(!(MEM_READ(UART_STATUS) & 2));
        MEM_WRITE(UART_DATA, *s);
        s++;
        len--;
    }
}

void print(const char *s)
{
    while (*s) {
        print_chr(*s);        
        s++;
    }
}

int key_avail()
{
    unsigned int ks = MEM_READ(KEYBOARD_STATUS);
    return (ks & (1 << 28));
}

int get_key()
{
    while (!key_avail());
    return MEM_READ(KEYBOARD_DATA) & 0xFF;
}