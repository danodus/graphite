PROGRAM = ../../src/examples/test_video/program.hex

VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "-std=c++14 $(shell sdl2-config --cflags)"

SRC = bram32bit.v \
	prom.v \
	uart_tx.v \
	uart_rx.v \
	fifo.sv \
	bram_true2p_2clk.v \
	ps2kbd.v \
	ps2mouse.v \
	spi.v \
	cache_controller.v \
	sdram.v \
	soc_top.sv \
	video.v \
	vqueue.v \
	riscv/bus_arbiter.sv \
	riscv/processor.sv \
	riscv/rv32.sv \
	graphite.sv \
	reciprocal.sv \
	div.sv

all: sim

clean:
	rm -rf obj_dir

sim: top.sv sim_main.cpp $(PROGRAM)
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) --trace --top-module top $(XOSERA_SRC) top.sv sdl_ps2.cpp sim_main.cpp -I.. -I../riscv -I../../../rtl $(SRC) -Wno-PINMISSING -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-TIMESCALEMOD -Wno-NULLPORT -Wno-MULTIDRIVEN -Wno-UNOPTFLAT
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	cp $(PROGRAM) .
	obj_dir/Vtop

.PHONY: all clean
