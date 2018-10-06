#include "MemoryAllocator.h"

void *MemoryAllocator_alloc (MemoryAllocator *ma, size_t size)
{
	/* Look if there is a chunk of free memory left that fits the requested
	 * size (first fit). */
	MemoryAllocator_range *free_range = ma->free_ranges;

	while (free_range)
	{
		if (free_range->size >= size)
			break;

		free_range = free_range->next;
	}

	if (free_range)
	{
		MemoryAllocator_range *allocated_range;

		/* If the range is big enough to take a part of it for a new free block's
		 * description, do that. */
		if (free_range->size > size + sizeof (*free_range))
		{
			/* Split the free block */
			allocated_range = (void *) free_range->begin + size;
			free_range->beginn = allocated_range + sizeof (*allocated_range);
			free_range->size = free_range->size - size - sizeof (*allocated_range);
			allocated_range->size = size;
		}
		else
		{
			/* Remove the free block from the list of free blocks */
			if (free_range->previous)
				free_range->previous = free_range->next;

			if (free_range->next)
				free_range->next->previous = free_range->previous;

			if (free_range == ma->free_ranges)
				ma->free_ranges = free_range;

			allocated_range = free_range;
		}

		/* Hook the allocated block into the list of allocated blocks */
		allocated_range->previous = NULL;

		if (!ma->allocated_ranges)
		{
			allocated_range->next = NULL;
		}
		else
		{
			allocated_range->next = ma->allocated_ranges;
			allocated_range->next->previous = allocated_range;
		}

		ma->allocated_ranges = allocated_range;
	}
	else
	{
		uint32_t page_frame_count = (size + pfa->frame_size - 1) / pfa->frame_size;
		
		/* Check if enough page frames are free */
		if (!PageFrameAllocator_check_frames_available (ma->pfa, page_frame_count))
			return NULL;

		/* If so, allocate and map them. */

	}
}

void MemoryAllocator_free (MemoryAllocator *ma, void *ptr)
{
}
