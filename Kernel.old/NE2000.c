#include <stdint.h>
#include <stddef.h>
#include "string.h"
#include "stdio.h"
#include "io.h"
#include "isabus.h"
#include "LinkedQueue.h"
#include "isr_handlers.h"
#include "ethernet.h"
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

	/* Create receve queue */
	ne->recvQueue = LinkedQueue_create();
	if (!ne->recvQueue)
	{
		kfree(ne);
		return NULL;
	}

	uint16_t iobase = isadev->iobase;

	outb(iobase + 0x1f, inb(iobase + 0x1f));	// Start whole card reset
	while ((inb(iobase + 0x07) & 0x80) == 0);	// Wait until NIC enters reset
												// state

	outb(iobase + 0x00, (1 << 5) | 1);	// Command: Page 0, no DMA, stop
	ne->page = 0;
	outb(iobase + 0x0E, 0x41);			// DCR: set word-wide access, 4 words fifo
										// threshold, loopback
	outb(iobase + NE_RBCR0_W, 0);			// Clear remote byte count registers
	outb(iobase + NE_RBCR1_W, 0);

	outb(iobase + 0x0C, 0x04);			// RCR: Accept broadcast
	outb(iobase + 0x0D, 0x02);			// TCR: Enable internal loopback

	outb(iobase + NE_BNRY_W, 0x40);		// Initialize receive buffer registers
	outb(iobase + NE_PSTART_W, 0x40);
	outb(iobase + NE_PSTOP_W, 0x80);

	outb(iobase + NE_ISR_W, 0xFF);		// Clear ISR
	outb(iobase + NE_IMR_W, 0x7F);		// Initialize IMR: enable all

	outb(iobase + 0x0A, 32);			// RBCR0: Reading 32 bytes
	outb(iobase + 0x0B, 0);				// RBCR1
	outb(iobase + 0x08, 0);				// RSAR0: Start read at card memory address 0
	outb(iobase + 0x09, 0);				// RSAR1
	outb(iobase + 0x00, 0x0A);			// Command: Start the remote DMA read

	for (int i = 0; i < 32; i++)
	{
		ne->prom[i] = inb(iobase + 0x10);	// Card's transfer port
	}

	ne->mac = ne->prom;

	// Program the PAR0..PAR5 registers to listen for packtes to our MAC address!
	// Page 1
	NE2000_select_page(ne, 1);

	printf("NE2000: MAC address: ");
	for (int i = 0; i < 6; i++)
	{
		terminal_hex_byte(ne->mac[i]);
		if (i < 5)
		{
			printf(":");
		}

		outb(iobase + 1 + i, ne->mac[i]);
	}
	printf("\n");

	outb(iobase + NE_CURR_W, 0x41);
	ne->next__pkt = 0x41;

	/* Start DP8390 NIC */
	outb(iobase + NE_CR_W, (1 << 5) | 2 | ne->page << 6);
	while (inb(iobase + 0x07) & 0x80);	// Wait until NIC leaves the reset state

	/* Enable all interrupts */
	NE2000_select_page(ne, 0);
	outb(iobase + NE_ISR_W, 0x7F);

	/* Install interrupt handler and enable interrupt */
	isrh_add_handler((uintptr_t) NE2000_isr_handler, 0x25);
	outb(0x21, inb(0x21) & ~(1 << 5));

	/* Leave loopback mode */
	NE2000_select_page(ne, 0);
	outb(iobase + NE_DCR_W, 0x49);
	outb(iobase + NE_TCR_W, 0x00);

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
	NE2000* ne = global_ne;
	uint16_t iobase = ne->isadev->iobase;

	// printf("NE2000: interrupt happened.\n");
	// NE2000_print_state(ne);

	/* Fetch packet(s) from card buffer */
	while (ne->next__pkt != NE2000_current_read(ne))
	{
		NE2000_remoteStartAddress_write(ne, ne->next__pkt << 8);
		NE2000_remoteByteCount_write(ne, 4);
		NE2000_remoteDMA_read(ne);

		uint16_t tmp = inw(iobase + NE_FIFO);
		// uint8_t recvState = tmp & 0xFF;
		ne->next__pkt = (tmp >> 8) & 0xFF;

		uint16_t recvCnt = inw(iobase + NE_FIFO);

		if (recvCnt >= 64)
		{
			ethernet2_packet* pkt = kmalloc(sizeof(ethernet2_packet));
			if (pkt)
			{
				bzero(pkt, sizeof(*pkt));

				/* We don't need the CRC, the card already checked it. */
				pkt->dataSize = recvCnt - (6 + 6 + 2 + 4);

				pkt->data = kmalloc(pkt->dataSize);
				if (pkt->data)
				{
					/* Destination MAC address */
					for (uint8_t i = 0; i < 3; i++)
					{
						((uint16_t*) pkt->macDestination)[i] = inw(iobase + NE_FIFO);
					}

					/* Source MAC address */
					for (uint8_t i = 0; i < 3; i++)
					{
						((uint16_t*) pkt->macSource)[i] = inw(iobase + NE_FIFO);
					}


					/* Type field */
					pkt->type = ethernet_ntohs(inw(iobase + NE_FIFO));
					if (pkt->type > 0x600)
					{
						for (uint16_t i = 0; i < pkt->dataSize / 2; i++)
						{
							((uint16_t*) pkt->data)[i] = inw(iobase + NE_FIFO);
						}

						/* Odd packet length */
						if (pkt->dataSize & 0x01)
						{
							pkt->data[pkt->dataSize - 1] = inb(iobase + NE_FIFO);
						}

						/* Enqueue the packet. */
						if (LinkedQueue_enqueue(ne->recvQueue, pkt) < 0)
						{
							kfree (pkt->data);
							kfree(pkt);
							printf ("NE2000: Enqueuing packet failed.\n");
						}
					}
					else
					{
						kfree(pkt->data);
						kfree(pkt);
						printf ("NE2000: Received an Ethernet-I frame (not supported).\n");
					}

				}
				else
				{
					kfree(pkt);
					printf("NE2000: Allocating buffer for packet data failed.\n");
				}
			}
			else
			{
				printf("NE2000: Allocating packet meta-data-structure failed.\n");
			}
		}
		else
		{
			printf("NE2000: Runt packet received.\n");
		}

		NE2000_remoteDMA_stop(ne);

		/* Advance boundary pointer */
		NE2000_boundary_write(ne, ne->next__pkt - 1);
	}

	/* Clear ISR */
	NE2000_select_page(ne, 0);
	int isr = inb(iobase + NE_ISR_R);
	isr &= isr;
	outb(iobase + NE_ISR_W, isr);
}

