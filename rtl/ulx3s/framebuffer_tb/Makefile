IVERILOG = iverilog

TB_SOURCE = ../async_fifo.sv ../sdram_ctrl.v ../async_sdram_ctrl.sv ../framebuffer.sv framebuffer_tb.sv

all: framebuffer_tb.out

clean:
	rm -f *.out *.vcd

framebuffer_tb.out: $(TB_SOURCE)
	$(IVERILOG) -g2012 -o framebuffer_tb.out $(TB_SOURCE)

run: framebuffer_tb.out
	vvp framebuffer_tb.out

.PHONY: all clean run
