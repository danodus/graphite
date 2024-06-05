Memory Map
==========

======================== ==============
Address Range            Description
======================== ==============
0x00000000 - 0x002000000 SDRAM (32 MiB)
0xE0000000 - 0xE000000FF Devices
0xF0000000 - 0xF000007FF ROM (2 KiB)
======================== ==============

BASE_IO: 0xE0000000

==================  ===============
Device              Address
==================  ===============
CLOCK               BASE_IO + 0
LED                 BASE_IO + 4
UART                BASE_IO + 8
SD_CARD             BASE_IO + 16
KEYBOARD            BASE_IO + 24
GRAPHITE            BASE_IO + 32
CONFIG              BASE_IO + 36
MOUSE               BASE_IO + 40
==================  ===============
