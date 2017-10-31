#ifndef ARP_H
#define ARP_H

#include <stddef.h>
#include <stdint.h>
#include "ethernet.h"

/* Function prototypes */
int ARP_in(ethernet2_packet* pkt);

#endif /* ARP_H */
