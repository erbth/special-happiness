#ifndef KERNEL_SYSTEM_MEMORY_MAP_H
#define KERNEL_SYSTEM_MEMORY_MAP_H

// For SYSTEM_MEMORY_MAP_ENTRY_* type.
#include "CommonConstants.h"

/* System Memory Map entry:
 * 0x00	previous	32 bit
 * 0x04	next		32 bit
 * 0x08	type		32 bit
 * 0x0C	base		64 bit
 * 0x14	size		64 bit
 *
 * type is one of SYSTEM_MEMORY_MAP_ENTRY_* defined in CommonConstants.h */

typedef struct _kSystemMemoryMap_entry kSystemMemoryMap_entry;
struct _kSystemMemoryMap_entry
{
	kSystemMemoryMap_entry *previous;
	kSystemMemoryMap_entry *next;
	uint32_t type;
	uint64_t base;
	uint64_t size;
} __attribute__((packed));

kSystemMemoryMap_entry*
kSystemMemoryMap_getNextEntry(kSystemMemoryMap_entry* current);
void kSystemMemoryMap_print(void);
void kSystemMemoryMap_printEntry(kSystemMemoryMap_entry* e);

#endif /* KERNEL_SYSTEM_MEMORY_MAP_H */
