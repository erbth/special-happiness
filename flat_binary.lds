/* Linker script for linking individual modules to a flat binary that is
   loaded to address 0x7C00 (for generating bootsectors) */

OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */

SECTIONS
{
	. = 0x7C00;

    LOADER : { *(LOADER) }

    . = 0x1000000;  /* Kernel will be loaded at address 0x1000000 */

	.text : AT ( ADDR (LOADER) + SIZEOF (LOADER) ) { *(.text) }
}
