/* Linker script for linking of individual modules to one relocatable module
   where the output module is aligned to full blocks of 200h bytes. */

OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */

SECTIONS
{
	. = 0;
	.text : {
		*(.text)
		. = ALIGN(0x200);  /* align to full block */
	}
}
