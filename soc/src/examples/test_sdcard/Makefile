IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH =
RISCV_TOOLCHAIN_PREFIX = riscv-none-elf-

AS = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}gcc
RISCV_CC_OPT ?= -march=rv32im -mabi=ilp32

FAT32_SOURCE = ../lib/fat/fat_access.c ../lib/fat/fat_cache.c ../lib/fat/fat_filelib.c ../lib/fat/fat_format.c ../lib/fat/fat_misc.c ../lib/fat/fat_string.c ../lib/fat/fat_table.c ../lib/fat/fat_write.c
PROGRAM_SOURCE = ../lib/start.S program.c ../lib/syscalls.c ../lib/io.c ../lib/sd_card.c $(FAT32_SOURCE)
SERIAL ?= /dev/tty.usbserial-D00039

LDFILE ?= ../lib/program.ld

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

program.elf: $(PROGRAM_SOURCE) $(EXTRA_SOURCE)
	${CC} $(RISCV_CC_OPT) -nostartfiles -O3 -T $(LDFILE) -D FATFS_INC_TIME_DATE_SUPPORT=1 -I ../lib -I ../lib/fat $(PROGRAM_SOURCE) -o program.elf -lm

.PHONY: all clean run
