/** Implementation of a queue using a linked list
 *  The enqueue, dequeue and getSize operations are atomar in respect to
 *  interrupts. */

#include "stdio.h"
#include "string.h"
#include "LinkedList.h"
#include "LinkedQueue.h"

/* Function:   LinkedQueue_create
 * Purpose:    to create a enw empty queue.
 * Parameters: None.
 * Returns:    A pointer to the new empty queue or NULL in case of failure. */
LinkedQueue* LinkedQueue_create(void)
{
	LinkedQueue* q = kmalloc(sizeof(LinkedQueue));

	if (q)
	{
		bzero(q, sizeof(LinkedQueue));

		if ((q->l = LinkedList_create()))
		{
			return q;
		}
		else
		{
			kfree(q);
		}
	}
	return NULL;
}

/* Function:   LinkedQueue_destroy
 * Purpose:    to destroy a queue that is free all its resources. The Queue
 *             items are NOT destoyed because this would require a destructor
 *             for them.
 * Parameters: q [IN]: A Pointer to the queue's meta data structure.
 * Retuns:     Nothing. */
void LinkedQueue_destroy(LinkedQueue* q)
{
	if (q)
	{
		LinkedList_destroy(q->l);
		kfree(q);
	}
}

/* Function:   LinkedQueue_enqueue
 * Purpose:    to enqueue an element. The payload has to be given directly as a
 *             void pointer, no special wrapping data structure is required.
 * Atomicity:  Called by an assembly language wrapper.
 * Parameters: q [IN]:       A pointer to the queue's meta data structure,
 *             p [CONST IN]: The payload.
 * Returns:    0 in case of success, -1 otherwise. */
__attribute__((cdecl)) int c_LinkedQueue_enqueue(LinkedQueue* q, const void* p)
{
	if (q)
	{
		return LinkedList_append(q->l, p) < 0 ? -1 : 0;
	}
	return -1;
}

/* Function:   LinkedQueue_dequeue
 * Purpose:    to dequeue an element.
 * Atomicity:  Called by an assembly language wrapper.
 * Parameters: q [IN]: A pointer to the queue's meta data structure.
 * Returns:    The payload as void pointer or NULL if the queue is empty or
 *             invalid (q == NULL). */
__attribute__((cdecl)) const void* c_LinkedQueue_dequeue(LinkedQueue* q)
{
	if (q)
	{
		return LinkedList_popFront(q->l);
	}
	return NULL;
}

/* Function:   LinkedQueue_getSize
 * Purpose:    to retrieve the count of items that are currently in the queue.
 * Atomicity:  Called by an assembly language wrapper.
 * Parameters: q [IN]: A pointer to the queue's meta data structure.
 * Returns:    The count of elements. If the queue is invalid (q == NULL),
 *             0 is returned. */
__attribute__((cdecl)) unsigned int c_LinkedQueue_getSize(LinkedQueue* q)
{
	if (q)
		return LinkedList_getSize(q->l);

	return 0;
}
