/* see http://wiki.osdev.org/Inline_Assembly/Examples#I.2FO_access */
#include <stddef.h>
#include <stdint.h>

#ifndef _IO_H
#define _IO_H

static inline void outb (uint16_t port, uint8_t val) {
	asm volatile ( "outb %0, %1" : : "a"(val), "Nd"(port) );
}

static inline void outw (uint16_t port, uint16_t val) {
	asm volatile ( "outw %0, %1" : : "a"(val), "Nd"(port) );
}

static inline uint8_t inb (uint16_t port) {
	uint8_t ret;
	asm volatile ( "inb %1, %0" : "=a"(ret) : "Nd"(port) );
	return ret;
}

static inline void kHUP (void)
{
	asm volatile ( "end_%=:\n\thlt\n\tjmp end_%=" : );
}

// terminal
void terminal_putchar (char c);
void terminal_writestring (const char* data);

void terminal_hex_byte(uint8_t byte);
void terminal_hex_word(uint16_t word);
void terminal_hex_dword(uint32_t dword);

#endif /* _IO_H */
