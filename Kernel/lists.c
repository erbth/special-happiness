/* sequential data structures (lists) */
#include <stddef.h>
#include <stdint.h>

/* dynamic array implementing list */
struct array_list
{
	void **array;		// array of void pointers
	size_t size;		// size
	size_t w;			// number of places occupied, starting from the front
};

/* Function:   array_list_new
 * Purpose:    to create a new array list, initial size: 2
 * Parameters: none
 * Returns:    a pointer to the new list,
 *             or NULL in case of failure */
struct array_list *array_list_new(void)
{
	return NULL;
}
