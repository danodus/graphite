MEMORY
{
   rom      (rx) : ORIGIN = 0xF0000000, LENGTH = 1024*4
   ram      (rwx) : ORIGIN = 0xD0000000, LENGTH = 512*4
}

__stacktop = ORIGIN(ram) + LENGTH(ram);

SECTIONS {
	.memory : {
		. = 0x0;
		*(.init);
		*(.text);
		*(*);
		. = ALIGN(4);
		end = .;
	} >rom
}