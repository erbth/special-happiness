#include "SystemMemoryMap.h"
#include "utils.h"
#include "stdio.h"

uint64_t SystemMemoryMap_get_memory_size (SystemMemoryMap mmap)
{
	uint64_t size = 0;

	while (mmap)
	{
		if (mmap->previous == NULL || 
				mmap->previous->start + mmap->previous->size == mmap->start)
		{
			size = MAX (size, mmap->start + mmap->size);
		}

		mmap = mmap->next;
	}

	return size;
}
