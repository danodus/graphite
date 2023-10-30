MEMORY
{
   ram      (rwx) : ORIGIN = 0x00000000, LENGTH = 128*1024
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