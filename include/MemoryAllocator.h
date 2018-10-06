#ifndef MEMORY_ALLOCATOR_H
#define MEMORY_ALLOCATOR_H

#include <stdint.h>
#include "PageFrameAllocator.h"

/******************************** Usage ***************************************
 *
 * ## Initializing a Memory Allocator
 *   1. Somehow allocate a MemoryAllocator structure
 *   2. Set pfa to a Page Frame Allocator
 *   3. Set ranges to 0 or alternatively to a manually allocated range.
 *****************************************************************************/

typedef struct _MemoryAllocator_range MemoryAllocator_range;
struct _MemoryAllocator_range
{
	MemoryAllocator_range *next;
	MemoryAllocator_range *previous;

	uint8_t *beginn;
	size_t size;
} __attribute__((packed));

typedef struct _MemoryAllocator MemoryAllocator;
struct _MemoryAllocator
{
	PageFrameAllocator pfa;

	MemoryAllocator_range *allocated_ranges;
	MemoryAllocator_range *free_ranges;
} __attribute__((packed));

#endif
