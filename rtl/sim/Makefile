VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "-std=c++14 $(shell sdl2-config --cflags) -g -I ../../../common -DFIXED_POINT=1"

all: sim

clean:
	rm -rf obj_dir

sim: top.sv sim_main.cpp ../../common/graphite.c ../../common/graphite.h ../../common/cube.c ../../common/cube.h ../../common/teapot.c ../../common/teapot.h ../../common/tex32x32.c ../../common/tex64x64.c
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) top.sv sim_main.cpp ../../common/graphite.c ../../common/cube.c ../../common/teapot.c ../../common/tex32x32.c ../../common/tex64x64.c -I..
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	obj_dir/Vtop $(SERIAL)

.PHONY: all clean
