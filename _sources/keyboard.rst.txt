Keyboard
========

PS/2 keyboard.

Registers
---------

=============== =============
Register        Address
=============== =============
KEYBOARD_STATUS BASE_IO + 24
KEYBOARD_DATA   BASE_IO + 28
=============== =============

KEYBOARD_STATUS
^^^^^^^^^^^^^^^

Read:

===== ============================
Field Description
===== ============================
[28]  Key available? 
===== ============================

Write: -

KEYBOARD_DATA
^^^^^^^^^^^^^

Read:

====== ============================
Field  Description
====== ============================
[7:0]  Character
====== ============================

Write: -
