/** Ethernet (for use as IOS/OSI layer 2) related functions and data
 * structures. */

#ifndef ETHERNET_H
#define ETHERNET_H

typedef struct _ethernet2_packet ethernet2_packet;
struct _ethernet2_packet
{
	uint8_t macSource[6];
	uint8_t macDestination[6];
	uint16_t type;
	uint16_t dataSize;
	uint8_t* data;
};

/* Function prototypes */
uint16_t ethernet_ntohs(uint16_t netshort);
uint16_t ethernet_htons(uint16_t hostshort);

#endif /* ETHERNET_H */
