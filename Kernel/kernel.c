/* see http://wiki.osdev.org/Bare_Bones */

#include <stdbool.h>
#include <stdint.h>
#include "stdio.h"
#include "string.h"
#include "Kernel_SystemMemoryMap.h"
#include "isapnp.h"
#include "NE2000.h"

/* Check if the compiler thinks we are targeting the wrong operating system. */
#if defined(__linux__)
#error "You are not using a cross compiler, you will most certainly run into trouble"
#endif

/* This tutorial will only work for the 32 bit ix86 targets. */
#if !defined(__i386__)
#error "This tutorial needs to be compiled with a ix86-elf compiler"
#endif

extern char text[];

#if defined(__cplusplus)
extern "C"  /* use C linkage for kernel_main */
#endif
void kernel_main (void) {
	/* Initialize terminal interface */
	terminal_initialize ();

	terminal_writestring("Welcome to the kernel.\n");

	/* Print the Loader-supplied SMAP */
	// kSystemMemoryMap_print();

	/* Add SMAP free regions to MemoryManagement */
	MemoryManagement_addFromSMAP();

	/* Print available memory */
	printf("Memory: %d Mibi Bytes total, %d/%d bytes used.\n",
		(int) (MemoryManagement_getTotalMemory() / (1024.0 * 1024)),
		MemoryManagement_getTotalMemory() - MemoryManagement_getFreeMemory(),
		MemoryManagement_getTotalMemory());

#if 0
	/* PnP detect cards */
	if (isapnp_detect_configure())
	{
		terminal_writestring("ISA PNP cards detected successfully.\n");
	}
	else
	{
		terminal_writestring("ISA PNP card detection failed.\n");
	}

	/* have fun */
	NE2000_initialize();
#endif
}
