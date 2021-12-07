VERILATOR = verilator

all: sim

clean:
	rm -rf obj_dir

sim:
	$(VERILATOR) -cc --exe top.sv sim_main.cpp -I../fpu
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	obj_dir/Vtop

.PHONY: all clean
