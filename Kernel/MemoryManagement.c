/* Memory management. Provides dynamically allocatable memory.
 *
 * Some of the functions herein are called from assembly wrappers who handle
 * disabling of interrupts to make the functions atomic. */

#include "stdio.h"
#include "stdint.h"
#include "MemoryManagement.h"
#include "Kernel_SystemMemoryMap.h"
#include "io.h"

/* Pointer to the first entry of the doubly linked list */
static MemoryManagement_regionHeader* MemoryManagement_base = NULL;

/* Prototypes for static functions */
static void MemoryManagement_append(MemoryManagement_regionHeader* r);
static void MemoryManagement_assertHeaderIsValid(MemoryManagement_regionHeader* r);

/* Function:   MemoryManagement_allocate
 * Purpose:    to allocate a block of memory from the available memory pool.
 * Atomicity:  Called from assembly wrapper
 * Parameters: size [IN]: Size of memory block
 * Returns:    Pointer to the allocated block of memory or NULL in case of
 *             failure (no free memory left). */
__attribute__((cdecl)) void* c_MemoryManagement_allocate(size_t size)
{
	/* Find a free region that is big enough */
	MemoryManagement_regionHeader* r = MemoryManagement_base;

	while (r)
	{
		/* Check magic number */
		MemoryManagement_assertHeaderIsValid(r);

		if (r->type == MEMORY_MANAGEMENT_REGION_FREE && r->size >= size)
		{
			/* Is it enough space to split the block? */
			if (r->size > size + sizeof(MemoryManagement_regionHeader))
			{
				MemoryManagement_regionHeader* n =
					(MemoryManagement_regionHeader*) ((uint8_t *) r + sizeof(*r) + size);

				n->type = r->type;
				n->magic = 0x12345678;
				n->size = r->size - sizeof(*n) - size;

				/* Insert new header */
				n->next = r->next;
				n->previous = r;

				r->next = n;

				if (n->next)
					n->next->previous = n;

				/* Adjust size of r */
				r->size = size;
			}

			/* Occupy region */
			r->type = MEMORY_MANAGEMENT_REGION_OCCUPIED;
			return r + 1;
		}
		r = r->next;
	}

	return NULL;
}

/* Function:   MemoryManagement_free
 * Purpose:    to return a block of memory to the pool of available memory,
 *             commonly known as freeing memory.
 * Atomicity:  Called from assembly wrapper
 * Parameters: pmem [IN]: Pointer to the begin of the memory block. */
__attribute__((cdecl)) void c_MemoryManagement_free(void* pmem)
{
	if (pmem)
	{
		MemoryManagement_regionHeader *r = (MemoryManagement_regionHeader*) pmem - 1;

		if (r->type != MEMORY_MANAGEMENT_REGION_OCCUPIED ||
			r->magic != 0x12345678)
		{
			printf("MemoryManagement: Double free or corruption.\n");
			kHUP();
		}
		else
		{
			/* Free block */
			r->type = MEMORY_MANAGEMENT_REGION_FREE;

			/* Merge with possibly touching and free lower neighbour */
			if (r->previous && r->previous->type == MEMORY_MANAGEMENT_REGION_FREE)
			{
				if ((uint8_t*) r->previous +
					sizeof(MemoryManagement_regionHeader) +
					r->previous->size == (uint8_t*) r)
				{
					/* The headers are in touch */
					r->previous->size += r->size +
						sizeof(MemoryManagement_regionHeader);

					r->previous->next = r->next;
					if (r->next)
						r->next->previous = r->previous;

					r = r->previous;
				}
			}

			/* Merge with possibly touching and free upper neighbour */
			if (r->next && r->next->type == MEMORY_MANAGEMENT_REGION_FREE)
			{
				if ((uint8_t*) r +
					sizeof(MemoryManagement_regionHeader) +
					r->size == (uint8_t*) r->next)
				{
					/* The headers are in touch */
					r->size += r->next->size +
						sizeof(MemoryManagement_regionHeader);

					r->next = r->next->next;
					if (r->next)
						r->next->previous = r;
				}
			}
		}
	}
	else
	{
		printf("MemoryManagement: Trying to free a NULL pointer.\n");
		kHUP();
	}
}

