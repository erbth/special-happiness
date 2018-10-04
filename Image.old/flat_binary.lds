/* Linker script for linking the Loader and the Kernel to a flat binary.
 * The Loader os located at 0x7C00, the Kernel at 0x100000. */

OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)      /* Is this a good idea? What about emulation? */

MEMORY
{
    boot   : ORIGIN = 0x7c00, LENGTH = 0xF8400
    kernel : ORIGIN = 0x100000, LENGTH = 10m
    floppy : ORIGIN = 0, LENGTH = 1440k
}

SECTIONS
{
    .loader_loadable : {
        loader_text_start = .;   /* absolute symbol */
        ../bin/Loader/Loader.o(.text)
        loader_text_end = .;

        loader_data_start = .;
        ../bin/Loader/Loader.o(.data)
        loader_data_end = .;
    } > boot AT > floppy

    loader_loadable_size = loader_data_end - loader_text_start;

    .bss1 (NOLOAD) : {
        loader_bss_start = .;
        ../bin/Loader/Loader.o(.bss)
        loader_bss_end = .;
    } > boot

    loader_bss_size = SIZEOF(.bss1);

    .kernel_loadable : {
        kernel_text_start = .;
        ../bin/Kernel/Kernel.o(.text)
        kernel_text_end = .;

        kernel_data_start = .;
        ../bin/Kernel/Kernel.o(.data)
        kernel_data_end = .;
    } > kernel AT > floppy

    kernel_load_addr = LOADADDR(.kernel_loadable);

    kernel_loadable_size = kernel_data_end - kernel_text_start;

    .bss2 (NOLOAD) : {
        kernel_bss_start = .;
        ../bin/Kernel/Kernel.o(.bss)
        kernel_bss_end = .;
    } > kernel

    kernel_bss_size = SIZEOF(.bss2);
}
