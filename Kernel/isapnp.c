/* see http://linux-sxs.org/programming/interfac.html,
 *     https://www.heise.de/ct/artikel/Plug-Play-Hilfe-285966.html,
 *     http://download.microsoft.com/download/1/6/1/161ba512-40e2-4cc9-843a-923143f3456c/PNPISA.rtf */

#include <stdint.h>
#include "isapnp.h"
#include "io.h"
#include <string.h>
#include <util.h>

#define ISAPNP_MAX_NUM_DEVICES 10

#define ISAPNP_ADDRESS 0x279
#define ISAPNP_WRITE   0xA79

// typedefs
typedef struct _isapnp_card_resource_data isapnp_card_resource_data;
typedef struct _isapnp_logical_device_resource_data isapnp_logical_device_resource_data;
typedef struct _isapnp_dependent_function_resource_data isapnp_dependent_function_resource_data;
typedef struct _isapnp_resource_memory_range isapnp_resource_memory_range;
typedef struct _isapnp_resource_memory_range_8_16_bit isapnp_resource_memory_range_8_16_bit;
typedef struct _isapnp_resource_memory_range_32_bit isapnp_resource_memory_range_32_bit;
typedef struct _isapnp_resource_io_port_range isapnp_resource_io_port_range;
typedef struct _isapnp_resource_dma_mask isapnp_resource_dma_mask;
typedef struct _isapnp_resource_irq_mask isapnp_resource_irq_mask;
typedef struct _isapnp_device isapnp_device;
typedef struct _isapnp_vendor_id_t isapnp_vendor_id_t;

// prototypes
void isapnp_select_card(isapnp_device *card);
void isapnp_select_logical_device(uint8_t id);
void isapnp_activate_logical_device(void);
uint8_t isapnp_check_io_port_range_naive(uint16_t base, uint16_t n_ports);
uint8_t isapnp_configure_io_port_range(isapnp_resource_io_port_range *range);
uint8_t isapnp_configure_irq(isapnp_resource_irq_mask *irq_mask);

// structs
struct _isapnp_vendor_id_t
{
	char string[4];
	uint16_t product_id;
};

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
	uint8_t configuration_register;  // location of the corresponding logical device configuration register

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
	struct
	{
		uint8_t fixed : 1;				// IO port range fixed?
		uint8_t full_16_bit : 1;		// if1, the device uses the full 16 bit ISA address,
										// if 0, only ISA address bits[9:0] are decoded.
	} information;

	uint8_t configuration_register;  // location of the corresponding logical device configuration register

	uint16_t minimum_base_address;
	uint16_t maximum_base_address;
	uint8_t base_alignment;			// in 1 byte blocks
	uint8_t number_of_ports;		// number of contiguous I/O ports requested
};

struct _isapnp_resource_dma_mask
{
	uint8_t configuration_register;  // location of the corresponding logical device configuration register

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
	uint8_t configuration_register;  // location of the corresponding logical device configuration register

	uint16_t mask;				// supported IRQs, bit 0 represents IRQ0

	struct
	{
		uint8_t low_true_level_sensitive : 1;	// interrupt driving capabilities
		uint8_t high_true_level_sensitive : 1;
		uint8_t low_true_edge_sensitive : 1;
		uint8_t high_true_edge_sensitive : 1;	// default / must be supported for ISA compatibility
	} information;
};

struct _isapnp_dependent_function_resource_data
{
	uint8_t n_memory_resources;
	uint8_t n_io_port_ranges;

	isapnp_resource_memory_range memory_range[4];
	isapnp_resource_io_port_range io_port_range[8];
	isapnp_resource_dma_mask dma_mask;
	isapnp_resource_irq_mask irq_mask;
};

struct _isapnp_logical_device_resource_data
{
	isapnp_vendor_id_t logical_device_id;

	uint8_t n_compatible_device_ids;
	isapnp_vendor_id_t compatible_device_ids[10];

	uint16_t flags;					// (Byte6 << 8) | Byte5
	char identifier_string[256];	// first 255 characters of the logical device's ansi identifier string

