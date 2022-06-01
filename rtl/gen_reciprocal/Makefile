IVERILOG = iverilog
TB_SOURCE = gen_reciprocal.sv

all: gen_reciprocal.out

clean:
	rm -f *.out

gen_reciprocal.out: $(TB_SOURCE)
	$(IVERILOG) -g2012 -o gen_reciprocal.out $(TB_SOURCE)

run: gen_reciprocal.out
	vvp gen_reciprocal.out

.PHONY: all clean run
