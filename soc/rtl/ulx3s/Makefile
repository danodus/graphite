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
TOP_MODULE = ulx3s_v31_top
TOP_MODULE_FILE = $(TOP_MODULE).sv

SRC = \
  $(TOP_MODULE_FILE) \
  ../soc_top.sv \
  ../prom.v \
  ../cache_controller.v \
  ../sdram.v \
  ../ps2kbd.v \
  ../ps2mouse.v \
  ../uart_rx.v \
  ../uart_tx.v \
  ../spi.v \
  ../riscv/processor.sv \
  ../riscv/decoder.sv \
  ../riscv/alu.sv \
  ../riscv/register_file.sv \
  ../riscv/multiplier.v \
  ../riscv/divider.v \
  ../video.v \
  ../lattice/bram32bit.v \
  ../bram_true2p_2clk.v \
  ../vqueue.v \
  ../lattice/ecp5pll.sv \
  ../dvi/hdmi_interface.v \
  ../../../rtl/graphite.sv \
  ../../../rtl/reciprocal.sv \
  ../../../rtl/div.sv

DEFINES = -DFAST_CPU

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
