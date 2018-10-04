/* Linker script for linking special-happiness*/

OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */

MEMORY
{
    address_space : ORIGIN = 0x7C00, LENGTH = 4096m
    floppy        : ORIGIN = 0, LENGTH = 1440k
}

SECTIONS
{
	/* Stage 1 - the bootstrapper */
	.stage1 : {
		*(.text_stage1)
	} > address_space AT > floppy

    /* uninitialized data, not loaded */
    .bss_stage1 (NOLOAD) : {
        *(.bss_stage1)
	} > address_space AT > floppy

	/* Bootstrapped sections */
	.bootstrapped : {
        *(.text_bootstrapped)
        *(.data_bootstrapped)
	} > address_space AT > floppy

    /* uninitialized data, not loaded */
    .bss_bootstrapped (NOLOAD) : {
        *(.bss_bootstrapped)
	} > address_space AT > floppy

	bootstrapped_blocks_to_load = (SIZEOF (.bootstrapped) + 0x1FF ) / 0x200;

	/* Align to size of full blocks */
	. = ALIGN(0x200);

	/* Dynamically loaded sections */
    .dynamic : {
        *(.text_dynamic)
        *(.data_dynamic)
    } > address_space AT > floppy

    /* uninitialized data, not loaded */
    .bss_dynamic (NOLOAD) : {
        *(.bss_dynamic)
    } > address_space AT > floppy

	/* Remove all other sections */
	/DISCARD/ : { *(*) }
}
