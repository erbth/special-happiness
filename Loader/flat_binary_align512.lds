/* Linker script for linking individual modules to a flat binary that is
   loaded at address 0x7C00 (for generating bootsectors).
   The output modue is aligned to 200h bytes */

OUTPUT_FORMAT(binary)
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

    text_size = SIZEOF (.text); /* size of entire .text section as absolute symbol */
}
