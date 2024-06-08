YOSYS := $(OSS_CAD_SUITE_PATH)yosys
ECPPACK := $(OSS_CAD_SUITE_PATH)ecppack
NEXTPNR := $(OSS_CAD_SUITE_PATH)nextpnr-ecp5
OPENFPGALOADER := $(OSS_CAD_SUITE_PATH)openFPGALoader

# ******* project, board and chip name *******
BOARD = ulx3s
# 12 25 45 85
DEVICE := um-85k
PACKAGE := CABGA381
SPEED := 7

PIN_DEF := mmm.lpf
TOP_MODULE = mmm_top
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
  ../fifo.sv \
  ../spi.v \
  ../riscv/processor.sv \
  ../riscv/bus_arbiter.sv \
  ../riscv/rv32.sv \
  ../video.v \
  ../rgb565_to_rgb888.sv \
  ../lattice/bram32bit.v \
  ../bram_true2p_2clk.v \
  ../vqueue.v \
  ../lattice/ecp5pll.sv \
  ../dvi/hdmi_interface.v \
  ../../../rtl/graphite.sv \
  ../../../rtl/reciprocal.sv \
  ../../../rtl/div.sv

DEFINES =

ifeq ($(VIDEO),480p)
DEFINES += -DVIDEO_480P
endif

ifeq ($(VIDEO),720p)
DEFINES += -DVIDEO_720P
endif

ifeq ($(VIDEO),1080p)
DEFINES += -DVIDEO_1080P
endif

ifeq ($(CPU_SPEED),fast)
DEFINES += -DFAST_CPU
endif

all: bios top.bin

clean:
	rm -f *.hex *.asc *.json *.bin *.log

bios:
	make -C ../../src/bios  

top.json: $(SRC)
	$(YOSYS) -ql top.log -p 'verilog_defines $(DEFINES) ; read_verilog -sv $(SRC); synth_ecp5 -top $(TOP_MODULE) -json top.json -abc9'

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --speed $(SPEED) --json top.json --lpf $(PIN_DEF) --textcfg top.asc --randomize-seed --timing-allow-fail

top.bin: top.asc
	$(ECPPACK) --compress --input top.asc --bit top.bin

prog: top.bin
	$(OPENFPGALOADER) --cable ft4232 top.bin

.PHONY: all prog bios
