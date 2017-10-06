/* Simple implementation of some of the standard I/O functions like printf */
#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdbool.h>
#include "stdio.h"
#include "util.h"
#include "string.h"

#define PRINTF_MAX_LENGTH 255

/* Static prototypes */
static void terminal_newline(void);


/* Function:   printf_handle_fmt_hex32
 * Purpose:    to append an 32 bit int in hexadecimal representation to printf's
 *             buffer. Helper function for printf.
 * Parameters: buffer: Pointer to the destination buffer
 *             pCnt:   Pointer to the variable maintaining the current character
 *                     count in the destination buffer.
 *             val:    Value value to append */
static void printf_handle_fmt_hex32(char* buffer, int* pCnt, uint32_t val)
{
	if (*pCnt + 8 <= PRINTF_MAX_LENGTH)
	{
		for (int i = 0; i < 8; i++)
		{
			char c = ((val & 0xF0000000) >> 28) + '0';

			if (c > '9')
				c += 'a' - '9' - 1;

			buffer[(*pCnt)++] = c;
			val <<= 4;
		}
	}
}

/* Function:   printf_handle_fmt_p
 * Purpose:    to append a pointer to printf's buffer. Helper function for
 *             printf.
 * Parameters: buffer: Pointer to the destination buffer
 *             pCnt:   Pointer to the variable maintaining the current character
 *                     count in the destination buffer.
 *             ptr:    Pointer value to append */
static void printf_handle_fmt_p(char* buffer, int* pCnt, void* ptr)
{
	if (ptr)
	{
		if (*pCnt + 2 <= PRINTF_MAX_LENGTH)
		{
			buffer[(*pCnt)++] = '0';
			buffer[(*pCnt)++] = 'x';
			printf_handle_fmt_hex32(buffer, pCnt, (intptr_t) ptr);
		}
	}
	else
	{
		if (*pCnt + 3)
		{
			buffer[(*pCnt)++] = 'n';
			buffer[(*pCnt)++] = 'i';
			buffer[(*pCnt)++] = 'l';
		}
	}
}

/* Function:   printf_handle_fmt_
 * Purpose:    to append an integer in hexadecimal representation to
 *             printf's buffer. Helper function for printf.
 * Parameters: buffer: Pointer to the destination buffer
 *             pCnt:   Pointer to the variable maintaining the current character
 *                     count in the destination buffer.
 *             val:    Integer value to be appended. */
static void printf_handle_fmt_x(char* buffer, int* pCnt, int val)
{
	printf_handle_fmt_hex32(buffer, pCnt, val);
}

/* Function:   printf_handle_fmt_lx
 * Purpose:    to append a long integer in hexadecimal representation to
 *             printf's buffer. Helper function for printf.
 * Parameters: buffer: Pointer to the destination buffer
 *             pCnt:   Pointer to the variable maintaining the current character
 *                     count in the destination buffer.
 *             val:    Long integer value to be appended. */
static void printf_handle_fmt_lx(char* buffer, int* pCnt, long val)
{
	// currently, sizeof(long) == sizeof(int)
	printf_handle_fmt_hex32(buffer, pCnt, val);
}

/* Function:   printf_handle_fmt_llx
 * Purpose:    to append a long long integer in hexadecimal representation to
 *             printf's buffer. Helper function for printf.
 * Parameters: buffer: Pointer to the destination buffer
 *             pCnt:   Pointer to the variable maintaining the current character
 *                     count in the destination buffer.
 *             val:    Long integer value to be appended. */
static void printf_handle_fmt_llx(char* buffer, int* pCnt, long long val)
{
	printf_handle_fmt_hex32(buffer, pCnt, (uint32_t) ((val >> 32) & 0xFFFFFFFF));
	printf_handle_fmt_hex32(buffer, pCnt, (uint32_t) (val & 0xFFFFFFFF));
}

