PROGRAM = ../../src/examples/test_video/program.hex

VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "$(shell sdl2-config --cflags)"

SRC = RS232R.v \
	bram32bit.v \
	mousem.v \
	PROM.v \
	RS232T.v \
	bram_true2p_2clk.v \
	PS2.v SPI.v cache_controller.v \
	sdram.v \
	soc_top.sv \
	VID.v \
	vqueue.v \
	riscv/alu.sv \
	riscv/multiplier.v \
	riscv/divider.v \
	riscv/decoder.sv \
	riscv/processor.sv \
	riscv/register_file.sv	

all: sim

clean:
	rm -rf obj_dir

sim: top.sv sim_main.cpp $(PROGRAM)
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) --trace --top-module top $(XOSERA_SRC) top.sv sdl_ps2.cpp sim_main.cpp -I.. $(SRC) -Wno-PINMISSING -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-TIMESCALEMOD -Wno-NULLPORT -Wno-MULTIDRIVEN -Wno-UNOPTFLAT
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	cp $(PROGRAM) .
	obj_dir/Vtop

.PHONY: all clean
