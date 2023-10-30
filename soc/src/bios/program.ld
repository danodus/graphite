MEMORY
{
   ram      (rwx) : ORIGIN = 0xF0000000, LENGTH = 512*4
}

SECTIONS {
	.memory : {
		. = 0x000000;
		*(.init);
		*(.text);
		*(*);
		. = ALIGN(4);
		end = .;
	} >ram

	.heap : {
		. = ALIGN(4);
		_heap_start = .;
		_end = .;
	} >ram
}