/* Function:   printf_handle_fmt_s
 * Purpose:    to append a zero-terminated (C) string to printf's buffer.
 *             Helper function for printf.
 * Parameters: buffer: Pointer to the destination buffer
 *             pCnt:   Pointer to the variable maintaining the current character
 *                     count in the destination buffer.
 *             s:      Pointer to the string */
static void printf_handle_fmt_s(char* buffer, int*pCnt, const char* s)
{
	if (s)
	{
		while (*s != '\0' && *pCnt < PRINTF_MAX_LENGTH)
			buffer[(*pCnt)++] = *s++;
	}
}

/* Function:   printf_handle_fmt_d
 * Purpose:    to append an integer value in decimal representation to printf's
 *             buffer. Helper function for printf.
 * Parameters: buffer: Pointer to the destination buffer
 *             pCnt:   Pointer to the variable maintaining the current character
 *                     count in the destination buffer.
 *             val:    The integer value */
static void printf_handle_fmt_d(char* buffer, int* pCnt, int val)
{
	int significance = 1000000000;

	/* Signum */
	if (val < 0)
	{
		if (*pCnt < PRINTF_MAX_LENGTH)
		{
			buffer[(*pCnt)++] = '-';
		}
		else
		{
			return;
		}
	}

	bool leading_zero = true;

	/* Number */
	while (significance > 0)
	{
		int digit = val / significance;
		if (digit < 0)
			digit *= -1;

		if (digit != 0 || !leading_zero || significance == 1)
		{
			digit += '0';
			leading_zero = false;

			if (*pCnt < PRINTF_MAX_LENGTH)
				buffer[(*pCnt)++] = (char) digit & 0xFF;
			else
				return;
		}

		val %= significance;
		significance /= 10;
	}
}

/* Function:   printf_handle_fmt_spec
 * Purpose:    to handle a format specifier, helper function for printf
 * Parameters: buffer: Pointer to the destination buffer
 *             pCnt:   Pointer to the variable maintaining the current character
 *                     count in the destination buffer.
 *             pp:     Address of the pointer to the format string
 *             argpp:  Address of va_list with for arguments */
static void printf_handle_fmt_spec(
	char* buffer,
	int* pCnt,
	const char** pp,
	va_list* argpp)
{
	char width_specifier1 = '\0';
	char width_specifier2 = '\0';

	if (!buffer || !pCnt || !pp || !argpp)
		return;

	/* Width specifiers */
	if (**pp == 'l')
	{
		(*pp)++;
		width_specifier1 = 'l';
	}

	if (*pp == '\0')
		return;

	if (**pp == 'l')
	{
		(*pp)++;
		width_specifier2 = 'l';
	}

	/* Actual format */
	if (*pp == '\0')
		return;

	switch (**pp)
	{
		case 'p':
			printf_handle_fmt_p(buffer, pCnt, va_arg(*argpp, void *));
			break;

		case 'X':
		case 'x':
			if (width_specifier1 == 'l' && width_specifier2 == 'l')
				printf_handle_fmt_llx(buffer, pCnt, va_arg(*argpp, long long));
			else if (width_specifier1 == 'l')
				printf_handle_fmt_lx(buffer, pCnt, va_arg(*argpp, long));
			else
				printf_handle_fmt_x(buffer, pCnt, va_arg(*argpp, int));
			break;

		case 's':
			printf_handle_fmt_s(buffer, pCnt, va_arg(*argpp, const char*));
			break;

		case 'd':
			printf_handle_fmt_d(buffer, pCnt, va_arg(*argpp, int));
			break;

		case '%':
			buffer[(*pCnt)++] = '%';
			break;

		default:
			break;
	}
}


/* Function:   printf
 * Purpose:    to print a formated text to the console. The printed text may not
 *             be longer than PRINTF_MAX_LENGTH characters, excluding the
 *             terminating 0.
 * Parameters: format: Format string
 *             ...:    Format arguments
 * Returns:    The count of characters printed, esxcluding the terminating 0. */
