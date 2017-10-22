#ifndef ISR_HANDLERS_H
#define ISR_HANDLERS_H

#include <stdint.h>
#include <stddef.h>

extern __attribute__((cdecl)) void isrh_add_handler(uint32_t address, uint8_t isr_num);

#endif /* ISR_HANDLERS_H */
