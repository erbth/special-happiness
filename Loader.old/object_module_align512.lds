/* Linker script for linking individual modules one module that is
   loaded at address 0x7C00 (for generating bootsectors).
   The output module's loadable sections are aligned to 200h bytes.
   Additionally, the section sizes are dfined as absolute models */

OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */

SECTIONS
{
	. = 0x7C00;
    .text : {
        *(.text)
        . = ALIGN(0x200);  /* align to full block */
    }

    .bss (NOLOAD) : {
        *(.bss)
    }
}
