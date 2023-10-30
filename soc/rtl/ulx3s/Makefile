# ******* project, board and chip name *******
PROJECT = oberon
BOARD = ulx3s
# 12 25 45 85
FPGA_SIZE = 85

FPGA_PACKAGE = CABGA381

# ******* design files *******
CONSTRAINTS = ulx3s_v31.lpf
TOP_MODULE = ulx3s_v31
TOP_MODULE_FILE = $(TOP_MODULE)_top.v

VERILOG_FILES = \
  $(TOP_MODULE_FILE) \
  ../RISCVTop.OStation.v \
  ../PROM.v \
  ../cache_controller.v \
  ../sdram.v \
  ../PS2.v \
  ../mousem.v \
  ../RS232R.v \
  ../RS232T.v \
  ../SPI.v \
  ../processor.sv \
  ../decoder.sv \
  ../alu.sv \
  ../register_file.sv \
  ../multiplier.v \
  ../divider.v \
  ../VID.OStation.v \
  ../lattice/bram32bit.v \
  ../bram_true2p_2clk.v \
  ../vqueue.v \
  ../lattice/ecp5pll.sv \
  ../dvi/hdmi_interface.v \

# synthesis options
YOSYS_OPTIONS = -abc9
NEXTPNR_OPTIONS = --timing-allow-fail --randomize-seed

include trellis_path.mk
include trellis_main.mk
