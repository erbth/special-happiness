#include <stdint.h>
#include "cpu_utils.h"
#include "SystemMemoryMap.h"
#include "PageFrameAllocator.h"
#include "MemoryAllocator.h"

/* This file is compiled for a IA32 target. */

__attribute__((cdecl)) __attribute__((noreturn)) void stage2_i386_c_entry (SystemMemoryMap mmap)
{
	/* Initialize a page frame allocator */
	PageFrameAllocator pfa;

	uint64_t memory_size = SystemMemoryMap_get_memory_size (mmap);

	pfa.mmap = mmap;
	pfa.frame_size = 4096;
	pfa.frame_count = memory_size / pfa.frame_size;
	pfa.bitmap_size = (pfa.frame_count + 7) / 8;

	/* Round up to full page frames as only those can be allocated so far */
	pfa.bitmap_size = ((pfa.bitmap_size + pfa.frame_size - 1) / pfa.frame_size) * pfa.frame_size;

	/* Figure out a bitmap location */
	extern uint8_t kernel_end;

	/* Lowest possible bitmap location */
	uint32_t pfa_bitmap_location = ((intptr_t) &kernel_end + pfa.frame_size - 1) / pfa.frame_size;

	do
	{
		/* Check each mmap entry for intersection */
		SystemMemoryMap cm = mmap;
		uint8_t intersection = 0;

		while (cm)
		{
			if (
					(pfa_bitmap_location + pfa.bitmap_size > cm->start &&
					pfa_bitmap_location < cm->start + cm->size) ||
					(pfa_bitmap_location < cm->start + cm->size &&
					 pfa_bitmap_location + pfa.bitmap_size > cm->start))
			{
				intersection = 1;
				break;
			}
			cm = cm->next;
		}

		/* If the bitmap does not intersect with any mmap entry, this is a
		 * valid location */
		if (!intersection)
			break;

		/* Else, try one page frame above. */
		pfa_bitmap_location += pfa.frame_size;
	}
	while (pfa_bitmap_location + pfa.bitmap_size <= memory_size);

	if (pfa_bitmap_location + pfa.bitmap_size > memory_size)
	{
		/* No location for the memory map found. Halt here. */
		cpu_halt ();
	}

	pfa.bitmap = (uint8_t *) (intptr_t) pfa_bitmap_location;
	PageFrameAllocator_init_bitmap (&pfa);

	/* Adapt usage information */
	/* It is OK to overwright stage 1 here. You won't need those 16 bit print
	 * commands anymore. */
	/* Kernel */
	uint32_t kernel_first_frame = 0x7E00 / pfa.frame_size;
	uint32_t kernel_last_frame = (intptr_t ) &kernel_end / pfa.frame_size;

	for (uint32_t frame = kernel_first_frame; frame <= kernel_last_frame; frame++)
		PageFrameAllocator_mark_used (&pfa, frame);

	/* PFA bitmap */
	PageFrameAllocator_mark_range_used (
			&pfa,
			(intptr_t) pfa.bitmap / pfa.frame_size,
			pfa.bitmap_size / pfa.frame_size);

	/* Initialize the memory allocator */
	MemoryAllocator ma;

	ma.pfa = &pfa;
	ma.

	/* Initialize the real console */

	cpu_halt ();
}
