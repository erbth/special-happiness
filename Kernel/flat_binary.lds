/* Linker script for linking individual modules to a flat binary that is
   loaded at address 0x100000 (for Kernels). */

OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */

SECTIONS
{
	. = 0x100000;
    .text : { *(.text) }

    text_size = SIZEOF (.text);  /* size of entire .text section as absolute symbol */
}