	uint8_t n_memory_resources;
	uint8_t n_io_port_ranges;

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

struct _isapnp_device
{
	isapnp_vendor_id_t vendor_id;
	uint32_t sn;
	uint8_t csn;
	isapnp_card_resource_data resource_data;
};


/**********
* globals *
**********/
static uint16_t isapnp_rpa;
static uint8_t nDevices;
static isapnp_device devices[ISAPNP_MAX_NUM_DEVICES];
static uint8_t next_io_port_configuration_register;
static uint8_t next_interrupt_configuration_register;
static uint8_t resource_data_sum;


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
 * Parameters: vendor_id: a pointer to a isapnp_vendor_id_t
 *             sn:        a pointer to a 32 bit unsigned integer receiving the
 *                        serial number
 * Returns:    1 in case of success, 0 in case of failure or if no card has sent
 *             an id (possibly because no card is on the bus) */
uint8_t isapnp_read_id(isapnp_vendor_id_t *vendor_id, uint32_t *sn)
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

	vendor_id->string[0] = ((id[0] >> 2) & 0x1F) + 'A' - 1;
	vendor_id->string[1] = (((id[1] >> 5) & 0x07) | ((id[0] << 3) & 0x18)) + 'A' - 1;
	vendor_id->string[2] = (id[1] & 0x1F) + 'A' - 1;
	vendor_id->string[3] = 0;

	vendor_id->product_id = id[2] << 8 | id[3];
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

