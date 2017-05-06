#ifndef _ISAPNP_H
#define _ISAPNP_H

/* prototypes */
void isapnp_detect(void);

void isapnp_send_initiaition_key(void);
void isapnp_reset(void);
void isapnp_return_to_wait_for_key(void);
void isapnp_wake(uint8_t csn);
void isapnp_set_read_port_address(uint16_t read_port_address);
void isapnp_select_isolation(void);
void isapnp_set_csn(uint8_t csn);
uint8_t isapnp_read_id(char *vendor_string, uint16_t *product_id, uint32_t *sn);
uint8_t isapnp_read_resource_data(uint8_t csn, uint8_t id_read);

 void isapnp_lfsr_shift(uint8_t *byte, uint8_t input);
 void isapnp_delay(void);

#endif /* _ISA_PNP_H */
