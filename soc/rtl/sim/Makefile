PROGRAM = ../../src/examples/test_video/program.hex

VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "$(shell sdl2-config --cflags)"

SRC = bram.sv \
	fifo.sv \
	uart.sv \
	sdram_ctrl.v \
	cache_ctrl.v \
	riscv/alu.sv \
	riscv/multiplier.v \
	riscv/divider.v \
	riscv/decoder.sv \
	riscv/processor.sv \
	riscv/register_file.sv \
	gsoc.sv \
	sdram.sv \
	timer_device.sv \
	led_device.sv \
	uart_device.sv

all: sim

clean:
	rm -rf obj_dir

sim: top.sv sim_main.cpp $(PROGRAM)
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) --trace --top-module top $(XOSERA_SRC) top.sv sdl_ps2.cpp sim_main.cpp -I.. -I../../../external/xglib/rtl $(SRC) -Wno-PINMISSING -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-TIMESCALEMOD -Wno-NULLPORT -Wno-MULTIDRIVEN -Wno-UNOPTFLAT
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	cp $(PROGRAM) .
	obj_dir/Vtop

.PHONY: all clean
