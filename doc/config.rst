Configuration
=============

System configuration.

Registers
---------

=============== =============
Register        Address
=============== =============
CONFIG          BASE_IO + 36
FB_ADDR         BASE_IO + 40
VSYNC           BASE_IO + 44
=============== =============

CONFIG
^^^^^^

Read:

======= ============================
Field   Description
======= ============================
[15:0]  Vertical video resolution
[31:16] Horizontal video resolution
======= ============================

Write:

======= ============================
Field   Description
======= ============================
[0]     0=no action, 1=flush cache
======= ============================


FB_ADDR
^^^^^^^

Read:

======= ============================
Field   Description
======= ============================
[31:0]  Frame buffer address
======= ============================

Write:

======= ============================
Field   Description
======= ============================
[31:0]  Frame buffer address
======= ============================

VSYNC
^^^^^

Read:

======= ============================
Field   Description
======= ============================
[0]     VSYNC?
======= ============================

Write: -
