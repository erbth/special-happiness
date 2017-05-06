/* see http://linux-sxs.org/programming/interfac.html,
 *     https://www.heise.de/ct/artikel/Plug-Play-Hilfe-285966.html,
 *     http://download.microsoft.com/download/1/6/1/161ba512-40e2-4cc9-843a-923143f3456c/PNPISA.rtf */

#include <stdint.h>
#include "isapnp.h"
#include "io.h"

#define ISAPNP_MAX_NUM_DEVICES 10

#define ISAPNP_ADDRESS 0x279
#define ISAPNP_WRITE   0xA79

typedef struct _isapnp_card_resource_data isapnp_card_resource_data;
typedef struct _isapnp_logical_device_resource_data isapnp_logical_device_resource_data;
typedef struct _isapnp_dependent_function_resource_data isapnp_dependent_function_resource_data;
typedef struct _isapnp_resource_memory_range isapnp_resource_memory_range;
typedef struct _isapnp_resource_memory_range_8_16_bit isapnp_resource_memory_range_8_16_bit;
typedef struct _isapnp_resource_memory_range_32_bit isapnp_resource_memory_range_32_bit;
typedef struct _isapnp_resource_io_port_range isapnp_resource_io_port_range;
typedef struct _isapnp_resource_dma_mask isapnp_resource_dma_mask;
typedef struct _isapnp_resource_irq_mask isapnp_resource_irq_mask;


struct _isapnp_resource_memory_range_8_16_bit
{
	struct
	{
		uint8_t writable : 1;					   // otherwise: ROM
		uint8_t read_cachable : 1;				   // and write-through, otherwise: non-cachable
		uint8_t decode_supports_high_address : 1;  // otherwise: range length
		uint8_t memory_control : 2;		// 00: 8 bit, 01: 16 bit, 10: both supported
		uint8_t is_shadowable : 1;
		uint8_t is_expansion_ROM : 1;
	} information;

	uint16_t minimum_base_address;  // bits[23:8], lower 8 bits are assumed 0, so it is a 24 bit address
	uint16_t maximum_base_address;  // bits[23:8], lower 8 bits are assumed 0, so it is a 24 bit address
	uint16_t base_alignment;		// (0 = 64 KiByte)
	uint16_t length;				// in 256 byte blocks
};

struct _isapnp_resource_memory_range_32_bit
{
	struct
	{
		uint8_t writable : 1;					   // otherwise: ROM
		uint8_t read_cachable : 1;				   // and write-through, otherwise: non-cachable
		uint8_t decode_supports_high_address : 1;  // otherwise: range length
		uint8_t memory_control : 2;		// 00: 8 bit, 01: 16 bit, 10: both supported, 11: 32 bit
		uint8_t is_shadowable : 1;
		uint8_t is_expansion_ROM : 1;
		uint8_t is_fixed : 1;			// if 1, the memory address is fixed and can not be configured.
										// minimum_base = maximum_base will hold the base address, length
										// the corresponding length and base_alignment is undefined.
	} information;

	uint32_t minimum_base_address;
	uint32_t maximum_base_address;
	uint32_t base_alignment;
	uint32_t length;				// in 1 byte blocks
};

struct _isapnp_resource_memory_range
{
	uint16_t configuration_port;  // location of the corresponding logical device configuration register

	enum
	{
		isapnp_resource_memory_range_type_8_16_bit,
		isapnp_resource_memory_range_type_32_bit
	} type;

	union
	{
		isapnp_resource_memory_range_8_16_bit _8_16_bit;
		isapnp_resource_memory_range_32_bit _32_bit;
	} u;
};
struct _isapnp_resource_io_port_range
{
	uint16_t configuration_port;  // location of the corresponding logical device configuration register

	uint8_t full_16_bit;			// if != 0, the device uses the full 16 bit ISA address,
									// if 0, only ISA address bits[9:0] are decoded.

	uint16_t minimum_base_address;
	uint16_t maximum_base_address;
	uint8_t base_alignment;			// in 1 byte blocks
	uint8_t number_of_ports;		// number of contiguous I/O ports requested
};

struct _isapnp_resource_dma_mask
{
	uint16_t configuration_port;  // location of the corresponding logical device configuration register

