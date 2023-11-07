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
   
    jal ra,main

    lui a0,0
    jalr zero,a0,0