/* Function:   NE2000_next_packet
 * Purpose:    to retrieve the next packet from the queue. If the queue is
 *             empty, this function blocks until a packet gets enqueued.
 * Parameters: ne [IN]: A pointer to the NE2000 driver's context structure.
 * Returns:    A pointer to the retrieved packet or NULL in case of failure. */
ethernet2_packet* NE2000_next_packet(NE2000* ne)
{
	if (ne && ne->recvQueue)
	{
		for (;;)
		{
			ethernet2_packet* pkt = (ethernet2_packet*) LinkedQueue_dequeue(ne->recvQueue);
			if (pkt)
			{
				return pkt;
			}

			kHLT();
		}
	}
	return NULL;
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
	{
		ne->page = page > 2 ? 0 : page;
		outb(ne->isadev->iobase + NE_CR_W,
			(inb(ne->isadev->iobase + NE_CR_R) & 0x3F) | page << 6);
	}
}

/* Function:   NE2000_print_state
 * Purpose:    to print some info about the card's state.
 * Parameters: ne [IN]: Pointer to the driver's context.
 * Returns:    Nothing. */
void NE2000_print_state(NE2000* ne)
{
	uint16_t iobase = ne->isadev->iobase;

	NE2000_select_page(ne, 1);
	int current = inb(iobase + NE_CURR_R);

	NE2000_select_page(ne, 0);
	int boundary = inb(iobase + NE_BNRY_R);
	int isr = inb(iobase + NE_ISR_R);

	int frame = inb(iobase + NE_FRAME_ERR_R);
	int crc = inb(iobase + NE_CRC_ERR_R);
	int missed = inb(iobase + NE_MISSED_ERR_R);

	printf("********************************* NE2000 state ********************************\n");
	printf("Boundary: 0x%x\nCurrent: 0x%x\n",
		boundary, current);

	printf("Errors: Frame: %d, CRC: %d, Missed: %d\n", frame, crc, missed);

	printf("ISR: 0x%x\n", isr);
}