	uint8_t mask;				// supported DMA channel bit mask, bit 0 is channel 0

	struct
	{
		uint8_t transfer_type_preference : 2;  // 00: 8-bit only, 01: 8- and 16-bit, 10: 16-bit only
		uint8_t is_bus_master : 1;			   // otherwise: logical device is not a bus master
		uint8_t execute_in_count_by_byte : 1;  // othersise: DMA may not execute in count by byte mode
		uint8_t execute_in_count_by_word : 1;  // otherwise: DMA may not execute in count by word mode
		uint8_t speed_support : 2;  // 00: compatibility mode, 01: Type A DMA, 10: Type B DMA, 11: Type F
	} information;
};

struct _isapnp_resource_irq_mask
{
	uint16_t configuration_port;  // location of the corresponding logical device configuration register

	uint16_t mask;				// supported IRQs, bit 0 represents IRQ0

	struct
	{
		uint8_t low_true_level_sensitive : 1;	// interrupt driving capabilities
		uint8_t high_true_level_sensitive : 1;
		uint8_t low_true_edge_sensitive : 1;
		uint8_t high_true_edge_sensitive : 1;	// default / must be supported for ISA compatibility
	};
};

struct _isapnp_dependent_function_resource_data
{
	isapnp_resource_memory_range memory_range[4];
	isapnp_resource_io_port_range io_port_range[8];
	isapnp_resource_dma_mask dma_mask;
	isapnp_resource_irq_mask irq_mask;
};

struct _isapnp_logical_device_resource_data
{
	uint16_t flags;					// (Byte6 << 8) | Byte5
	char identifier_string[256];	// first 255 characters of the logical device's ansi identifier string

	isapnp_resource_memory_range memory_range[4];
	isapnp_resource_io_port_range io_port_range[8];
	isapnp_resource_dma_mask dma_mask;
	isapnp_resource_irq_mask irq_mask;

	uint8_t n_dependent_functions;	// count of dependent functions read
	isapnp_dependent_function_resource_data dependent_functions[4];
									// maximum 4 dependent functions supported
};

struct _isapnp_card_resource_data
{
	uint8_t pnp_version_number;		// bits 7:4: major, bits 3:0: minor version (packed BCD)
	char identifier_string[256];	// first 255 characters of the card's ansi identifier string

	uint8_t n_logical_devices;		// count of logical devices on this card
	isapnp_logical_device_resource_data logical_devices[4];
									// not more than 4 logical devices supported
};

typedef struct
{
	char vendor_string[4];
	uint16_t product_id;
	uint32_t sn;
	uint8_t csn;
	isapnp_card_resource_data resource_data;
} isapnp_device;


/**********
* globals *
**********/
static uint16_t isapnp_rpa;
static uint8_t nDevices;
static isapnp_device devices[ISAPNP_MAX_NUM_DEVICES];


void isapnp_delay(void)
{
	volatile int i = 0;

	while (i != 333000)
	{
		i++;
	}
}

