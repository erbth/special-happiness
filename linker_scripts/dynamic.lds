/* Linker script to link the dynamically loaded code (that is it is loaded by
 * the OS itself, actually distinct from a 'classic' dynamically linked library). */

OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)		/* Is this a good idea? What about emulation? */

SECTIONS
{
	. = 0;
	.text_dynamic : {
		*(.text*)
	}

	.data_dynamic : {
		*(.data*)
		*(.rodata*)
	}

	.bss_dynamic (NOLOAD) : {
		*(.bss)
	}
}
