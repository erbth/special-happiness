/* Linker script for linking of individual modules to one relocatable module */

OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */

SECTIONS
{
	. = 0;
	.text : {
		*(.text)
	}

	.bss (NOLOAD) : {
		*(.bss)
	}
}
