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

/* Function:   memcmp
 * Purpose:    to compare to areas in memory like traditional memcmp
 * Parameters: s1 [IN]: memory area 1
 *             s2 [IN]: memory area 2
 *             n [IN]:  number of bytes to compare
 * Returns:    an integer less than, equal to or greater than 0, if the first n
 *             bytes of s1 are less than, equal to or greater than the bytes of
 *             s2 */
int memcmp(const void *s1, const void *s2, size_t n)
{
	if (s1 != NULL && s2 != NULL)
	{
		while (n-- > 0)
		{
			if (*((uint8_t *) s1++) != *((uint8_t *) s2++))
			{
				return *((uint8_t *) s1 - 1) - *((uint8_t *) s2 - 1);
			}
		}

		return 0;
	}
	else
	{
		return s1 == NULL ? (s2 == NULL ? 0 : -1) : 1;
	}
}


/* Function:   strcpy
 * Purpose:    to copy zero terminated strings like traditional strcpy
 * Parameters: dest [OUT]: destinaiton buffer
 *             src [IN]:   source buffer
 * Returns:    a pointer to the destination string dest */
char * strcpy(char *dest, const char *src)
{
	if (dest != NULL && src != NULL)
	{
		while (*src != 0)
		{
			*dest++ = *src++;
		}
	}

	return dest;
}


/* Function:   strlen
 * Purpose:    to examine the length of a zero terminated (C) string.
 * Parameters: str: The string
 * Returns:    The length of the string */
size_t strlen (const char* str) {
	size_t len = 0;
	while (str[len]) {
		len++;
	}
	return len;
}
