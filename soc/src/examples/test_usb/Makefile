PYTHON = python3

RISCV_TOOLCHAIN_PATH =
RISCV_TOOLCHAIN_PREFIX = riscv-none-elf-

AS = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}gcc
RISCV_CC_OPT ?= -march=rv32i -mabi=ilp32

USB_SOURCE = ../lib/usb/enum.c ../lib/usb/hid.c ../lib/usb/hub.c ../lib/usb/prn.c ../lib/usb/req.c
PROGRAM_SOURCE = start.S program.c ../lib/syscalls.c ../lib/io.c $(USB_SOURCE)
SERIAL ?= /dev/tty.usbserial-D00039

LDFILE ?= program.ld

all: program.hex

clean:
	rm -f *.hex *.elf *.bin *.lst

run: program.hex
	$(PYTHON) ../../../../utils/sendhex.py $(SERIAL) program.hex

program.lst: program.elf
	${OBJDUMP} --disassemble program.elf > program.lst

program.hex: program.bin
	hexdump -v -e '1/4 "%08x\n"' program.bin > program.hex

program.bin: program.elf program.lst
	${OBJCOPY} -O binary program.elf program.bin

program.elf: $(PROGRAM_SOURCE) $(EXTRA_SOURCE)
	${CC} $(RISCV_CC_OPT) -nostartfiles -O3 -T $(LDFILE) -I ../lib -I ../lib/usb $(PROGRAM_SOURCE) -o program.elf -lm

.PHONY: all clean run
