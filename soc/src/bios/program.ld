/* Ref.: https://github.com/YosysHQ/picorv32/blob/main/picosoc/sections.lds */

MEMORY
{
   ROM      (rx) : ORIGIN = 0xF0000000, LENGTH = 2048
}

SECTIONS {

    /*
     * This is the initialized data
     */
    .data : {
        . = ALIGN(4);

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
    } > ROM
}
