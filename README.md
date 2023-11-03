# Graphite

Graphite is a FPGA based open source 3D graphics accelerator.

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
- Press L to enable/disable lighting.

## System on Chip

Note: The integration of the Graphite core module is not yet available.

A SoC for the ULX3S is also available with the following features:
- RISC-V (RV32IM)
- UART (115200-N-8-1)
- SDRAM (32MiB shared between CPU and video)
- Set associative cache (2-way with LRU replacement policy)
- 640x480 HDMI video output with framebuffer (ARGB4444)
- PS/2 keyboard
- PS/2 mouse
- SD Card with hardware SPI

```bash
cd soc/src/bios
make
cd ../../rtl/ulx3s
make prog
cd ../../src/examples/test_video
make run SERIAL=<serial device>
```

## References

The SoC is based on the Oberon project for the ULX3S available here: https://github.com/emard/oberon.

