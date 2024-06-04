Graphite
========

2D/3D accelerator.

After a reset, the frame buffer address is 0x001000000.

Registers
---------

=============== =============
Register        Address
=============== =============
GRAPHITE        BASE_IO + 32
=============== =============

GRAPHITE
^^^^^^^^

Read:

===== ============================
Field Description
===== ============================
[0]   Ready? 
===== ============================

Write:

====== ============================
Field  Description
====== ============================
[31:0] Command
====== ============================


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

================ ===== ===========
Opcode           Value Description
================ ===== ===========
OP_SET_X0        0     Set X0
OP_SET_Y0        1     Set Y0
OP_SET_Z0        2     Set 1/W0
OP_SET_X1        3     Set X1
OP_SET_Y1        4     Set Y1
OP_SET_Z1        5     Set 1/W1
OP_SET_X2        6     Set X2
OP_SET_Y2        7     Set Y2
OP_SET_Z2        8     Set 1/W2
OP_SET_R0        9     Set R0
OP_SET_G0        10    Set G0
OP_SET_B0        11    Set B0
OP_SET_R1        12    Set R1
OP_SET_G1        13    Set G1
OP_SET_B1        14    Set B1
OP_SET_R2        15    Set R2
OP_SET_G2        16    Set G2
OP_SET_B2        17    Set B2
OP_SET_S0        18    Set S0
OP_SET_T0        19    Set T0
OP_SET_S1        20    Set S1
OP_SET_T1        21    Set T1
OP_SET_S2        22    Set S2
OP_SET_T2        23    Set T2
OP_CLEAR         24    Clear frame buffer or depth buffer
OP_DRAW          25    Draw triangle
OP_SWAP          26    Swap the front and back buffer addresses
OP_SET_TEX_ADDR  27    Set texture address
OP_SET_FB_ADDR   28    Set the frame buffer address
================ ===== ===========

OP_SET_*
^^^^^^^^

Set a 18.14 fixed point value for a given parameter.

======= ============================
Field   Description
======= ============================
[0:15]  16-bit value
[16]    0=LSB, 1=MSB
[31:24] Opcode (0..23)
======= ============================


OP_CLEAR
^^^^^^^^

======= ============================
Field   Description
======= ============================
[15:0]  Color (ARGB4444)
[16]    0=frame buffer, 1=depth buffer
[31:24] Opcode (24)
======= ============================

OP_DRAW
^^^^^^^

======= ============================
Field   Description
======= ============================
[0]     0=solid, 1=textured
[1]     0=wrap T, 1=clamp T
[2]     0=wrap S, 1=clamp S
[3]     0=depth test disabled, 1=depth test enabled
[4]     0=perspective correction disabled, 1=perspective correction enabled
[7:5]   Texture width scale (0=32, 1=64, 2=128, 3=256, 4=512, 5=1024, 6=2048, 7=4096)
[10:8]  Texture height scale (0=32, 1=64, 2=128, 3=256, 4=512, 5=1024, 6=2048, 7=4096)
[31:24] Opcode (25)
======= ============================

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
[31:24] Opcode (27)
======= ============================
