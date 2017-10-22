#include <stdint.h>
#include <stddef.h>
#include "string.h"
#include "stdio.h"
#include "io.h"
#include "isabus.h"
#include "isr_handlers.h"
#include "NE2000_internal.h"
#include "NE2000.h"

static NE2000* global_ne = NULL;

/* Function:   NE2000_initialize
 * Purpose:    to initialze the NE2000 and her driver
 * See:        http://wiki.osdev.org/Ne2000
 * Parameters: isadev [IN]: Pointer to ISA bus device. Ownership of it is taken,
 *                          but only in case of success. Otherwise no
 *                          modification is guaranteed.
 * Result:     A pointer to the new driver instance or NULL in case of any
 *             failure. */
NE2000* NE2000_initialize(isabus_device* isadev)
{
	if (!isadev)
		return NULL;

	NE2000* ne = kmalloc(sizeof(NE2000));
	if (!ne)
		return ne;

	bzero(ne, sizeof(*ne));
	ne->isadev = isadev;

	uint16_t iobase = isadev->iobase;

	outb(iobase + 0x1f, inb(iobase + 0x1f));	// Start whole card reset
	while ((inb(iobase + 0x07) & 0x80) == 0);	// Wait until NIC enters reset
												// state

	outb(iobase + 0x00, (1 << 5) | 1);	// Command: Page 0, no DMA, stop
	ne->page = 0;
	outb(iobase + 0x0E, 0x41);			// DCR: set word-wide access, 4 words fifo
										// threshold, loopback
	outb(iobase + 0x0D, 0x02);			// TCR: Enable internal loopback
	outb(iobase + 0x0C, 0x24);			// RCR: Accept broadcast
	outb(iobase + 0x0F, 0);				// IMR: Mask all interrupts

	/* Start DP8390 NIC */
	outb(iobase + NE_CR_W, (1 << 5) | 2 | ne->page << 6);
	while (inb(iobase + 0x07) & 0x80);	// Wait until NIC leaves the reset state

	outb(iobase + 0x0A, 32);			// RBCR0: Reading 32 bytes
	outb(iobase + 0x0B, 0);				// RBCR1
	outb(iobase + 0x08, 0);				// RSAR0: Start read at card memory address 0
	outb(iobase + 0x09, 0);				// RSAR1
	outb(iobase + 0x00, 0x0A);			// Command: Start the remote DMA read

	for (int i = 0; i < 32; i++)
	{
		ne->prom[i] = inb(iobase + 0x10);	// Card's transfer port
	}

	// Program the PAR0..PAR5 registers to listen for packtes to our MAC address!
	// Page 1
	NE2000_select_page(ne, 1);

	// Command: Complete DMA, stop
	outb(iobase, (1 << 5) | 1 | ne->page << 6);

	printf("NE2000: MAC address: ");

	for (int i = 0; i < 6; i++)
	{
		terminal_hex_byte(ne->prom[i]);
		if (i < 5)
		{
			printf(":");
		}

		outb(iobase + 1 + i, ne->prom[i]);
	}

	printf("\n");

	/* Setup local dma for receiving packets */
	NE2000_select_page(ne, 0);
	outb(iobase + NE_PSTART_W, 0x40);
	outb(iobase + NE_PSTOP_W, 0x60);
	outb(iobase + NE_BNRY_W, 0x40);
	outb(iobase + NE_CURR_W, 0x40);

	/* Enable all interrupts */
	outb(iobase + NE_ISR_W, 0x7F);
	outb(iobase + NE_IMR_W, 0x7F);

	/* Install interrupt handler and enable interrupt */
	isrh_add_handler((uintptr_t) NE2000_isr_handler, 0x25);
	outb(0x21, inb(0x21) & ~(1 << 5));

	/* Leave loopback mode */
	NE2000_select_page(ne, 2);
	uint8_t dcr = inb(iobase + NE_DCR_R);
	uint8_t tcr = inb(iobase + NE_TCR_R);

	NE2000_select_page(ne, 0);
	outb(iobase + NE_DCR_W, dcr | 0x08);
	outb(iobase + NE_TCR_W, tcr & ~0x06);

	global_ne = ne;
	return ne;
}

/* Function:   c_NE2000_isr_handler
 * Purpose:    to handle isr requests from NE2000, called by a wrapper to ensure
 *             proper handling.
 * Cc:         cdecl
 * Parameters: None.
 * Returns:    Nothing. */
__attribute__((cdecl)) void c_NE2000_isr_handler(void)
{
	printf("NE2000: interrupt happened.\n");
	NE2000_print_state(global_ne);
}

/* Function:   NE2000_select_page
 * Purpose:    to select a page in the command register block. If an invalid
 *             page number (> 2) is given, page 0 is selected. the
 * Parameters: ne [IN]:   Pointer to the driver's context
 *             page [IN]: Page to select.
 * Returns:    Nothing. */
void NE2000_select_page(NE2000* ne, uint8_t page)
{
	if (ne->page != page)
		ne->page = page > 2 ? 0 : page;
}

/* Function:   NE2000_print_state
 * Purpose:    to print some info about the card's state.
 * Parameters: ne [IN]: Pointer to the driver's context.
 * Returns:    Nothing. */
void NE2000_print_state(NE2000* ne)
{
	uint16_t iobase = ne->isadev->iobase;

	NE2000_select_page(ne, 2);
	int pstart = inb(iobase + NE_PSTART_R);
	int pstop = inb(iobase + NE_PSTOP_R);

	NE2000_select_page(ne, 1);
	int current = inb(iobase + NE_CURR_R);

	NE2000_select_page(ne, 0);
	int boundary = inb(iobase + NE_BNRY_R);

	printf("********************************* NE2000 state ********************************\n");
	printf("PSTART: 0x%x\nPSTOP: 0x%x\nBoundary: 0x%x\nCurrent: 0x%x\n",
		pstart, pstop, boundary, current);
}
