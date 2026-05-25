VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "-std=c++14 $(shell sdl2-config --cflags) -g -I ../../../common -DFIXED_POINT=1"

SRC := ../../common/graphite.c ../../common/cube.c ../../common/teapot.c ../../common/tex32x32.c ../../common/tex64x64.c ../../common/tex32x64.c ../../common/tex256x2048.c

all: sim

clean:
	rm -rf obj_dir
	rm -f golden_capture.tga

RTL := top.sv ../graphite.sv ../graphite_command_processor.sv ../graphite_rasterizer.sv \
       ../graphite_fragment_shader.sv ../reciprocal.sv ../div.sv

sim: $(RTL) sim_main.cpp $(SRC) ../../common/graphite.h ../../common/cube.h ../../common/teapot.h
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) $(RTL) sim_main.cpp $(SRC) -I..
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	obj_dir/Vtop $(SERIAL)

# Pixel regression: capture framebuffer to a temp TGA and require a byte-identical
# match with the golden reference (default: out.tga in this directory).
GOLDEN_TGA ?= out.tga
CAPTURE_TGA ?= golden_capture.tga

golden: sim
	obj_dir/Vtop --write-tga $(CAPTURE_TGA) --golden-tga $(GOLDEN_TGA) && rm -f $(CAPTURE_TGA)

.PHONY: all clean golden
