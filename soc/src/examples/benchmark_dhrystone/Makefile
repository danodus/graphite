IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH =
RISCV_TOOLCHAIN_PREFIX = riscv64-unknown-elf-

AS = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}gcc
RISCV_CC_OPT ?= -march=rv32im -mabi=ilp32

LIB_SOURCE = ../lib/io.c ../lib/syscalls.c
PROGRAM_SOURCE = start.S *.c
SERIAL ?= /dev/tty.usbserial-D00039

LDFILE ?= program.ld

all: program.hex

clean:
	rm -f *.hex *.elf *.bin *.lst

run: program.hex
	$(PYTHON) ../../../../utils/sendhex.py $(SERIAL) program.hex

program.lst: program.elf
	${OBJDUMP} --source program.elf > program.lst

program.hex: program.bin
	hexdump -v -e '1/4 "%08x\n"' program.bin > program.hex

program.bin: program.elf program.lst
	${OBJCOPY} -O binary program.elf program.bin

program.elf: $(PROGRAM_SOURCE) $(LIB_SOURCE)
	${CC} $(RISCV_CC_OPT) -Wall -Wno-switch -std=c99 -nostartfiles -O3 -T $(LDFILE) -I ../lib $(PROGRAM_SOURCE) $(LIB_SOURCE) -o program.elf -lm

.PHONY: all clean run