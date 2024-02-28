IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH =
RISCV_TOOLCHAIN_PREFIX = riscv64-unknown-elf-

AS = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}gcc
RISCV_CC_OPT ?= -march=rv32i -mabi=ilp32

FAT32_SOURCE = ../lib/fat/fat_access.c ../lib/fat/fat_cache.c ../lib/fat/fat_filelib.c ../lib/fat/fat_format.c ../lib/fat/fat_misc.c ../lib/fat/fat_string.c ../lib/fat/fat_table.c ../lib/fat/fat_write.c
LIB_SOURCE = ../lib/io.c ../lib/syscalls.c ../lib/SDL2/sdl.c ../lib/sd_card.c $(FAT32_SOURCE) ../lib/libfixmath/*.c
PROGRAM_SOURCE = src/start.S src/*.c
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
	${PYTHON} ../../../../utils/makehex.py program.bin > program.hex

program.bin: program.elf program.lst
	${OBJCOPY} -O binary program.elf program.bin

program.elf: $(PROGRAM_SOURCE) $(LIB_SOURCE)
	${CC} $(RISCV_CC_OPT) -std=c99 -nostartfiles -g -O3 -T $(LDFILE) -I ../lib -I ../lib/SDL2 -I ../lib/fat $(PROGRAM_SOURCE) $(LIB_SOURCE) -o program.elf -lm

.PHONY: all clean run
