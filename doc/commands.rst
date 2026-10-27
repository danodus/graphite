Commands
========

Command Format
--------------

======= ============================
Field   Description
======= ============================
[31:24] Opcode
[23:0]  Parameter
======= ============================

Opcodes
-------

================== ===== ==================================================
Opcode             Value Description
================== ===== ==================================================
OP_SET_V0_X        0     Set V0_X
OP_SET_V0_Y        1     Set V0_Y
OP_SET_V1_X        2     Set V1_X
OP_SET_V1_Y        3     Set V1_Y
OP_SET_V2_X        4     Set V2_X
OP_SET_V2_Y        5     Set V2_Y
OP_SET_START_W_INV 6     Set START_W_INV
OP_SET_START_S     7     Set START_S
OP_SET_START_T     8     Set START_T
OP_SET_START_R     9     Set START_R
OP_SET_START_G     10    Set START_G
OP_SET_START_B     11    Set START_B
OP_SET_DW_DX       12    Set DW_DX
OP_SET_DW_DY       13    Set DW_DY
OP_SET_DS_DX       14    Set DS_DX
OP_SET_DS_DY       15    Set DS_DY
OP_SET_DT_DX       16    Set DT_DX
OP_SET_DT_DY       17    Set DT_DY
OP_SET_DR_DX       18    Set DR_DX
OP_SET_DR_DY       19    Set DR_DY
OP_SET_DG_DX       20    Set DG_DX
OP_SET_DG_DY       21    Set DG_DY
OP_SET_DB_DX       22    Set DB_DX
OP_SET_DB_DY       23    Set DB_DY
OP_CLEAR           24    Clear frame buffer or depth buffer
OP_DRAW            25    Draw triangle
OP_SWAP            26    Swap the front and back buffer addresses
OP_SET_TEX_ADDR    27    Set texture address (in 16-bit word, address >> 1)
OP_SET_FB_ADDR     28    Set the frame buffer address (in 16-bit word, address >> 1)
OP_SET_START_SU    29    Set START_SU (shadow map U)
OP_SET_START_SV    30    Set START_SV (shadow map V)
OP_SET_START_SZ    31    Set START_SZ (shadow depth)
OP_SET_DSU_DX      32    Set DSU_DX
OP_SET_DSU_DY      33    Set DSU_DY
OP_SET_DSV_DX      34    Set DSV_DX
OP_SET_DSV_DY      35    Set DSV_DY
OP_SET_DSZ_DX      36    Set DSZ_DX
OP_SET_DSZ_DY      37    Set DSZ_DY
OP_SET_VIEWPORT    38    Set the raster viewport width and height
OP_SET_ZB_ADDR     39    Set the depth buffer address (in 16-bit word, address >> 1)
OP_SET_SHADOW      40    Set the shadow map address (in 16-bit word, address >> 1)
OP_SET_SHADOW_PARAM 41   Set the shadow map scale and depth bias
================== ===== ==================================================

OP_SET_*
^^^^^^^^

Set a fixed point value for a given parameter. Values are 32-bit and passed in two 16-bit chunks, except for V0..V2 coordinates which are sent as a single 16-bit chunk.

======= ============================
Field   Description
======= ============================
[0:15]  16-bit value
[16]    0=LSB, 1=MSB (ignored for 16-bit coordinates)
[31:24] Opcode (0..23)
======= ============================

Parameter Formats:
- V0_X, V0_Y, V1_X, V1_Y, V2_X, V2_Y: 12.4 fixed point format (16-bit)
- START_W_INV, DW_DX, DW_DY: 4.28 fixed point format (32-bit)
- START_S, START_T, DS_DX, DS_DY, DT_DX, DT_DY: 14.18 fixed point format (32-bit)
- START_R, START_G, START_B, DR_DX, DR_DY, DG_DX, DG_DY, DB_DX, DB_DY: 12.20 fixed point format (32-bit)
- START_SU, START_SV, DSU_DX, DSU_DY, DSV_DX, DSV_DY: 14.18 fixed point format (32-bit)
- START_SZ, DSZ_DX, DSZ_DY: 12.20 fixed point format (32-bit)


OP_CLEAR
^^^^^^^^

======= ============================
Field   Description
======= ============================
[15:0]  Color (RGB565)
[16]    0=frame buffer, 1=depth buffer
[31:24] Opcode (24)
======= ============================

OP_DRAW
^^^^^^^

======= ============================
Field   Description
======= ============================
[0]     0=not textured, 1=textured
[1]     0=wrap T, 1=clamp T
[2]     0=wrap S, 1=clamp S
[3]     0=depth test disabled, 1=depth test enabled
[4]     0=perspective correction disabled, 1=perspective correction enabled
[5]     0=positive area, 1=negative area (winding sign bit)
[8:6]   Texture width scale (0=32, 1=64, 2=128, 3=256, 4=512, 5=1024, 6=2048, 7=4096)
[11:9]  Texture height scale (0=32, 1=64, 2=128, 3=256, 4=512, 5=1024, 6=2048, 7=4096)
[12]    0=shade, 1=depth only (no texture fetch, no color write; depth is interpolated SZ)
[13]    0=shadow compare off, 1=sample the shadow map and darken occluded pixels
[22]    0=truncate to RGB565, 1=4x4 Bayer dither before the RGB565 quantize
[31:24] Opcode (25)
======= ============================

OP_SET_VIEWPORT
^^^^^^^^^^^^^^^

======= ============================
Field   Description
======= ============================
[11:0]  Viewport width in pixels
[23:12] Viewport height in pixels
[31:24] Opcode (38)
======= ============================

Depth clears cover ``width * height`` samples at the current depth address. The rasterizer clips and addresses using this viewport. A power-of-two size (the shadow map) or the framebuffer size configured at elaboration are the supported dimensions.

OP_SET_ZB_ADDR
^^^^^^^^^^^^^^

Absolute depth-buffer address in 16-bit words. Same two-beat encoding as OP_SET_TEX_ADDR.

OP_SET_SHADOW
^^^^^^^^^^^^^

Absolute shadow-map address in 16-bit words. Same two-beat encoding as OP_SET_TEX_ADDR. Samples are raw 16-bit depth, not RGB4444.

OP_SET_SHADOW_PARAM
^^^^^^^^^^^^^^^^^^^

======= ============================
Field   Description
======= ============================
[2:0]   Shadow map width scale (0=32 .. 7=4096), same encoding as texture scale
[5:3]   Shadow map height scale
[21:6]  Constant depth bias added to interpolated SZ before the compare
[31:24] Opcode (41)
======= ============================

A pixel is darkened by half when it is inside the map, the fetched depth is below 20000, and ``SZ + bias`` is greater than the fetched depth. Coordinates outside the map stay lit.

OP_SWAP
^^^^^^^

======= ============================
Field   Description
======= ============================
[0]     0=do not wait for vsync, 1=wait for vsync
[31:24] Opcode (26)
======= ============================


OP_SET_TEX_ADDR
^^^^^^^^^^^^^^^

======= ============================
Field   Description
======= ============================
[0:15]  16-bit value
[16]    0=LSB, 1=MSB
[31:24] Opcode (27)
======= ============================

OP_SET_FB_ADDR
^^^^^^^^^^^^^^^

======= ============================
Field   Description
======= ============================
[0:15]  16-bit value
[16]    0=LSB, 1=MSB
[17]    0=double buffer (back != front), 1=single buffer (back == front)
[31:24] Opcode (28)
======= ============================
