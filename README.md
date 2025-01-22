# Graphite

Graphite is a FPGA based open source 2D/3D graphics accelerator.
See the following project for an integration example: https://github.com/danodus/xgsoc

![Utah Teapot](doc/teapot.gif)

## Documentation

The documentation is available here: https://danodus.github.io/graphite/

## Features

- Draw textured triangle.

## Requirements

- OSS CAD Suite (https://github.com/YosysHQ/oss-cad-suite-build) (*)
- SDL2

(*) Extract and add the `bin` directory to the path.

Note: Tested with `oss-cad-suite-darwin-arm64-20240810`.

## Simulation

```bash
cd rtl/sim
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
