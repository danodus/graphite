IVERILOG = iverilog

TB_SOURCE = ../async_fifo.sv async_fifo_tb.sv

all: async_fifo_tb.out

clean:
	rm -f *.out *.vcd

async_fifo_tb.out: $(TB_SOURCE)
	$(IVERILOG) -g2012 -o async_fifo_tb.out $(TB_SOURCE)

run: async_fifo_tb.out
	vvp async_fifo_tb.out

.PHONY: all clean run
