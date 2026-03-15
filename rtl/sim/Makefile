VERILATOR = verilator
VERILATOR_ROOT = `$(VERILATOR) --getenv VERILATOR_ROOT`

SRC := ../../common/graphite.c ../../common/cube.c ../../common/teapot.c ../../common/tex32x32.c ../../common/tex64x64.c ../../common/tex32x64.c ../../common/tex256x2048.c

all: demo tutorial01 tutorial02 tutorial03

clean:
	rm -rf obj_dir
	rm -f demo tutorial01 tutorial02

obj_dir/libVtop.a: top.sv
	$(VERILATOR) -O3 -cc -CFLAGS "-std=c++14" top.sv -I..
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

demo: obj_dir/libVtop.a demo.cpp $(SRC) ../../common/graphite.h ../../common/cube.h ../../common/teapot.h
	g++ -std=c++14 $(shell sdl2-config --cflags) -I $(VERILATOR_ROOT)/include -I obj_dir -I ../../common -DFIXED_POINT=1 -L obj_dir demo.cpp $(SRC) $(shell sdl2-config --libs) -l verilated -l Vtop -o demo

tutorial01: obj_dir/libVtop.a gr.cpp gr.h tutorial01.cpp
	g++ -std=c++14 $(shell sdl2-config --cflags) -I $(VERILATOR_ROOT)/include -I obj_dir -L obj_dir tutorial01.cpp gr.cpp $(shell sdl2-config --libs) -l verilated -l Vtop -o tutorial01

tutorial02: obj_dir/libVtop.a gr.cpp gr.h math.h tutorial02.cpp
	g++ -std=c++14 $(shell sdl2-config --cflags) -I $(VERILATOR_ROOT)/include -I obj_dir -L obj_dir tutorial02.cpp gr.cpp $(shell sdl2-config --libs) -l verilated -l Vtop -o tutorial02

tutorial03: obj_dir/libVtop.a gr.cpp gr.h math.h tutorial03.cpp
	g++ -std=c++14 $(shell sdl2-config --cflags) -I $(VERILATOR_ROOT)/include -I obj_dir -L obj_dir tutorial03.cpp gr.cpp $(shell sdl2-config --libs) -l verilated -l Vtop -o tutorial03

run: demo
	./demo $(SERIAL)

.PHONY: all clean
