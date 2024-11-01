UART
====

Serial port read/write with FIFO.  The character must be dequeued manually before reading.

Registers
---------

=========== =============
Register    Address
=========== =============
UART_DATA   BASE_IO + 8
UART_STATUS BASE_IO + 12
=========== =============

UART_DATA
^^^^^^^^^

Read:

====== ============================
Field  Description
====== ============================
[7:0]  Character
====== ============================

Write:

====== ============================
Field  Description
====== ============================
[7:0]  Character
====== ============================

UART_STATUS
^^^^^^^^^^^

Read:

===== ============================
Field Description
===== ============================
[0]   Character available in FIFO?
[1]   Ready to transmit?
===== ============================

Write:

===== ============================
Field Description
===== ============================
[0]   Dequeue character from FIFO
===== ============================
