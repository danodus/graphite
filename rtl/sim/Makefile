VERILATOR = verilator
VERILATOR_ROOT = `$(VERILATOR) --getenv VERILATOR_ROOT`

SRC := ../../common/graphite.c ../../common/cube.c ../../common/teapot.c ../../common/tex32x32.c ../../common/tex64x64.c ../../common/tex32x64.c ../../common/tex256x2048.c

all: demo tutorial01 tutorial02

clean:
	rm -rf obj_dir
	rm -f demo tutorial01 tutorial02

sim: top.sv
	$(VERILATOR) -O3 -cc -CFLAGS "-std=c++14" top.sv -I..
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

demo: sim demo.cpp $(SRC) ../../common/graphite.h ../../common/cube.h ../../common/teapot.h
	g++ -std=c++14 $(shell sdl2-config --cflags) -I $(VERILATOR_ROOT)/include -I obj_dir -I ../../common -DFIXED_POINT=1 $(shell sdl2-config --libs) -L obj_dir -l verilated -l Vtop demo.cpp $(SRC) -o demo

tutorial01: sim gr.cpp gr.h tutorial01.cpp
	g++ -std=c++14 $(shell sdl2-config --cflags) -I $(VERILATOR_ROOT)/include -I obj_dir $(shell sdl2-config --libs) -L obj_dir -l verilated -l Vtop tutorial01.cpp gr.cpp -o tutorial01

tutorial02: sim gr.cpp gr.h math.h tutorial02.cpp
	g++ -std=c++14 $(shell sdl2-config --cflags) -I $(VERILATOR_ROOT)/include -I obj_dir $(shell sdl2-config --libs) -L obj_dir -l verilated -l Vtop tutorial02.cpp gr.cpp -o tutorial02

run: demo
	./demo $(SERIAL)

.PHONY: all sim_core sim clean
