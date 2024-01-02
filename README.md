# Graphite

Graphite is a FPGA based open source 2D/3D graphics accelerator.

![Utah Teapot](doc/teapot.png)

## Features

- Draw line;
- Draw textured triangle.

## Requirements

- SDL2
- Verilator 4.213 or above

## Getting Started
```bash
git clone https://github.com/danodus/graphite.git
cd graphite/rtl/sim
make run
```

- Press 1 to select the cube model;
- Press 2 to select the teapot model;
- Press W/A/S/D and arrows to move the camera;
- Press SPACE to start/stop the rotation of the model;
- Press TAB to enable/disable the wireframe mode;
- Press T to enable/disable texture mapping;
- Press L to increase the number of directional lights;
- Press G to enable/disable Gouraud shading.

## System on Chip

A SoC for the ULX3S is also available with the following features:
- RISC-V (RV32I + Graphite extension)
- UART (115200/230400-N-8-1)
- SDRAM (32MiB shared between CPU and video)
- Set associative cache (4-way with LRU replacement policy)
- 640x480 HDMI video output with framebuffer (ARGB4444)
- Graphite 2D/3D graphics accelerator
- PS/2 keyboard
- PS/2 mouse
- SD Card with hardware SPI

```bash
cd soc/src/bios
make
cd ../../rtl/ulx3s
make prog
cd ../../src/examples/test_graphite
make run SERIAL=<serial device>
```

Open a serial terminal at 230400 bauds and press 'h' for help.

## References

The SoC is based on the Oberon project for the ULX3S available here: https://github.com/emard/oberon.

