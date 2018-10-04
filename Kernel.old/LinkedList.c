/** Implementation of a linked list */

#include "stdio.h"
#include "string.h"
#include "LinkedList.h"

/* Function:   LinkedList_create
 * Purpose:    to create a new empty linked list.
 * Parameters: None.
 * Returns:    A pointer to a new empty linked list or NULL in case of failure
 *             (usually kmalloc returned NULL). */
LinkedList* LinkedList_create(void)
{
	LinkedList* l = kmalloc(sizeof(LinkedList));

	if (l)
	{
		bzero(l, sizeof(LinkedList));
	}

	return l;
}

/* Function:   LinkedList_destroy
 * Purpose:    to destroy a linked list, while the containing elements are NOT
 *             destroyd. To allow this, a destructor wouls have to be set when
 *             adding elements. but this can be done with C++ more easily.
 * Parameters: l [IN]: Pointer to the linked list which is to be destroyed.
 * Returns:    Nothing. */
void LinkedList_destroy(LinkedList* l)
{
	if (l)
	{
		kfree(l);
	}
}

/* Function:   LinkedList_append
 * Purpose:    to append an element to the list in O(1). The payload must be
 *             specified directly as void pointer, the function will wrap it
 *             into an internal structure containing meta data.
 * Parameters: l [IN]:       A pointer to the list's meta data structure,
 *             p [CONST IN]: The payload.
 * Returns:    0 in case of success, -1 otherwise (usually kmalloc failed). */
int LinkedList_append(LinkedList* l, const void* p)
{
	if (l)
	{
		LinkedList_element* e = kmalloc(sizeof(LinkedList_element));

		if (e)
		{
			bzero (e, sizeof(LinkedList_element));

			e->next = NULL;
			e->list = l;
			e->payload = p;

			if (l->last)
			{
				l->last->next = e;
			}
			else
			{
				l->first = l->last = e;
			}

			l->size++;

			return 0;
		}
	}
	return -1;
}

/* Function:   LinkedList_popFront
 * Purpose:    to remove an element from the front of the list.
 * Parameters: l [IN]: A pointer to the list's meta data structure.
 * Returns:    An pointer to the payload of the removed element or NULL, if
 *             the list is empty or invalid. */
const void* LinkedList_popFront(LinkedList* l)
{
	if (l && l->first)
	{
		const void* p = l->first->payload;

		/* Remove the element */
		LinkedList_element* e = l->first;

		l->first = e->next;
		l->size--;

		if (!l->first)
			l->last = l->first;

		kfree (e);

		return p;
	}
	return NULL;
}

/* Function:   LinkedList_getSize
 * Purpose:    to retrieve the count of the elements currently stored in the
 *             list.
 * Parameters: l [IN]: Pointer to the list's meta data structure.
 * Returns:    The count of elements in the list. If the list is invalid
 *             (l == NULL), 0 is returned. */
unsigned int LinkedList_getSize(LinkedList* l)
{
	if (l)
		return l->size;

	return 0;
}
