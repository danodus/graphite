/* Ref.: https://github.com/YosysHQ/picorv32/blob/main/picosoc/sections.lds */

MEMORY
{
   RAM      (rwx) : ORIGIN = 0x00000000, LENGTH = 16*1024*1024
}

__stacktop = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS {


    /*
     * This is the initialized data
     */
    .data : {
        . = ALIGN(4);
        _sdata = .;        /* create a global symbol at data start; used by startup code in order to initialise the .data section in RAM */
        _ram_start = .;    /* create a global symbol at ram start (e.g., for garbage collector) */

        *(.init)
        *(.text)                /* .text sections (code) */
        *(.text*)               /* .text* sections (code) */
        . = ALIGN(4);

    	/* Initialized data */
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        . = ALIGN(4);
        *(.rodata)              /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)             /* .rodata* sections (constants, strings, etc.) */
        *(.srodata)             /* .rodata sections (constants, strings, etc.) */
        *(.srodata*)            /* .rodata* sections (constants, strings, etc.) */

        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end; used by startup code in order to initialise the .data section in RAM */
    } > RAM

    /* Uninitialized data section */
    .bss : {
        . = ALIGN(4);
        _sbss = .;         /* define a global symbol at bss start; used by startup code */
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end; used by startup code */
    } >RAM

    /* this is to define the start of the heap, and make sure we have a minimum size */
    .heap : {
        . = ALIGN(4);
        _heap_start = .;    /* define a global symbol at heap start */
	_end = .;           /* as expected by syscalls.c            */
    } >RAM
}
