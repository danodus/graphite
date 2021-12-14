IVERILOG = iverilog

EDGE_FUNCTION_TB_SOURCE = ../fpu/adder.sv ../fpu/multiplier.sv ../edge_function.sv edge_function_tb.sv

all: edge_function_tb.out

clean:
	rm *.out *.vcd

edge_function_tb.out: $(EDGE_FUNCTION_TB_SOURCE)
	$(IVERILOG) -g2005-sv  -o edge_function_tb.out $(EDGE_FUNCTION_TB_SOURCE)

run: edge_function_tb.out
	vvp edge_function_tb.out

.PHONY: all clean run
