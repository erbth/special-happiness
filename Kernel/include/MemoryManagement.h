/* Memory management. Provides dynamically allocatable memory and defines the
 * kmalloc and kfree macros. */
#ifndef MEMORY_MANAGEMENT_H
#define MEMORY_MANAGEMENT_H

#include "stddef.h"
#include "stdint.h"

enum MemoryManagement_regionType
{
	MEMORY_MANAGEMENT_REGION_FREE,
	MEMORY_MANAGEMENT_REGION_OCCUPIED
};

typedef struct _MemoryManagement_regionHeader MemoryManagement_regionHeader;
struct _MemoryManagement_regionHeader
{
	MemoryManagement_regionHeader* previous;
	MemoryManagement_regionHeader* next;
	uint32_t size;

	/* Must always be 0x12345678 to ensure integrity */
	uint32_t magic;

	enum MemoryManagement_regionType type;
};

#define kmalloc MemoryManagement_allocate
#define kfree MemoryManagement_free

extern __attribute__((cdecl)) void* MemoryManagement_allocate(size_t size);
extern __attribute__((cdecl)) void MemoryManagement_free(void* pmem);
extern __attribute__((cdecl)) uint32_t MemoryManagement_getTotalMemory(void);
extern __attribute__((cdecl)) uint32_t MemoryManagement_getFreeMemory(void);
extern __attribute__((cdecl)) void MemoryManagement_addRegion(uint32_t base, uint32_t size);
void MemoryManagement_addFromSMAP(void);
extern __attribute__((cdecl)) void MemoryManagement_print(void);

#endif /* MEMORY_MANAGEMENT_H */
