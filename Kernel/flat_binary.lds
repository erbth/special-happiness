/* Linker script for linking individual modules to a flat binary that is
   loaded at address 0x100000 (for Kernels). */

OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */

binary_vma = 0x100000;  /* VMA of the output binary file at runtime */

SECTIONS
{
	. = binary_vma;

    .text : {
        *(.text)
        *(.text.hot)
        *(.text.unlikely)
    }

    .data : { *(.data) }

    /* size of binary (all sections beeing loaded) as absolute symbol */
    binary_size = . - binary_vma;

    /* uninitialized data, not loaded */
    .bss : {
        *(COMMON)
        *(.bss)
    }

    /* comment, not loaded */
    .comment : { *(.comment) }
}
