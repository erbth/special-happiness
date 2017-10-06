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

	/* MemoryManagement */
	char* test1 = kmalloc(100);
	if (!test1)
	{
		printf("Allocating test1 failed\n");
		return;
	}

	char* test2 = kmalloc(100);
	if (!test2)
	{
		printf("Allocating test2 failed\n");
		return;
	}

	char* test3 = kmalloc(100);
	if (!test3)
	{
		printf("Allocating test3 failed\n");
		return;
	}

	MemoryManagement_print();
	printf("test1: %p, test2: %p, test3: %p\n", test1, test2, test3);

	kfree(test1);
	MemoryManagement_print();

	kfree(test2);
	MemoryManagement_print();

	kfree(test3);
	MemoryManagement_print();

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
