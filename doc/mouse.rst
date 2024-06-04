Mouse
=====

PS/2 mouse.

Registers
---------

=============== =============
Register        Address
=============== =============
MOUSE           BASE_IO + 24
=============== =============

MOUSE
^^^^^

Read:

======= ============================
Field   Description
======= ============================
[9:0]   X position
[21:12] Y position
[24]    Left button
[25]    Middle button
[26]    Right button
======= ============================

Write: -
