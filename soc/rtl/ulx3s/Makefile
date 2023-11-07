YOSYS := $(OSS_CAD_SUITE_PATH)yosys
ECPPACK := $(OSS_CAD_SUITE_PATH)ecppack
NEXTPNR := $(OSS_CAD_SUITE_PATH)nextpnr-ecp5
FUJPROG := $(OSS_CAD_SUITE_PATH)fujprog

# ******* project, board and chip name *******
BOARD = ulx3s
# 12 25 45 85
DEVICE := 85k
PACKAGE := CABGA381

PIN_DEF := ulx3s_v31.lpf
TOP_MODULE = top
TOP_MODULE_FILE = $(TOP_MODULE).sv

SRC = \
  $(TOP_MODULE_FILE) \
  ../../../external/xglib/rtl/bram.sv \
  ../../../external/xglib/rtl/fifo.sv \
	../../../external/xglib/rtl/uart.sv \
	../../../external/xglib/rtl/sdram_ctrl.v \
	../../../external/xglib/rtl/cache_ctrl.v \
	../../../external/xglib/rtl/riscv/alu.sv \
	../../../external/xglib/rtl/riscv/multiplier.v \
	../../../external/xglib/rtl/riscv/divider.v \
	../../../external/xglib/rtl/riscv/decoder.sv \
	../../../external/xglib/rtl/riscv/processor.sv \
	../../../external/xglib/rtl/riscv/register_file.sv \
	../gsoc.sv \
	../sdram.sv \
	../timer_device.sv \
	../led_device.sv \
	../uart_device.sv \
  ../lattice/ecp5pll.sv

#DEFINES = -DFAST_CPU
DEFINES =

all: top.bin

clean:
	rm -f *.hex *.asc *.json *.bin *.log

top.json: $(SRC) prom.mem
	$(YOSYS) -ql top.log -p 'verilog_defines $(DEFINES) ; read_verilog -sv $(SRC); synth_ecp5 -top $(TOP_MODULE) -json top.json -abc9'

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --json top.json --lpf $(PIN_DEF) --textcfg top.asc --randomize-seed

top.bin: top.asc
	$(ECPPACK) --compress --input top.asc --bit top.bin

prog: top.bin
	$(FUJPROG) -T bit top.bin

.PHONY: all prog