/* Function:   isapnp_lfsr_shift
 * Purpose:    perform a shift equal to that one the LFSR does on a byte value
 *             If no serial input is needed, use 0 as input.
 * Parameters: byte:  pointer to the byte value
 *             input: if 0, 0 is taken as serial input into the checksum
 *             circuit, 1 otherwise. */
 void isapnp_lfsr_shift(uint8_t *byte, uint8_t input)
 {
	 if (input != 0)
	 {
		 input = 1;
	 }

	 // The LFSR's MSB is set to LFSR[0] xor LFSR[1] xor input (serial data)
	 // This is equal to input xor LFSR[0] xor LFSR[1]

	 input = (input ^ (*byte & 0x01) ^ ((*byte & 0x02) >> 1)) << 7;
	 *byte = (*byte >> 1) & 0x7F;
	 *byte |= input;
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
		outb(ISAPNP_ADDRESS, lfsr_value);
		isapnp_lfsr_shift(&lfsr_value, 0);
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

/* Function:   isapnp_reset_configuration
 * Purpose:    to reset the ISA PnP cards' configuration registers preserving
 *             the CSN, RD_DATA port and current PnP state
 * Parameters: none */
void isapnp_reset_configuration(void)
{
	outb(ISAPNP_ADDRESS, 2);		// set the address register to configuration control
	outb(ISAPNP_WRITE, 1);			// reset configuration
	isapnp_delay();					// delay 1 msec (as spec requires)
	isapnp_delay();					// In section 4.4 the spec requires to wait
									// 2 msec after ResetCmd (is this a ResetCmd ?)
}

/* Function:   isapnp_return_to_wait_for_key
 * Purpose:    to put the ISA PnP cards into Wait For Key state
 * Parameters: none */
void isapnp_return_to_wait_for_key(void)
{
	outb(ISAPNP_ADDRESS, 2);		// set the address register to configuration control
	outb(ISAPNP_WRITE, 2);			// reset all csns to 0
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
 * Purpose:    to read a card's vendor id and serial number during serial isolation
 * Parameters: vendor_id: a pointer to a 32 bit unsigned integer receiving the
 *                        vendor id
 *             sn:        a pointer to a 32 bit unsigned integer receiving the
 *                        serial number
 * Returns:    1 in case of success, 0 in case of failure or if no card has sent
 *             an id (possibly because no card is on the bus) */
uint8_t isapnp_read_id(char *vendor_string, uint16_t *product_id, uint32_t *sn)
{
	uint16_t input;
	int card_detected = 0;
	uint8_t id[9];
	uint8_t lfsr = 0x6A;

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

				// The last byte is the checksum itself
				if (i != 8)
				{
					isapnp_lfsr_shift(&lfsr, 1);
				}
			}
			else if (input == 0xFFFF)
			{
				id[i] = (id[i] >> 1) & 0x7F;

				if (i != 8)
				{
					isapnp_lfsr_shift(&lfsr, 0);
				}
			}
			else
			{
				return 0;
			}
		}
	}

	if (!card_detected)
	{
		return 0;
	}

	if (lfsr != id[8])
	{
		return 0;
	}

	vendor_string[0] = ((id[0] >> 2) & 0x1F) + 'A' - 1;
	vendor_string[1] = (((id[1] >> 5) & 0x07) | ((id[0] << 3) & 0x18)) + 'A' - 1;
	vendor_string[2] = (id[1] & 0x1F) + 'A' - 1;
	vendor_string[3] = 0;

	*product_id = id[2] << 8 | id[3];
	*sn        = id[7] << 24 | id[6] << 16 | id[5] << 8 | id[4];
	return 1;
}

/* Function:   isapnp_read_resource_byte
 * Purpose:    to read a byte of resource data from the card which is in config
 *             state. The status register is respected.
 * Parameters: none
 * Returns:    the read byte */
static inline uint8_t isapnp_read_resource_byte()
{
	uint8_t input;

	outb(ISAPNP_ADDRESS, 0x05);
	while (!(inb(isapnp_rpa) & 0x01)) { }  // poll status register (shall not be
										   // optimized because inb is volatile)

	outb(ISAPNP_ADDRESS, 0x04);
	input = inb(isapnp_rpa);				// read resource data
	return input;
}

void isapnp_read_resource_pnp_version(isapnp_device *card, uint16_t *length)
{
	if (*length > 0)
	{
		card->resource_data.pnp_version_number = isapnp_read_resource_byte();
		(*length)--;
	}

	if (*length > 0)
	{
		// vendor specific version number
		isapnp_read_resource_byte();
		(*length)--;
	}
}

void isapnp_read_resource_ansi_string(isapnp_device *card, uint16_t *length)
{
	int pos = 0;

	while ((pos < 255) && (*length > 0))
	{
		card->resource_data.identifier_string[pos++] = isapnp_read_resource_byte();
		(*length)--;
	}

	card->resource_data.identifier_string[pos] = 0;
}

/* Function:   isapnp_read_resource_data
 * Purpose:    to read a card's reasource data
 * Parameters: csn:     the card's CSN,
 *             id_read: if != 0, the 72 bit card id has already been read,
 *                      if 0, it has not
 * Returns:    0 in case of failure, 1 otherwise */
