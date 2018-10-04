/* Linker script to link the bootstrapped code */
OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)		/* Is this a good idea? What about emulation? */

SECTIONS
{
	. = 0;
	.text_bootstrapped : {
		*(.text*)
	}

	.data_bootstrapped : {
		*(.data*)
		*(.rodata*)
	}

	.bss_bootstrapped (NOLOAD) : {
		*(.bss)
	}
}
