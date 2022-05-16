IVERILOG = iverilog

TB_SOURCE = ../sdram_ctrl.v ../sdram_test.sv sdram_ctrl_tb.sv

all: sdram_ctrl_tb.out

clean:
	rm -f *.out *.vcd

sdram_ctrl_tb.out: $(TB_SOURCE)
	$(IVERILOG) -g2012 -o sdram_ctrl_tb.out $(TB_SOURCE)

run: sdram_ctrl_tb.out
	vvp sdram_ctrl_tb.out

.PHONY: all clean run
