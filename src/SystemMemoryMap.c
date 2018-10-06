#include "SystemMemoryMap.h"
#include "utils.h"

uint64_t SystemMemoryMap_get_memory_size (SystemMemoryMap mmap)
{
	uint64_t size = 0;

	while (mmap)
		size = MAX (size, mmap->start + mmap->size);

	return size;
}
