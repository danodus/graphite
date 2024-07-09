IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH =
RISCV_TOOLCHAIN_PREFIX = riscv-none-elf-

AS = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}gcc
RISCV_CC_OPT ?= -march=rv32im -mabi=ilp32

LIB_SOURCE = ../lib/io.c ../lib/syscalls.c
PROGRAM_SOURCE = ../lib/start.S program.c ../../../../common/graphite.c ../../../../common/cube.c ../../../../common/teapot.c ../../../../common/tex32x32.c ../../../../common/tex64x64.c
SERIAL ?= /dev/tty.usbserial-D00039

LDFILE ?= ../lib/program.ld

EXTRA_CC_ARGS = -DRV_FIXED_POINT_EXTENSION=0

all: program.hex

clean:
	rm -f *.hex *.elf *.bin *.lst

run: program.hex
	$(PYTHON) ../../../../utils/sendhex.py $(SERIAL) program.hex

program.lst: program.elf
	${OBJDUMP} --disassemble program.elf > program.lst

program.hex: program.bin
	${PYTHON} ../../../../utils/makehex.py program.bin > program.hex

program.bin: program.elf program.lst
	${OBJCOPY} -O binary program.elf program.bin

program.elf: $(PROGRAM_SOURCE) $(LIB_SOURCE)
	${CC} $(RISCV_CC_OPT) -nostartfiles -O3 -T $(LDFILE) -I ../lib -I ../../../../common $(EXTRA_CC_ARGS) $(PROGRAM_SOURCE) $(LIB_SOURCE) -o program.elf -lm

.PHONY: all clean run
