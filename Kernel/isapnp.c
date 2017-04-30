/* see http://linux-sxs.org/programming/interfac.html,
 *     https://www.heise.de/ct/artikel/Plug-Play-Hilfe-285966.html,
 *     http://download.microsoft.com/download/1/6/1/161ba512-40e2-4cc9-843a-923143f3456c/PNPISA.rtf */

#include <stdint.h>
#include "isapnp.h"
#include "io.h"

#define ISAPNP_MAX_NUM_DEVICES 10

#define ISAPNP_ADDRESS 0x279
#define ISAPNP_WRITE   0xA79

typedef struct
{
	uint8_t pnp_id[9];
	uint16_t io_base_port;
	uint8_t irq;
	void *mem_base;

	char name[256];
} isapnp_device;

/**********
* globals *
**********/
static uint16_t isapnp_rpa;

void isapnp_delay(void)
{
	volatile int i = 0;

	while (i != 333000)
	{
		i++;
	}
}

/* Function:   isapnp_send_initiation_key
 * Purpose:    to enable the PnP logic on the PnP ISA cards
 * Parameters: none */
void isapnp_send_initiation_key(void)
{
	uint8_t lfsr_value = 0x6A;

	outb(ISAPNP_ADDRESS, 0);		// reset the LFSR (Linear Feedback Shift Register)
	outb(ISAPNP_ADDRESS, 0);

	for (int i = 0; i < 32; i++)
	{
		uint8_t temp = ((lfsr_value & 0x01) ^ ((lfsr_value >> 1) & 0x01)) << 7;

		outb(ISAPNP_ADDRESS, lfsr_value);

		lfsr_value = (lfsr_value >> 1) & 0x7F;
		lfsr_value |= temp;
	}
}

/* Function:   isapnp_reset_csns
 * Purpose:    to reset the ISA PnP cards' csns' to 0
 * Parameters: none */
void isapnp_reset_csns(void)
{
	outb(ISAPNP_ADDRESS, 2);		// set the address register to configuration control
	outb(ISAPNP_WRITE, 4);			// reset all csns to 0
}

/* Function:   isapnp_wake
 * Purpose:    to wake up a specific ISA PnP card or all cards
 * Parameters: csn: target card's csn or 0 to wake all cards */
void isapnp_wake(uint8_t csn)
{
	outb(ISAPNP_ADDRESS, 3);		// set the address register to wakeup
	outb(ISAPNP_WRITE, csn);		// csn
}

/* Function:   isapnp_set_read_port_address
 * Purpose:    to set the ISA PnP read address in the range of 0x203 and 0x3FF,
 *             where the least significant 2 bits need to be set
 * Parameters: port: read port address */
void isapnp_set_read_port_address(uint16_t port)
{
	outb(ISAPNP_ADDRESS, 0);		// set address register to 'set read port address'
	outb(ISAPNP_WRITE, (port >> 2) & 0xFF);  // write read port address
}

 /* Function:   isapnp_select_isolation
  * Purpose:    to select the serial isolation register from which the card
  *             identifiers can be read if a card is in isolation state
  * Parameters: none */
void isapnp_select_isolation(void)
{
	outb(ISAPNP_ADDRESS, 1);
}

/* Function:   isapnp_set_csn
 * Purpose:    to set the CSN of the card which is currently in Configuration
 *             state
 * Parameters: csn: the CSN to set */
void isapnp_set_csn(uint8_t csn)
{
	outb(ISAPNP_ADDRESS, 6);		// Card Select Number
	outb(ISAPNP_WRITE, csn);
}

/* Function:   isapnp_read_id
 * Purpose:    to read a card's id during serial isolation
 * Parameters: id: a pointer to an array of 9 uint8_ts where the ISA PnP id will
 *             be stored
 * Returns:    1 in case of success, 0 in case of failure or if no card has sent
 *             an id (possibly because no card is on the bus) */
uint8_t isapnp_read_id(uint8_t *id)
{
	uint16_t input;
	int card_detected = 0;

	for (int i = 0; i < 9; i++)
	{
		for (int j = 0; j < 8; j++)
		{
			isapnp_delay();		// wait 1 msec or 250 usec ... (not implemented yet)

			input = inb(isapnp_rpa);
			input = input | (inb(isapnp_rpa) << 8);

			if (input == 0xAA55)
			{
				card_detected = 1;
				id[i] = ((id[i] >> 1) & 0x7F) | 0x80;
			}
			else if (input == 0xFFFF)
			{
				id[i] = (id[i] >> 1) & 0x7F;
			}
			else
			{
				return 0;
			}
		}
	}

	if (card_detected)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}


void isapnp_detect(void)
{
	uint8_t nDevices = 0;
	isapnp_device devices[ISAPNP_MAX_NUM_DEVICES];
	uint8_t next_csn;

	isapnp_rpa = 0x203;

	isapnp_send_initiation_key();
	isapnp_reset_csns();

	isapnp_wake(0);				// wake all cards with unconfigured csn
	isapnp_set_read_port_address(isapnp_rpa);

	next_csn = 1;

	while (1)
	{
		isapnp_select_isolation();

		if (!isapnp_read_id(devices[nDevices].pnp_id))
		{
			break;
		}

		isapnp_set_csn(next_csn++);

		nDevices++;

		if (nDevices >= ISAPNP_MAX_NUM_DEVICES)
		{
			terminal_writestring("ISAPNP: maximum number of cards reached.\n");
			break;
		}
	}

	if (nDevices > 0)
	{
		terminal_writestring("ISAPNP: read io port: 0x");
		terminal_hex_word(isapnp_rpa);
		terminal_writestring("\nISAPNP: ");
		terminal_hex_byte(nDevices);
		terminal_writestring("h cards detected.\n");
	}
	else
	{
		terminal_writestring("ISAPNP: no card detected.\n");
	}


/*


	for (isapnp_rpa = 0x203; nDevices == 0 && isapnp_rpa <= 0x3FF; isapnp_rpa += 4)
	{

	}

	 */
}
