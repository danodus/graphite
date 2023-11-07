#include <stddef.h>

#define RAM_START   0x00000000

#define BASE_IO     0xE0000000

#define TIMER           (BASE_IO + 0x0000)
#define LED             (BASE_IO + 0x1000)
#define UART_DATA       (BASE_IO + 0x2000)
#define UART_STATUS     (BASE_IO + 0x2004)

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
    while(MEM_READ(UART_STATUS) & 1);
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
        while(!(MEM_READ(UART_STATUS) & 2));
        // dequeue
        MEM_WRITE(UART_STATUS, 0x1);        
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
        MEM_WRITE(LED, i << 1);        
    }
    MEM_WRITE(LED, 0x00);

    return 1;
}

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

int test_mem(void) {
    char s[16];
    for (unsigned int addr = 0x00000000; addr < 0x02000000; addr += 4*1024) {
        unsigned int expected = addr ^ 0x55555555;
        MEM_WRITE(addr, expected);
    }

    for (unsigned int addr = 0x00000000; addr < 0x02000000; addr += 4*1024) {
        unsigned int expected = addr ^ 0x55555555;
        unsigned int read = MEM_READ(addr);
        if (read != expected) {
            print("Mismatch detected at address ");
            print(uitoa(addr, s, 16));
            print(" expected=");
            print(uitoa(expected, s, 16));
            print(" read=");
            print(uitoa(read, s, 16));
            print("\r\n");
            return 0;
        }
    }
    return 1;
}


void main(void)
{
    MEM_WRITE(LED, 0x01);
    if (!test_mem()) {
        // failure
        MEM_WRITE(LED, 0x55);
        for(;;);
    } else {
        // success
        print("Memory OK\r\n");
    }

    if (receive_program())
        start_prog();
}