	resource_data_sum += input;				// add to sum of all bytes for
											// checksum verification

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

void isapnp_read_resource_logical_device_identifier(isapnp_device *card, uint16_t *length)
{
	uint8_t dev_id;
	uint8_t in[4];

	if (card->resource_data.n_logical_devices < 4)
	{
		dev_id = card->resource_data.n_logical_devices++;

		// reset next configuration register addresses
		next_io_port_configuration_register = 0x60;
		next_interrupt_configuration_register = 0x70;

		for (int c_in = 0; c_in < 4 && *length > 0; (*length)--)
		{
			in[c_in++] = isapnp_read_resource_byte();
		}

		card->resource_data.logical_devices[dev_id].logical_device_id.string[0] = ((in[0] >> 2) & 0x1F) + 'A' - 1;
		card->resource_data.logical_devices[dev_id].logical_device_id.string[1] = (((in[1] >> 5) & 0x07) | ((in[0] << 3) & 0x18)) + 'A' - 1;
		card->resource_data.logical_devices[dev_id].logical_device_id.string[2] = (in[1] & 0x1F) + 'A' - 1;
		card->resource_data.logical_devices[dev_id].logical_device_id.string[3] = 0;

		card->resource_data.logical_devices[dev_id].logical_device_id.product_id = in[2] << 8 | in[3];

		if (*length > 0)
		{
			card->resource_data.logical_devices[dev_id].flags = isapnp_read_resource_byte();
			(*length)--;
		}

		if (*length > 0)
		{
			card->resource_data.logical_devices[dev_id].flags |= isapnp_read_resource_byte() << 8;
			(*length)--;
		}
	}
	else
	{
		terminal_writestring("ISAPNP: card ");
		terminal_hex_byte(card->csn);
		terminal_writestring("h: too many logical devices.\n");
	}
}

void isapnp_read_resource_compatible_device_id(isapnp_device *card, uint16_t *length)
{
	if (card->resource_data.n_logical_devices > 0)
	{
		isapnp_logical_device_resource_data *dev =
			&(card->resource_data.logical_devices[card->resource_data.n_logical_devices - 1]);

		if (dev->n_compatible_device_ids < 10)
		{
			uint8_t in[4];

			isapnp_vendor_id_t *c_id = &(dev->compatible_device_ids[dev->n_compatible_device_ids++]);

			for (uint8_t i = 0; i < 4 && *length > 0; i++)
			{
				in[i] = isapnp_read_resource_byte();
				(*length)--;
			}

			c_id->string[0] = ((in[0] >> 2) & 0x1F) + 'A' - 1;
			c_id->string[1] = (((in[1] >> 5) & 0x07) | ((in[0] << 3) & 0x18)) + 'A' - 1;
			c_id->string[2] = (in[1] & 0x1F) + 'A' - 1;
			c_id->string[3] = 0;

			c_id->product_id = in[2] << 8 | in[3];
		}
		else
		{
			terminal_writestring("ISAPNP: card ");
			terminal_hex_byte(card->csn);
			terminal_writestring("h: too many compatible device ids\n");
		}
	}
	else
	{
		terminal_writestring("ISAPNP: card ");
		terminal_hex_byte(card->csn);
		terminal_writestring("h: unable to set compatible device id, no logical devices!\n");
	}
}

void isapnp_read_resource_irq_mask(isapnp_device *card, uint16_t *length)
{
	if (card->resource_data.n_logical_devices > 0)
	{
		isapnp_resource_irq_mask *mask =
			&(card->resource_data.logical_devices[card->resource_data.n_logical_devices - 1].irq_mask);

		// assign configuration register address
		mask->configuration_register = next_interrupt_configuration_register;
		next_interrupt_configuration_register += 2;

		if (*length > 2)
		{
			mask->mask = isapnp_read_resource_byte();
			mask->mask |= isapnp_read_resource_byte() << 8;
			*length -= 2;

			if (*length > 0)
			{
				uint8_t info = isapnp_read_resource_byte();

				(*length)--;

				mask->information.low_true_level_sensitive = info & 0x08 ? 1 : 0;
				mask->information.high_true_level_sensitive = info & 0x04 ? 1 : 0;
				mask->information.low_true_edge_sensitive = info & 0x02 ? 1 : 0;
				mask->information.high_true_edge_sensitive = info & 0x01 ? 1 : 0;
			}
			else
			{
				mask->information.low_true_level_sensitive = 0;
				mask->information.high_true_level_sensitive = 0;
				mask->information.low_true_edge_sensitive = 0;
				mask->information.high_true_edge_sensitive = 1;
			}
		}
	}
	else
	{
		terminal_writestring("ISAPNP: card ");
		terminal_hex_byte(card->csn);
		terminal_writestring("h: store IRQ mask: no logical devices!\n");
	}
}

void isapnp_read_resource_io_port_descriptor(isapnp_device *card, uint16_t *length)
{
	if (card->resource_data.n_logical_devices > 0)
	{
		isapnp_logical_device_resource_data *dev =
			&(card->resource_data.logical_devices[card->resource_data.n_logical_devices - 1]);

		if (dev->n_io_port_ranges < 8)
		{
			isapnp_resource_io_port_range *range =
				&(dev->io_port_range[dev->n_io_port_ranges++]);

			// not a fixed descriptor
			range->information.fixed = 0;

			// assign configuration register location
			range->configuration_register = next_io_port_configuration_register;
			next_io_port_configuration_register += 2;

			// check length once
			if (*length < 7)
			{
				return;
			}

			range->information.full_16_bit =
				(isapnp_read_resource_byte() & 0x01) ? 1 : 0;

			range->minimum_base_address = isapnp_read_resource_byte();
			range->minimum_base_address |= isapnp_read_resource_byte() << 8;
			range->maximum_base_address = isapnp_read_resource_byte();
			range->maximum_base_address |= isapnp_read_resource_byte() << 8;
			range->base_alignment = isapnp_read_resource_byte();
			range->number_of_ports = isapnp_read_resource_byte();

			*length -= 7;
		}
		else
		{
			terminal_writestring("ISAPNP: card ");
			terminal_hex_byte(card->csn);
			terminal_writestring("h: too many io port ranges\n");
		}
	}
	else
	{
		terminal_writestring("ISAPNP: card ");
		terminal_hex_byte(card->csn);
		terminal_writestring("h: store io port range: no logical devices!\n");
	}
}

/* returns:    1 if the checksum matches, 0 otherwise */
uint8_t isapnp_read_resource_end_tag(isapnp_device *card, uint16_t *length)
{
	if (*length >= 1)
	{
		uint8_t prev_sum = resource_data_sum;
		uint8_t checksum = isapnp_read_resource_byte();

		(*length)--;

		if (checksum == 0 || resource_data_sum == 0)
		{
			return 1;
		}
		else
		{
			terminal_writestring("ISAPNP: card ");
			terminal_hex_byte(card->csn);
			terminal_writestring("h: checksum mismatch: 0x");
			terminal_hex_byte(checksum);
			terminal_writestring(" (checksum) != 0x");
			terminal_hex_byte(prev_sum);
			terminal_writestring(" (sum of received bytes)\n");
		}
	}

	return 0;
}

void isapnp_read_resource_ansi_string(isapnp_device *card, uint16_t *length)
{
	int pos = 0;
	char *id_string;

	if (card->resource_data.n_logical_devices <= 0)
	{
		id_string = card->resource_data.identifier_string;
	}
	else
	{
		id_string = card->resource_data.logical_devices[card->resource_data.n_logical_devices - 1].identifier_string;
	}

	while ((pos < 255) && (*length > 0))
	{
		id_string[pos++] = isapnp_read_resource_byte();
		(*length)--;
	}

	id_string[pos] = 0;
}

/* Function:   isapnp_read_resource_data
 * Purpose:    to read a card's reasource data
 * Parameters: card:    a pointer to an isapnp_device,
 *             id_read: if != 0, the 72 bit card in has already been read,
 *                      if 0, it has not
 * Returns:    0 in case of failure, 1 otherwise */
uint8_t isapnp_read_resource_data(isapnp_device *card, uint8_t id_read)
{
	uint8_t input;
	uint8_t end_reached = 0;

	if (card == NULL)
	{
		return 0;
	}

	// initialize certain variables
	card->resource_data.n_logical_devices = 0;  // actually not required because of memset ...

	// wake card and put others to sleep
	isapnp_wake(card->csn);

	if (id_read == 0)
	{
		// read 72 bit card id (put it to trash as it isn't needed, it is already known)
		for (int i = 0; i < 9; i++)
		{
			isapnp_read_resource_byte();
		}
	}

	// The checksum covers all data after the serial identifier, thus reset the
	// computed sum here
	resource_data_sum = 0;

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

		switch (resource_id)
		{
		case 0x01:
			isapnp_read_resource_pnp_version(card, &length);
			break;

		case 0x02:
			if (card->resource_data.n_logical_devices >= 4)
			{
				terminal_writestring("ISAPNP: card ");
				terminal_hex_byte(card->csn);
				terminal_writestring("h: too many logical devices\n");
				return 0;
			}

			isapnp_read_resource_logical_device_identifier(card, &length);
			break;

		case 0x03:
			isapnp_read_resource_compatible_device_id(card, &length);
			break;

		case 0x04:
			isapnp_read_resource_irq_mask(card, &length);
			break;

		case 0x08:
			isapnp_read_resource_io_port_descriptor(card, &length);
			break;

		case 0x0F:
			if (isapnp_read_resource_end_tag(card, &length))
			{
				end_reached = 1;
			}
			break;

		case 0x82:
			isapnp_read_resource_ansi_string(card, &length);
			break;

		default:
			terminal_writestring("ISAPNP: card ");
			terminal_hex_byte(card->csn);
			terminal_writestring(": unknown resource id: 0x");
			terminal_hex_byte(resource_id);
			terminal_putchar('\n');
			return 0;
		}

		if (length != 0)
		{
			terminal_writestring("ISAPNP: card ");
			terminal_hex_byte(card->csn);
			terminal_writestring("h: resource id: 0x");
			terminal_hex_byte(resource_id);
			terminal_writestring(": length (");
			terminal_hex_word(length);
			terminal_writestring("h) != 0\n");
		}

	} while (!end_reached);

