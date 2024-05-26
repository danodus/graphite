MEMORY
{
   ram      (rwx) : ORIGIN = 0x00000000, LENGTH = 16*1024*1024
}

__stacktop = ORIGIN(ram) + LENGTH(ram);

SECTIONS {
	.memory : {
		. = 0x000000;
		*(.text);
		*(.sbss);
		. = ALIGN(4);
		end = .;
	} >ram

	.heap : {
		. = ALIGN(4);
		_heap_start = .;
		_end = .;
	} >ram
}