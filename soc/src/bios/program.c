#include <stddef.h>

#define RAM_START   0x00000000

#define BASE_IO     0xE0000000

#define LED         (BASE_IO + 4)
#define UART_DATA   (BASE_IO + 8)
#define UART_STATUS (BASE_IO + 12)

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
        unsigned int c = MEM_READ(UART_DATA);
        word |= c;
    }
    return word;
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

void main(void)
{
#if FAST_CPU
    // Fast bitrate
    MEM_WRITE(UART_STATUS, 0x1);
#endif

    if (receive_program())
        start_prog();
}
