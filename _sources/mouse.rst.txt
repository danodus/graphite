Mouse
=====

PS/2 mouse.

Registers
---------

=============== =============
Register        Address
=============== =============
MOUSE_STATUS    BASE_IO + 40
MOUSE_DATA      BASE_IO + 44
=============== =============

MOUSE_STATUS
^^^^^^^^^^^^

Read:

===== ============================
Field Description
===== ============================
[28]  Mouse event available? 
===== ============================

Write: -

MOUSE_DATA
^^^^^^^^^^

Read:

======= ============================
Field   Description
======= ============================
[7:0]   Delta Z
[15:8]  Delta Y
[23:16] Delta X
[24]    Left button pressed?
[25]    Right button pressed?
[26]    Middle button pressed?
======= ============================

Write: -
