/* Linker script for linking individual modules to a single one that is
   loaded to address 0x100000 (for Kernels). */

OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */
SECTIONS
{
	. = 0;

    .text : {
        *(.text)
        *(.text.hot)
        *(.text.unlikely)
    }

    .data : {
        *(.data)
        *(.rodata*)
    }

    /* uninitialized data, not loaded */
    .bss (NOLOAD) : {
        *(.bss)
    }

    /* comment, not loaded */
    .comment : { *(.comment) }
}
