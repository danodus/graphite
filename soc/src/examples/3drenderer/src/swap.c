#include "swap.h"

void int_swap(int* a, int* b) {
    int tmp = *a;
    *a = *b;
    *b = tmp;
}

void fix16_swap(fix16_t* a, fix16_t* b) {
    fix16_t tmp = *a;
    *a = *b;
    *b = tmp;
}