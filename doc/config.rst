Configuration
=============

System configuration.

Registers
---------

=============== =============
Register        Address
=============== =============
CONFIG          BASE_IO + 36
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

Write: -
