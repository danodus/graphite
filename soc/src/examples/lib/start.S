    .section .init
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

    lui sp, %hi(__stacktop)
    addi sp, sp, %lo(__stacktop)

    # zero-init bss section
    la a0, _sbss
    la a1, _ebss
    bge a0, a1, end_init_bss
loop_init_bss:
    sw zero, 0(a0)
    addi a0, a0, 4
    blt a0, a1, loop_init_bss
end_init_bss:    
    
    jal ra,main

    li a0,0xF0000000
    jalr zero,a0,0