/*************** Functions for interfacing with the Remote DMA ***************/
/* Function:   NE2000_remoteDMA_sendPacket
 * Purpose:    to issue a SEND PACKET COMMAND to the card's Remote DMA unit.
 * Parameters: ne [IN]: A pointer to the driver's meta-data-structure.
 * Returns:    Nothing. */
void NE2000_remoteDMA_sendPacket(NE2000* ne)
{
	NE2000_command_write(ne, (NE2000_command_read(ne) & ~0x38) | 0x18);
}

/* Function:   NE2000_remoteDMA_read
 * Purpose:    to read from the card's memory using its Remote DMA unit.
 * Parameters: ne [IN]: A pointer to the driver's meta-data-structure.
 * Returns:    Nothing. */
void NE2000_remoteDMA_read(NE2000* ne)
{
	NE2000_command_write(ne, (NE2000_command_read(ne) & ~0x38) | 0x08);
}

/* Function:   NE2000_remoteDMA_stop
 * Purpose:    to abort/complete any operation on the Remote DMA.
 * Parameters: ne [IN]: A pointer to the driver's meta-data-structure.
 * Returns:    Nothing. */
void NE2000_remoteDMA_stop(NE2000* ne)
{
	NE2000_command_write(ne, (NE2000_command_read(ne) & ~0x38) | 0x20);
}

/********************* Functions for accessing registers *********************/
/* Basic format: NE2000_<register name>_<read|write>
 * Parameters:   Functions for reading only take a pointer to the NE2000
 *               driver's context structure, those for writing have a second
 *               parameter comprising the particular 8 bit value.
 * Returns:      Functions for reading return the paritcular 8 bit value,
 *               the ones for writing return nothing. */

uint8_t NE2000_command_read(NE2000* ne)
{
	/* The command register is available on all pages. */
	return inb(ne->isadev->iobase + NE_CR_R);
}

void NE2000_command_write(NE2000* ne, const uint8_t val)
{
	/* The command resgiter is available on all pages. */
	outb(ne->isadev->iobase + NE_CR_W, val);
}

uint8_t NE2000_boundary_read(NE2000* ne)
{
	NE2000_select_page(ne, 0);
	return inb(ne->isadev->iobase + NE_BNRY_R);
}

void NE2000_boundary_write(NE2000* ne, const uint8_t val)
{
	NE2000_select_page(ne, 0);
	outb(ne->isadev->iobase + NE_BNRY_W, val);
}

uint8_t NE2000_current_read(NE2000* ne)
{
	NE2000_select_page(ne, 1);
	return inb(ne->isadev->iobase + NE_CURR_R);
}

void NE2000_remoteStartAddress_write(NE2000* ne, const uint16_t addr)
{
	NE2000_select_page(ne, 0);
	outb(ne->isadev->iobase + NE_RSAR0_W, addr & 0xFF);
	outb(ne->isadev->iobase + NE_RSAR1_W, (addr >> 8) & 0xFF);
}

void NE2000_remoteByteCount_write(NE2000* ne, const uint16_t cnt)
{
	NE2000_select_page(ne, 0);
	outb(ne->isadev->iobase + NE_RBCR0_W, cnt & 0xFF);
	outb(ne->isadev->iobase + NE_RBCR1_W, (cnt >> 8) & 0xFF);
}
