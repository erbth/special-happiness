#ifndef MEMORY_ALLOCATOR_H
#define MEMORY_ALLOCATOR_H

#include <stdint.h>
#include <stddef.h>
#include "PageFrameAllocator.h"

/******************************** Usage ***************************************
 *
 * ## Initializing a Memory Allocator
 *   1. Somehow allocate a MemoryAllocator structure
 *   2. Call MemoryAllocator_init
 *****************************************************************************/

typedef struct _MemoryAllocator_range MemoryAllocator_range;
struct _MemoryAllocator_range
{
	MemoryAllocator_range *next;
	MemoryAllocator_range *previous;

	uint8_t *begin;
	uint32_t size;
} __attribute__((packed));

typedef struct _MemoryAllocator MemoryAllocator;
struct _MemoryAllocator
{
	PageFrameAllocator *pfa;

	MemoryAllocator_range *allocated_ranges;
	MemoryAllocator_range *free_ranges;
} __attribute__((packed));

/* Public API */
void MemoryAllocator_init (MemoryAllocator *ma, PageFrameAllocator *pfa);
void *MemoryAllocator_alloc (MemoryAllocator *ma, size_t size);
void MemoryAllocator_free (MemoryAllocator *ma, void *ptr);

#endif
