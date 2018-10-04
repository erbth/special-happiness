#include "stdio.h"
#include "ethernet.h"
#include "ARP.h"

/* Function:   ARP_in
 * Purpose:    to handle incoming ethernet II packets which are destinied to
 *             the ARP.
 * Paramters: pkt [IN]: A pointer to the incoming packet.
 * Returns:   -1 in case of failure, 0 otherwise. */
int ARP_in(ethernet2_packet* pkt)
{
	if (pkt)
	{
		if (ethernet_ntohs(((uint16_t*) pkt->data)[0]) &&
			ethernet_ntohs(((uint16_t*) pkt->data)[1]))
		{
			/* It is a MAC to IPv4 resolution */
			if (pkt->data[4] == 6 && pkt->data[5] == 4)
			{
				uint16_t operation = ethernet_ntohs(((uint16_t*) pkt->data)[3]);
				if (operation == 1)
				{
					printf ("ARP: Who has %d.%d.%d.%d? Tell ",
						(int) pkt->data[24],
						(int) pkt->data[25],
						(int) pkt->data[26],
						(int) pkt->data[27]);

					for (int i = 0; i < 5; i++)
					{
						terminal_hex_byte(pkt->data[8 + i]);
						terminal_putchar(':');
					}
					terminal_hex_byte(pkt->data[13]);

					printf(" (%d.%d.%d.%d)\n",
						(int) pkt->data[14],
						(int) pkt->data[15],
						(int) pkt->data[16],
						(int) pkt->data[17]);
				}
				else if (operation == 2)
				{
					printf("ARP: response received\n");
				}
				else
				{
					printf("ARP: Invalid operation.\n");
				}
			}
			else
			{
				printf("ARP: MAC to IPv4: Address sizes do not match the expected ones.\n");
			}
		}

		/* Free packet */
		kfree(pkt->data);
		kfree(pkt);
		return 0;
	}
	return -1;
}
