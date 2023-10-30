    .section .text
    .global _start

_start:
    j start

.balign 16
irq0_vec:
    j irq0

irq1_vec:
    j irq1

ecall_vec:
    j ecall

ebreak_vec:
    j ebreak

irq0:
    mret

irq1:
    mret

ecall:
    sret

ebreak:
    sret

start:
    add x1,x0,x0
    add x2,x0,x0
    add x3,x0,x0
    add x4,x0,x0
    add x5,x0,x0
    add x6,x0,x0
    add x7,x0,x0
    add x8,x0,x0
    add x9,x0,x0
    add x10,x0,x0
    add x11,x0,x0
    add x12,x0,x0
    add x13,x0,x0
    add x14,x0,x0
    add x15,x0,x0
    
    jal ra,main

    lui a0,0
    jalr zero,a0,0
