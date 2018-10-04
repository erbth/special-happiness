#ifndef NE2000_INTERNAL_H
#define NE2000_INTERNAL_H

#include <stddef.h>
#include <stdint.h>
#include "LinkedQueue.h"
#include "isabus.h"

/* Register addresses */
#define NE_CR_W							0x00
#define NE_CR_R							NE_CR_W

/* Page 0 */
#define NE_PSTART_W						0x01
#define NE_PSTOP_W						0x02
#define NE_CLDA0_R						0x01
#define NE_CLDA1_R						0x02
#define NE_BNRY_W						0x03
#define NE_BNRY_R						NE_BNRY_W
#define NE_ISR_W						0x07
#define NE_ISR_R						0x07
#define NE_RSAR0_W						0x08
#define NE_RSAR1_W						0x09
#define NE_RBCR0_W						0x0A
#define NE_RBCR1_W						0x0B
#define NE_TCR_W						0x0D
#define NE_DCR_W						0x0E
#define NE_IMR_W						0x0F
#define NE_FRAME_ERR_R					0x0D
#define NE_CRC_ERR_R					0x0E
#define NE_MISSED_ERR_R					0x0F

/* Page 1 */
#define NE_CURR_W						0x07
#define NE_CURR_R						0x07

/* Page 2 */
#define NE_PSTART_R						0x01
#define NE_PSTOP_R						0x02
#define NE_CLDA0_W						0x01
#define NE_CLDA1_W						0x02
#define NE_TCR_R						0x0D
#define NE_DCR_R						0x0E
#define NE_IMR_R						0x0F

#define NE_FIFO							0x10

typedef struct _NE2000 NE2000;
struct _NE2000
{
	uint8_t page;
	isabus_device* isadev;
	uint8_t prom[32];
	uint8_t* mac;

	/* Driver's common state */
	uint8_t next__pkt;

	LinkedQueue* recvQueue;
};

/* Prototypes */
void NE2000_select_page(NE2000* ne, uint8_t page);

void NE2000_remoteDMA_sendPacket(NE2000* ne);
void NE2000_remoteDMA_read(NE2000* ne);
void NE2000_remoteDMA_stop(NE2000* ne);
uint8_t NE2000_command_read(NE2000* ne);
void NE2000_command_write(NE2000* ne, const uint8_t val);
uint8_t NE2000_boundary_read(NE2000* ne);
void NE2000_boundary_write(NE2000* ne, const uint8_t val);
uint8_t NE2000_current_read(NE2000* ne);
void NE2000_remoteStartAddress_write(NE2000* ne, const uint16_t addr);
void NE2000_remoteByteCount_write(NE2000* ne, const uint16_t cnt);

/* From assembly */
extern __attribute__((cdecl)) void NE2000_isr_handler(void);

#endif /* NE2000_INTERNAL_H */
