/* see http://wiki.osdev.org/Bare_Bones */

#include <stdbool.h>
#include <stdint.h>
#include "stdio.h"
#include "util.h"
#include "string.h"
#include "Kernel_SystemMemoryMap.h"
#include "isapnp.h"
#include "NE2000.h"
#include "isabus.h"
#include "isr_handlers.h"
#include "ethernet.h"
#include "isoosi/layer3.h"


/* Check if the compiler thinks we are targeting the wrong operating system. */
#if defined(__linux__)
#error "You are not using a cross compiler, you will most certainly run into trouble"
#endif

/* This tutorial will only work for the 32 bit ix86 targets. */
#if !defined(__i386__)
#error "This tutorial needs to be compiled with a ix86-elf compiler"
#endif

extern char text[];

/* Helper functions */
void printMac (uint8_t* mac)
{
	for (int i = 0; i < 5; i++)
	{
		terminal_hex_byte(mac[i]);
		terminal_putchar(':');
	}
	terminal_hex_byte(mac[5]);
}

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
	kernel_print_memory_info();

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
	isabus_device* ne_isa = kmalloc(sizeof(isabus_device));
	if (ne_isa)
	{
		ne_isa->iobase = 0x280;
		ne_isa->irq = 5;
		NE2000* ne = NE2000_initialize(ne_isa);
		if (ne)
		{
			printf("NE2000 sucessfully initialized.\n");

			/* Let me proudly present: The first dispatch loop in special-happiness! */
			ethernet2_packet* pkt;

			while ((pkt = NE2000_next_packet(ne)))
			{
				/* printf ("******************** Packet ********************\n");
				printf ("Type: 0x%x\n", (int) pkt->type);
				printf (" Source:      ");
				printMac (pkt->macSource);
				printf ("\nDestination: ");
				printMac (pkt->macDestination);
				printf ("\nData size: %d\n", (int) pkt->dataSize); */
				layer3_in(pkt);
			}

			printf ("NE2000_next_pkt failed.\n");
		}
		else
		{
			printf("NE2000 initialization failed.\n");
		}
	}
	else
	{
		printf("Failed to allocate memory for isabus_device.\n");
	}
}
