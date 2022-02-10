VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "$(shell sdl2-config --cflags) -I ../../../common"

all: sim

clean:
	rm -rf obj_dir

sim: top.sv sim_main.cpp ../../common/graphite.c ../../common/graphite.h ../../common/cube.c ../../common/cube.h ../../common/teapot.c ../../common/teapot.h
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) top.sv sim_main.cpp ../../common/graphite.c ../../common/cube.c ../../common/teapot.c -I.. -I../fpu
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	obj_dir/Vtop

.PHONY: all clean
