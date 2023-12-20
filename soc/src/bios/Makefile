IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH =
RISCV_TOOLCHAIN_PREFIX = riscv64-unknown-elf-

AS = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}gcc
RISCV_CC_OPT ?= -march=rv32im -mabi=ilp32

PROGRAM_SOURCE = start.S program.c
CC_OPT = -DFAST_CPU=0

SERIAL ?= /dev/tty.usbserial-ibNy7k1v1

LDFILE ?= program.ld

all: prom.mem

$(SITE_MK):
	$(info Copy the example site.template file to site.mk and edit the paths.)
	$(error site.mk not found.)

clean:
	rm -f *.mem *.elf *.bin *.lst

program.lst: program.elf
	${OBJDUMP} --disassemble program.elf > program.lst

prom.mem: program.bin
	hexdump -v -e '1/4 "%08x\n"' program.bin > prom.mem

program.bin: program.elf program.lst
	${OBJCOPY} -O binary program.elf program.bin

program.elf: $(PROGRAM_SOURCE) $(EXTRA_SOURCE)
	${CC} $(RISCV_CC_OPT) -nostartfiles -O3 -T $(LDFILE) -I ../../lib -I ../common $(CC_OPT) $(PROGRAM_SOURCE) -o program.elf -lm

.PHONY: all clean