uint8_t isapnp_read_resource_data(uint8_t csn, uint8_t id_read)
{
	uint8_t input;
	uint8_t end_reached = 0;
	isapnp_device *card = NULL;

	// find card
	for (int i = 0; i < nDevices; i++)
	{
		if (devices[i].csn == csn)
		{
			card = &(devices[i]);
		}
	}

	if (card == NULL)
	{
		terminal_writestring("ISAPNP: error: CSN ");
		terminal_hex_byte(csn);
		terminal_writestring("h not found.");
		return 0;
	}

	// wake card and put others to sleep
	isapnp_wake(csn);

	if (id_read == 0)
	{
		// read 72 bit card id (put it to trash as it isn't needed, it is already known)
		for (int i = 0; i < 9; i++)
		{
			isapnp_read_resource_byte();
		}
	}

	do
	{
		input = isapnp_read_resource_byte();

		// read resources
		// only read tag identifiers
		uint8_t resource_id;
		uint16_t length;

		if (input & 0x80)
		{
			resource_id = input;  // keep bit 8 to indicate large resource data type
			length = isapnp_read_resource_byte();
			length = (isapnp_read_resource_byte() << 8) | length;
		}
		else
		{
			// small resource data type
			resource_id = (input >> 3) & 0x0F;
			length = input & 0x07;
		}

		switch (input)
		{
		case 0x01:
			isapnp_read_resource_pnp_version(card, &length);
			break;

		case 0x82:
			isapnp_read_resource_ansi_string(card, &length);
			break;

		default:
			terminal_writestring("ISAPNP: card ");
			terminal_hex_byte(csn);
			terminal_writestring(": unknown resource id: 0x");
			terminal_hex_byte(resource_id);
			terminal_putchar('\n');
			return 0;
		}

		if (length != 0)
		{
			terminal_writestring("ISAPNP: card ");
			terminal_hex_byte(csn);
			terminal_writestring(": resource id: 0x");
			terminal_hex_byte(input);
			terminal_writestring(": length (");
			terminal_hex_word(length);
			terminal_writestring("h) != 0\n");
		}

	} while (!end_reached);

	return 1;
}


void isapnp_detect(void)
{
	uint8_t next_csn;

	isapnp_send_initiation_key();	// cards have to be resetted before read port change
	isapnp_reset_csns();
	isapnp_reset_configuration();

	next_csn = 1;
	nDevices = 0;

	for (isapnp_rpa = 0x203; nDevices == 0 && isapnp_rpa <= 0x3FF;)
	{
		isapnp_wake(0);				// wake all cards with unconfigured csn
		isapnp_set_read_port_address(isapnp_rpa);

		while (1)
		{
			isapnp_select_isolation();

			if (!isapnp_read_id(devices[nDevices].vendor_string,
				&(devices[nDevices].product_id),
				&(devices[nDevices].sn)))
			{
				break;
			}

			isapnp_set_csn(next_csn);
			devices[nDevices].csn = next_csn;
			next_csn++;

			nDevices++;

			if (nDevices >= ISAPNP_MAX_NUM_DEVICES)
			{
				terminal_writestring("ISAPNP: maximum number of cards reached.\n");
				break;
			}

			isapnp_wake(0);				// wake all cards with unconfigured csn
		}

		if (nDevices == 0)
		{
			isapnp_rpa += 4;
		}
	}

	if (nDevices > 0)
	{
		terminal_writestring("ISAPNP: read io port: 0x");
		terminal_hex_word(isapnp_rpa);
		terminal_writestring("\nISAPNP: ");
		terminal_hex_byte(nDevices);
		terminal_writestring("h card(s) detected:\n");

		for (int i = 0; i < nDevices; i++)
		{
			terminal_writestring("ISAPNP: vendor: ");
			terminal_writestring(devices[i].vendor_string);
			terminal_writestring(", product id: 0x");
			terminal_hex_word(devices[i].product_id);
			terminal_writestring(", sn: 0x");
			terminal_hex_dword(devices[i].sn);
			terminal_writestring(", csn: ");
			terminal_hex_byte(devices[i].csn);
			terminal_writestring("h\n");

			// Configure cards
			if (isapnp_read_resource_data(devices[i].csn, 0))
			{
				terminal_writestring("ISAPNP: resource data read successfully!\n");
			}
			else
			{
				terminal_writestring("ISAPNP: reading resource data failed.\n");
			}
		}
	}
	else
	{
		terminal_writestring("ISAPNP: no card detected.\n");
	}

	// leave cards in Wait for Key state
	isapnp_return_to_wait_for_key();
}
