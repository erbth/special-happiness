#include <stddef.h>
#include <stdint.h>

/* Function:   memset
 * Purpose:    to set the memory cells at a specific location to a specific value,
 *             this implements the traditional memset.
 * Parameters: s: memory location
 *             c: byte value to set
 *             n: size of memory location
 * Returns:    a pointer to the memory area s */
void *memset(void *s, int c, size_t n)
{
	void *s_initial = s;

	while (n-- > 0)
	{
		*((uint8_t *)s) = c;
		s++;
	}
	return s_initial;
}
