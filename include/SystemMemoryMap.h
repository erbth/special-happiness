#ifndef SYSTEM_MEMORY_MAP_H
#define SYSTEM_MEMORY_MAP_H

#include <stdint.h>

/* Contains constants */
#include "SystemMemoryMap.inc.h"

typedef struct _SystemMemoryMap_entry SystemMemoryMap_entry;
struct _SystemMemoryMap_entry
{
	SystemMemoryMap_entry *previous;
	SystemMemoryMap_entry *next;
	uint32_t type;
	uint64_t start;
	uint64_t size;
} __attribute__((packed));

typedef SystemMemoryMap_entry *SystemMemoryMap;

/* Functions' and procedures' prototypes */
uint64_t SystemMemoryMap_get_memory_size (SystemMemoryMap mmap);

#endif