	return 1;
}

/* Function:   isapnp_print_resource_data
 * Purpose:    to print the read resource data of a specific card on the terminal
 * Parameters: card: a pointer to an isapnp_device */
void isapnp_print_resource_data(isapnp_device *card)
{
	if (card)
	{
		isapnp_card_resource_data *res_data = &(card->resource_data);

		terminal_writestring("ISAPNP: pnp version number: ");
		terminal_hex_byte(res_data->pnp_version_number);

		terminal_writestring("h\n"
							 "ISAPNP: identifier string:  ");
		terminal_writestring(res_data->identifier_string);

		for (int i = 0; i < res_data->n_logical_devices; i++)
		{
			isapnp_logical_device_resource_data *dev = &(res_data->logical_devices[i]);

			terminal_writestring("\nISAPNP: logical device #");
			terminal_hex_byte(i);

			terminal_writestring("h\n"
								 "ISAPNP:   vendor string:      ");
			terminal_writestring(dev->logical_device_id.string);
			terminal_writestring(", product identifier: 0x");
			terminal_hex_word(dev->logical_device_id.product_id);

			for (int j = 0; j < dev->n_compatible_device_ids; j++)
			{
				terminal_writestring("h\n"
									 "ISAPNP:   compatible vendor string: ");
				terminal_writestring(dev->compatible_device_ids[j].string);
				terminal_writestring(", product identifier: 0x");
				terminal_hex_word(dev->compatible_device_ids[j].product_id);
			}

			if (dev->identifier_string[0] != 0)
			{
				terminal_writestring("\n"
									 "ISAPNP:   identifier string:  ");
				terminal_writestring(dev->identifier_string);
			}

			for (int j = 0; j < dev->n_io_port_ranges; j++)
			{
				isapnp_resource_io_port_range *range = &(dev->io_port_range[j]);

				terminal_writestring("\n"
					"ISAPNP:   io port range: 0x");
				terminal_hex_word(range->minimum_base_address);
				terminal_writestring("-0x");
				terminal_hex_word(range->maximum_base_address);
				terminal_writestring(" (#=");
				terminal_hex_byte(range->number_of_ports);
				terminal_writestring("h, aligned to ");
				terminal_hex_byte(range->base_alignment);
				terminal_writestring("h, config: 0x");
				terminal_hex_byte(range->configuration_register);
				terminal_putchar(')');

				if (range->information.fixed)
				{
					terminal_writestring(" fixed");
				}

				if (range->information.full_16_bit)
				{
					terminal_writestring(" full-16-bit");
				}
			}

			/* IRQ mask */
			terminal_writestring("\n"
								 "ISAPNP:   IRQ mask:           0x");
			terminal_hex_word(dev->irq_mask.mask);

			if (dev->irq_mask.information.low_true_level_sensitive ||
				dev->irq_mask.information.low_true_edge_sensitive)
			{
				terminal_writestring(" low true");
			}
			else
			{
				terminal_writestring(" high true");
			}

			if (dev->irq_mask.information.low_true_level_sensitive ||
				dev->irq_mask.information.high_true_level_sensitive)
			{
				terminal_writestring(" level sensitive");
			}
			else
			{
				terminal_writestring(" edge sensitive");
			}

			terminal_writestring(" (config: 0x");
			terminal_hex_byte(dev->irq_mask.configuration_register);
			terminal_putchar(')');
		}

		terminal_putchar('\n');
	}
}


