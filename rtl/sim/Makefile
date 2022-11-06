VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell pkg-config sdl2 --libs)"
CFLAGS := -CFLAGS "$(shell pkg-config sdl2 --cflags) -g -I ../../../src -DFIXED_POINT=1"

all: sim

clean:
	rm -rf obj_dir
	rm -f *.hex

sim: top.sv sim_main.cpp ../../src/fx.h ../../src/glide.c ../../src/draw.c ../../src/draw.h ../../src/cube.c ../../src/cube.h ../../src/teapot.c ../../src/teapot.h
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) top.sv sim_main.cpp ../../src/glide.c ../../src/draw.c ../../src/cube.c ../../src/teapot.c -I..
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	cp ../*.hex .
	obj_dir/Vtop $(SERIAL)

.PHONY: all clean
