/* Linker script to link the bootstrapping stage 1 */
OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)		/* Is this a good idea? What about emulation? */

SECTIONS
{
	. = 0;
	.text_stage1 : {
		*(.text)
	}

	.bss_stage1 (NOLOAD) : {
		*(.bss)
	}
}
