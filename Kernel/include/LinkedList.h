/** Implementation of a linked list */

#ifndef LINKED_LIST_H
#define LINKED_LIST_H

#include "stdio.h"

typedef struct _LinkedList_element LinkedList_element;
typedef struct _LinkedList LinkedList;

struct _LinkedList_element
{
	LinkedList_element* next;
	LinkedList* list;
	const void* payload;
};

struct _LinkedList
{
	LinkedList_element* first;
	LinkedList_element* last;
	unsigned int size;
};

/* Prototypes, for documentation see source code (includes comments) */
LinkedList* LinkedList_create(void);
void LinkedList_destroy(LinkedList* l);
int LinkedList_append(LinkedList* l, const void* p);
const void* LinkedList_popFront(LinkedList* l);
unsigned int LinkedList_getSize(LinkedList* l);

#endif /* LINKED_LIST_H */
