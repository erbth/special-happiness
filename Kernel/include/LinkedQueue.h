/** Implementation of a queue using a linked list
 *  The enqueue, dequeue and getSize operations are atomar in respect to
 *  interrupts. */

#ifndef LINKED_QUEUE_H
#define LINKED_QUEUE_H

#include "stdio.h"
#include "LinkedList.h"

typedef struct _LinkedQueue LinkedQueue;
struct _LinkedQueue
{
	LinkedList* l;
};

/* Prototypes */
LinkedQueue* LinkedQueue_create(void);
void LinkedQueue_destroy(LinkedQueue* q);
extern __attribute__((cdecl)) int LinkedQueue_enqueue(LinkedQueue* q, const void* p);
extern __attribute__((cdecl)) const void* LinkedQueue_dequeue(LinkedQueue* q);
extern __attribute__((cdecl)) unsigned int LinkedQueue_getSize(LinkedQueue* q);

#endif /* LINKED_QUEUE_H */
