IVERILOG = iverilog

TB_SOURCE = ../async_fifo.sv ../sdram_ctrl.v ../async_sdram_ctrl.sv ../framebuffer.sv ../display_timings_480p.sv ../test_pattern.sv top_tb.sv

all: top_tb.out

clean:
	rm -f *.out *.vcd

top_tb.out: $(TB_SOURCE)
	$(IVERILOG) -g2012 -o top_tb.out $(TB_SOURCE)

run: top_tb.out
	vvp top_tb.out

.PHONY: all clean run