int printf(const char* format, ...)
{
	int cnt = 0;
	char buffer[PRINTF_MAX_LENGTH + 1];
	va_list argp;

	va_start(argp, format);

	for (const char* p = format; *p != '\0'; p++)
	{
		switch (*p)
		{
			case '%':
				p++;
				printf_handle_fmt_spec(buffer, &cnt, &p, &argp);
				break;

			default:
				buffer[cnt++] = *p;
				break;
		}

		if (cnt >= PRINTF_MAX_LENGTH)
			break;
	}

	va_end(argp);

	cnt = MIN(cnt, PRINTF_MAX_LENGTH);
	buffer[cnt] = 0;

	terminal_writestring(buffer);
	return cnt;
}


/**********************************
******* Terminal interaction ******
**********************************/
static const size_t VGA_WIDTH = 80;
static const size_t VGA_HEIGHT = 25;

extern uint8_t terminal_row;
extern uint8_t terminal_column;
uint8_t terminal_color;
uint16_t* terminal_buffer;

static inline uint8_t vga_entry_color (enum vga_color fg, enum vga_color bg) {
	return fg | bg << 4;
}

static inline uint16_t vga_entry (unsigned char uc, uint8_t color) {
	return (uint16_t) uc | (uint16_t) color << 8;
}

void terminal_initialize (void) {
	terminal_row = 0;
	terminal_column = 0;
	terminal_color = vga_entry_color (VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
	terminal_buffer = (uint16_t*) 0xB8000;

	for (size_t y = 0; y < VGA_HEIGHT; ++y) {
		for (size_t x = 0; x < VGA_WIDTH; ++x) {
			const size_t index = y * VGA_WIDTH + x;
			terminal_buffer[index] = vga_entry (' ', terminal_color);
		}
	}
}

void terminal_setcolor (uint8_t color) {
	terminal_color = color;
}

static void terminal_putentryat (char c, uint8_t color, size_t x, size_t y) {
	const size_t index = y * VGA_WIDTH + x;
	terminal_buffer[index] = vga_entry (c, color);
}

void terminal_putchar (char c) {
	if (c == '\n')
	{
		terminal_newline();
	}
	else
	{
		terminal_putentryat (c, terminal_color, terminal_column, terminal_row);

		if (++terminal_column == VGA_WIDTH) {
			terminal_newline();
		}
	}
}

void terminal_write (const char* data, size_t size) {
	for (size_t i = 0; i < size; ++i) {
		terminal_putchar (data[i]);
	}
}

void terminal_writestring (const char* data) {
	terminal_write (data, strlen (data));
}

void terminal_hex_byte(uint8_t byte)
{
	char first_digit = (byte >> 4) + '0';
	char last_digit = (byte & 0x0F) + '0';

	if (first_digit > '9')
	{
		first_digit += 'A' - '9' - 1;
	}

	if (last_digit > '9')
	{
		last_digit += 'A' - '9' - 1;
	}

	terminal_putchar(first_digit);
	terminal_putchar(last_digit);
}

void terminal_hex_word(uint16_t word)
{
	terminal_hex_byte((uint8_t) ((word >> 8) & 0xFF));
	terminal_hex_byte((uint8_t) (word & 0xFF));
}

void terminal_hex_dword(uint32_t dword)
{
	terminal_hex_word((uint16_t) ((dword >> 16) & 0xFFFF));
	terminal_hex_word((uint16_t) (dword & 0xFFFF));
}

static void terminal_newline(void)
{
	terminal_column = 0;

	if (terminal_row < VGA_HEIGHT - 1)
	{
		terminal_row++;
	}
	else
	{
		/* Scroll one line up */
		for (size_t i = 0; i < (VGA_HEIGHT - 1) * VGA_WIDTH; i++)
			terminal_buffer[i] = terminal_buffer[i + VGA_WIDTH];

		/* Clear last row */
		for (uint8_t x = 0; x < VGA_WIDTH; x++)
			terminal_putentryat(' ', terminal_color, x, VGA_HEIGHT - 1);
	}
}
