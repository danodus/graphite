IVERILOG = iverilog

TB_SOURCE = ../async_fifo.sv ../sdram_ctrl.v ../async_sdram_ctrl.sv ../async_sdram_test.sv async_sdram_ctrl_tb.sv

all: async_sdram_ctrl_tb.out

clean:
	rm -f *.out *.vcd

async_sdram_ctrl_tb.out: $(TB_SOURCE)
	$(IVERILOG) -g2012 -o async_sdram_ctrl_tb.out $(TB_SOURCE)

run: async_sdram_ctrl_tb.out
	vvp async_sdram_ctrl_tb.out

.PHONY: all clean run
