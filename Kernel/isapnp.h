#ifndef _ISAPNP_H
#define _ISAPNP_H

/* prototypes */
void isapnp_detect(void);

void isapnp_send_initiaition_key(void);
void isapnp_reset_csns(void);
void isapnp_wake(uint8_t csn);
void isapnp_set_read_port_address(uint16_t read_port_address);
void isapnp_select_isolation(void);
void isapnp_set_csn(uint8_t csn);
uint8_t isapnp_read_id(uint8_t *id);

#endif /* _ISA_PNP_H */