/* Function:   isapnp_select_card
 * Purpose:    to put a specific card into the configure state
 * Parameters: card [IN]: a pointer to the specific card's isapnp_device */
void isapnp_select_card(isapnp_device *card)
{
	isapnp_wake(card->csn);
}

/* Function:   isapnp_select_logical_device
 * Purpose:    to select a logical device on the card which is currently in
 *             configure state
 * Parameters: id [IN]: the logical device's id */
void isapnp_select_logical_device(uint8_t id)
{
	outb(ISAPNP_ADDRESS, 0x07);		// logical device number register
	outb(ISAPNP_WRITE, id);
}

/* Function:   isapnp_activate_logical_device
 * Purpose:    to activate the currently selected device of the card which is
 *             currently in configure state for the ISA bus. This will disable
 *             I/O range check on the particular card.
 * Parameters: none */
void isapnp_activate_logical_device(void)
{
	outb(ISAPNP_ADDRESS, 0x31);		// I/O Range Check register
	outb(ISAPNP_WRITE, 0);			// disable I/O range check

	outb(ISAPNP_ADDRESS, 0x30);		// Activate register
	outb(ISAPNP_WRITE, 0x01);		// activate device
}

/* Function:   isapnp_check_io_port_range_naive
 * Purpose:    to check whether an io port range is free in a naive way
 *             without using an ISA PNP logical device's I/O range check
 *             function (to avoid obvious conflicts).
 * Parameters: base [IN]:    base I/O port
 *             n_ports [IN]: count of ports in the range to check
 * Returns:    1 if the I/O port range seems free, 0 otherwise */
