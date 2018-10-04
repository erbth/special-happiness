#include "stdio.h"
#include "ethernet.h"
#include "isoosi/layer3.h"
#include "ARP.h"

/* Function:   layer3_in
 * Purpose:    to dispatch ethernet 2 packets from layer 2 into the networking
 *             layer.
 * Parameters: pkt [IN]: The ethernet 2 packet to dispatch.
 * Returns:    -1 in case of failure, 0 otherwise. */
int layer3_in(ethernet2_packet* pkt)
{
	if (!pkt)
		return -1;


	switch (pkt->type)
	{
		case 0x800:
			kfree(pkt->data);
			kfree(pkt);
			break;

		case 0x806:
			return ARP_in(pkt);
			break;

		default:
			printf ("Unknown ethernet 2 frame type: 0x%x\n", (int) pkt->type);
			kfree(pkt->data);
			kfree(pkt);
			break;
	}
	return 0;
}