/* Function:   MemoryManagement_addRegion
 * Purpose:    to add a region of free memory to the pool of available.
 *             A base address of 0 is not allowed to have a value for invalid
 *             pointers. If a base address of 0 is supplied, the region is not
 *             added. Additionally, the size available for allocation will be
 *             less than the supplied size by
 *             sizeof(MemoryManagement_regionHeader), because meta data has to
 *             be stored. If the supplied size is to small to provide any
 *             available memory, the region is not added.
 *             The region must be disjoint with the memory already available.
 * Atomicity:  Called from assembly wrapper
 * Parameters: base [IN]: The memory region's base address
 *             size [IN]: The memory region's size */
__attribute__((cdecl)) void c_MemoryManagement_addRegion(uint32_t base, uint32_t size)
{
	if (base != 0 && size > sizeof(MemoryManagement_regionHeader))
	{
		MemoryManagement_regionHeader* ph = (MemoryManagement_regionHeader*) base;

		/* Initialize header */
		ph->size = size - sizeof (MemoryManagement_regionHeader);
		ph->magic = 0x12345678;
		ph->type = MEMORY_MANAGEMENT_REGION_FREE;

		MemoryManagement_append(ph);
	}
}

/* Function:   MemoryManagement_addFromSMAP
 * Purpose:    to add the free memory regions from the System Memory Map to
 *             the pool of available memory.
 * Atomicity:  Not required
 * Parameters: None. */
void MemoryManagement_addFromSMAP(void)
{
	kSystemMemoryMap_entry *smapEntry = NULL;

	while ((smapEntry = kSystemMemoryMap_getNextEntry(smapEntry)))
	{
		if (smapEntry->type == SYSTEM_MEMORY_MAP_ENTRY_FREE)
			/* It's a 32 bit OS. */
			MemoryManagement_addRegion(
				(uint32_t) (smapEntry->base & 0xFFFFFFFF),
				(uint32_t) (smapEntry->size & 0xFFFFFFFF));
	}
}

/* Function:   MemoryManagement_append
 * Purpose:    to append a memory region to the current list. Use with care,
 *             no error checking is done.
 * Atomicity:  Not required (internal helper)
 * Parameters: r [IN]: The memory region */
static void MemoryManagement_append(MemoryManagement_regionHeader* r)
{
	if (MemoryManagement_base)
	{
		MemoryManagement_regionHeader *last = MemoryManagement_base;

		/* Find last element in list */
		while (last->next)
			last = last->next;

		last->next = r;
		r->previous = last;
		r->next = NULL;
	}
	else
	{
		r->next = r->previous = NULL;
		MemoryManagement_base = r;
	}
}

/* Function:   MemoryManagement_assertHeaderIsValid
 * Purpose:    to ensure that a region header is valid.
 *             Helper function.
 * Atomicity:  Not required (internal helper)
 * Parameters: r [IN]: Pointer to region header. */
static void MemoryManagement_assertHeaderIsValid(MemoryManagement_regionHeader* r)
{
	if (!r)
	{
		printf("MemoryManagement: region header NULL\n");
		kHUP();
	}

	if (r->magic != 0x12345678)
	{
		printf("MemoryManagement: region magic number invalid\n");
		kHUP();
	}
}

/* Function:   MemoryManagement_print
 * Purpose:    to print the current memory region list, useful for debugging.
 * Atomicity:  Called from assembly wrapper
 * Parameters: None. */
__attribute__((cdecl)) void c_MemoryManagement_print(void)
{
	printf("****************************** Memory Region List *****************************\n"
		"Base: %p\n", MemoryManagement_base);

	MemoryManagement_regionHeader* r = MemoryManagement_base;

	while (r != NULL)
	{
		const char* stype;

		switch (r->type)
		{
			case MEMORY_MANAGEMENT_REGION_FREE:
				stype = "[   free   ]";
				break;

			case MEMORY_MANAGEMENT_REGION_OCCUPIED:
				stype = "[ occupied ]";
				break;

			default:
				stype = "[undefined ]";
				break;
		}

		printf("Header addr: %p, .previous: %p, .next: %p,\n"
			"    .size: %xh, .magic: %s, .type: %s\n",
			r,
			r->previous,
			r->next,
			r->size,
			r->magic == 0x12345678 ? "[ OK ]" : "[FAIL]",
			stype);

		r = r->next;
	}

	printf("--- end ---\n\n");
}