uint8_t isapnp_check_io_port_range_naive(uint16_t base, uint16_t n_ports)
{
	for (uint16_t port = base; port < (base + n_ports); port++)
	{
		for (int i = 0; i < 10; i++)
		{
			// "quick and dirty"
			if (inb(port) != 0xFF)
			{
				return 0;
			}
		}
	}

	// the otherway round ...
	for (int i = 0; i < 10; i++)
	{
		for (uint16_t port = base; port < (base + n_ports); port++)
		{
			// "quick and dirty"
			if (inb(port) != 0xFF)
			{
				return 0;
			}
		}
	}

	return 1;
}

/* Function:   isapnp_configure_io_port_range
 * Purpose:    to configure one of the currently selected logical device's io port
 *             ranges to free ports
 * Parameters: range [IN]: a pointer to an isapnp_resource_io_port_range
 * Returns:    1 on success, 0 on failure */
uint8_t isapnp_configure_io_port_range(isapnp_resource_io_port_range *range)
{
	uint16_t base_port;

	// it might be a good idea to start above 0x279 ...
	// (see http://wiki.osdev.org/Ne2000#Ne2000_Registers)
	base_port = MAX(0x280, range->minimum_base_address);

	// enforce alignment
	if ((base_port % range->base_alignment) != 0)
	{
		base_port += range->base_alignment - (base_port % range->base_alignment);
	}

	// currently, configure only to port 0x280
	for (; base_port <= 0x280 /* range->maximum_base_address */; base_port += range->base_alignment)
	{
		terminal_hex_word(base_port);
		terminal_putchar('\n');

		if (isapnp_check_io_port_range_naive(base_port, range->number_of_ports))
		{
			// configure high byte
			outb(ISAPNP_ADDRESS, range->configuration_register);
			outb(ISAPNP_WRITE, (base_port >> 8) & 0xFF);

			// configure low byte
			outb(ISAPNP_ADDRESS, range->configuration_register + 1);
			outb(ISAPNP_WRITE, base_port & 0xFF);

			terminal_writestring("ISAPNP: configured I/O port range to 0x");
			terminal_hex_word(base_port);
			terminal_writestring(" (");
			terminal_hex_byte(range->number_of_ports);
			terminal_writestring("h ports)\n");
			return 1;
		}
	}

	return 0;
}

/* Function:   isapnp_configure_irq
 * Purpose:    to configure one of the currently selected logical device's IRQ
 *             to a free IRQ
 * Parameters: irq_mask [IN]: a pointer to an isapnp_resource_irq_mask
 * Returns:    1 on success, 0 on failure */
 uint8_t isapnp_configure_irq(isapnp_resource_irq_mask *irq_mask)
 {
	 // currently, this is implemented trivially, it configures any irq to irq 5
	 // or returns with failure if irq 5 is not supported.

	 if (irq_mask->mask & (1 << 5))
	 {
		 if (irq_mask->information.high_true_edge_sensitive)
		 {
			 // interrupt level
			 outb(ISAPNP_ADDRESS, irq_mask->configuration_register);
			 outb(ISAPNP_WRITE, 5);

			 // type
			 outb(ISAPNP_ADDRESS, irq_mask->configuration_register + 1);
			 outb(ISAPNP_WRITE, 0b10);		// high true, edge sensitive

			 terminal_writestring("ISAPNP: configured IRQ 5\n");
		 }
		 else
		 {
			 terminal_writestring("ISAPNP: configure IRQ: high true/edge sensitive not supported\n");
			 return 0;
		 }
	 }
	 else
	 {
		 terminal_writestring("ISAPNP: configure IRQ: IRQ 5 not supported\n");
		 return 0;
	 }

	 return 1;
 }


