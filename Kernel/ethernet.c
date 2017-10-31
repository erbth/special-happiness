#include "stdio.h"
#include "ethernet.h"

/* Function:   ethernet_ntohs
 * Purpose:    to convert a 16 byte value from network to host byte ordering.
 * Parameters: netshort [IN]: The network like ordered 16 bit word.
 * Returns:    The host like ordered 16 bit word. */
uint16_t ethernet_ntohs(uint16_t netshort)
{
	/* x86 is little endian, ethernet big endian */
	return ((netshort >> 8) & 0xFF) | ((netshort << 8) & 0xFF00);
}

/* Function:   ethernet_htons
 * Purpose:    to convert a 16 byte value from host to network byte ordering.
 * Parameters: hostshort [IN]: The host like ordered 16 bit word.
 * Returns:    The network like ordered 16 bit word. */
uint16_t ethernet_htons(uint16_t hostshort)
{
	/* x86 is little endian, ethernet big endian */
	return ((hostshort >> 8) & 0xFF) | ((hostshort << 8) & 0xFF00);
}
