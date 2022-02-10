IVERILOG = iverilog

EDGE_FUNCTION_TB_SOURCE = \
	../fpu/adder.sv \
	../fpu/divider.sv \
	../fpu/float_to_int.sv \
	../fpu/int_to_float.sv \
	../fpu/multiplier.sv \
	../fpu.sv \
	../edge_function.sv \
	edge_function_tb.sv

all: edge_function_tb.out

clean:
	rm -f *.out *.vcd

edge_function_tb.out: $(EDGE_FUNCTION_TB_SOURCE)
	$(IVERILOG) -g2005-sv  -I .. -o edge_function_tb.out $(EDGE_FUNCTION_TB_SOURCE)

run: edge_function_tb.out
	vvp edge_function_tb.out

.PHONY: all clean run