uint8_t isapnp_configure_ne2000(isapnp_device *card, uint8_t logical_device_id)
{
	isapnp_logical_device_resource_data *dev;

	if (!card || logical_device_id >= card->resource_data.n_logical_devices)
	{
		return 0;
	}

	dev = &(card->resource_data.logical_devices[logical_device_id]);

	isapnp_select_card(card);
	isapnp_select_logical_device(logical_device_id);

	if (dev->n_io_port_ranges > 0)
	{
		if (!isapnp_configure_io_port_range(&(dev->io_port_range[0])))
		{
			terminal_writestring("ISAPNP: NE2000 ");
			terminal_hex_byte(card->csn);
			terminal_writestring("h: configuring io port range failed\n");
			return 0;
		}
	}

	if (!isapnp_configure_irq(&(dev->irq_mask)))
	{
		terminal_writestring("ISAPNP: NE2000 ");
		terminal_hex_byte(card->csn);
		terminal_writestring("h: configuring irq failed\n");
		return 0;
	}

	terminal_writestring("ISAPNP: NE2000 with CSN ");
	terminal_hex_byte(card->csn);
	terminal_writestring("h/logical device id ");
	terminal_hex_byte(logical_device_id);
	terminal_writestring("h configured.\n");

	return 1;
}

/* Function:   isapnp_detect_configure
 * Purpose:    to detect and configure ISA PNP cards
 * Parameters: none
 * Returns:    0 in case of failure, 1 in case of success */
uint8_t isapnp_detect_configure(void)
{
	uint8_t next_csn;

	// initialize global card table
	nDevices = 0;
	memset(devices, 0, sizeof(devices));

	isapnp_send_initiation_key();	// cards have to be resetted before read port change
	isapnp_reset_csns();
	isapnp_reset_configuration();

	next_csn = 1;

	for (isapnp_rpa = 0x203; nDevices == 0 && isapnp_rpa <= 0x3FF;)
	{
		isapnp_wake(0);				// wake all cards with unconfigured csn
		isapnp_set_read_port_address(isapnp_rpa);

		while (1)
		{
			isapnp_select_isolation();

			if (!isapnp_read_id(&(devices[nDevices].vendor_id),
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
			terminal_writestring(devices[i].vendor_id.string);
			terminal_writestring(", product id: 0x");
			terminal_hex_word(devices[i].vendor_id.product_id);
			terminal_writestring(", sn: 0x");
			terminal_hex_dword(devices[i].sn);
			terminal_writestring(", csn: ");
			terminal_hex_byte(devices[i].csn);
			terminal_writestring("h\n");

			// Configure cards
			if (!isapnp_read_resource_data(&(devices[i]), 0))
			{
				terminal_writestring("ISAPNP: reading resource data failed.\n");
				return 0;
			}

			isapnp_print_resource_data(&(devices[i]));

			for (int j = 0; j < devices[i].resource_data.n_logical_devices; j++)
			{
				isapnp_logical_device_resource_data *dev =
					&(devices[i].resource_data.logical_devices[j]);

				// If it is a NE2000, configure it (roudimentary)
				if (memcmp(dev->logical_device_id.string, "PNP", 3) == 0 &&
					dev->logical_device_id.product_id == 0x80d6)
				{
					if (!isapnp_configure_ne2000(&(devices[i]), j))
					{
						return 0;
					}
				}
				else
				{
					for (int k = 0; k < dev->n_compatible_device_ids; k++)
					{
						if (memcmp(dev->compatible_device_ids[k].string, "PNP", 3) == 0 &&
							dev->compatible_device_ids[k].product_id == 0x80d6)
						{
							if (!isapnp_configure_ne2000(&(devices[i]), j))
							{
								return 0;
							}
							break;
						}
					}
				}
			}
		}
	}
	else
	{
		terminal_writestring("ISAPNP: no card detected.\n");
	}

	// leave cards in Wait for Key state
	isapnp_return_to_wait_for_key();
	return 1;
}
