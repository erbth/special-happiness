#include <stdint.h>
#include <stddef.h>
#include "io.h"
#include <string.h>

/* Function:   NE2000_initialize
 * Purpose:    to have fun
 * Parameters: none */
void NE2000_initialize(void)
{
	// see http://wiki.osdev.org/Ne2000
	uint16_t iobase = 0x280;		// just for now
	uint8_t prom[32];
	uint8_t packet[60];

	memset(packet, 0, sizeof(packet));

	outb(iobase + 0x1F, inb(iobase + 0x1F));	// start reset
	while ((inb(iobase + 0x07) & 0x80) == 0);
	outb(iobase + 0x07, 0xFF);					// mask interupts

	outb(iobase, (1 << 5) | 1);			// page 0, no DMA, stop
	outb(iobase + 0x0E, 0x49);			// set word-wide access
	outb(iobase + 0x0A, 0);				// clear the count regs
	outb(iobase + 0x0B, 0);
	outb(iobase + 0x0F, 0);				// mask completion IRQ
	outb(iobase + 0x07, 0xFF);
	outb(iobase + 0x0C, 0x20);			// set to monitor
	outb(iobase + 0x0D, 0x02);			// and loopback mode.
	outb(iobase + 0x0A, 32);			// reading 32 bytes
	outb(iobase + 0x0B, 0);				// count high
	outb(iobase + 0x08, 0);				// start DMA at 0
	outb(iobase + 0x09, 0);				// start DMA high
	outb(iobase, 0x0A);					// start the read

	for (int i = 0; i < 32; i++)
	{
		prom[i] = inb(iobase + 0x10);
	}

	// program the PAR0..PAR5 registers to listen for packtes to our MAC address!
	outb(iobase, (1 << 6) | (1 << 5) | 1);	// page 1

	terminal_writestring("NE2000: MAC address: ");

	for (int i = 0; i < 6; i++)
	{
		terminal_hex_byte(prom[i]);
		if (i < 5)
		{
			terminal_putchar(':');
		}

		outb(iobase + 1 + i, prom[i]);
		packet[6 + i] = prom[i];
	}

	terminal_putchar('\n');

	// send packet
	outb(iobase, 0x22);				// page 0, no DMA, start
	outb(iobase + 0x0A, 60);		// packet size
	outb(iobase + 0x0B, 0);			// packet size high
	outb(iobase + 0x07, (1 << 6));	// clear "Remote DMA complete?"
	outb(iobase + 0x08, 0);			// start DMA at page boundary
	outb(iobase + 0x09, 0);			// start DMA page 0
	outb(iobase, 0x12);				// page 0, "remote write DMA", start

	// destination: Andromeda2
	packet[0] = 0x00;
	packet[1] = 0x16;
	packet[2] = 0x76;
	packet[3] = 0xe1;
	packet[4] = 0x9c;
	packet[5] = 0x13;

	packet[12] = 0x08;				// IPv4 ;)
	packet[13] = 0x00;

	strcpy((char *) (packet + 14), "Hello, World!");

	for (int i = 0; i < 60 / 2; i++)
	{
		outw(iobase + 0x10, ((uint16_t *) packet)[i]);\
	}

	while ((inb(iobase + 0x07) & 0x40) == 0);
	terminal_writestring("NE2000: transmission complete\n");
}
