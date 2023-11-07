#ifndef _IO_H_
#define _IO_H_

#include <stddef.h>

#define BASE_IO     0xE0000000

#define TIMER           (BASE_IO + 0x0000)
#define LED             (BASE_IO + 0x1000)
#define UART_DATA       (BASE_IO + 0x2000)
#define UART_STATUS     (BASE_IO + 0x2004)
#define KEYBOARD_STATUS (BASE_IO + 0x3000)
#define KEYBOARD_DATA   (BASE_IO + 0x3004)

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_) *((volatile unsigned int *)(_addr_))

char *uitoa(unsigned int value, char* result, int base);

char get_chr();
void print_chr(char c);
void print_buf(const char *s, size_t len);
void print(const char *s);

//int key_avail();
//int get_key();

#endif