/* Linker script for linking individual modules to a flat binary that is
   loaded to address 0x7C00 (for generating bootsectors) */

OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */

SECTIONS
{
	. = 0x7C00;
	.text : { *(.text) }
}
