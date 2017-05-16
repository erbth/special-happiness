#ifndef _ISAPNP_H
#define _ISAPNP_H

/* type prototypes */
typedef struct _isapnp_device isapnp_device;
typedef struct _isapnp_vendor_id_t isapnp_vendor_id_t;

/* function prototypes */
uint8_t isapnp_detect_configure(void);

void isapnp_send_initiaition_key(void);
void isapnp_reset(void);
void isapnp_return_to_wait_for_key(void);
void isapnp_wake(uint8_t csn);
void isapnp_set_read_port_address(uint16_t read_port_address);
void isapnp_select_isolation(void);
void isapnp_set_csn(uint8_t csn);
uint8_t isapnp_read_id(isapnp_vendor_id_t *vendor_id, uint32_t *sn);
uint8_t isapnp_read_resource_data(isapnp_device *card, uint8_t id_read);
void isapnp_print_resource_data(isapnp_device *card);

 void isapnp_lfsr_shift(uint8_t *byte, uint8_t input);
 void isapnp_delay(void);

#endif /* _ISA_PNP_H */
