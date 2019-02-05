#include <stdint.h>
#include "cpu_utils.h"
#include "SystemMemoryMap.h"
#include "PageFrameAllocator.h"
#include "MemoryAllocator.h"
#include "stdio.h"
#include "cpu/msr.h"

/* This file is compiled for a IA32 target. */

__attribute__((cdecl)) __attribute__((noreturn)) void stage2_i386_c_entry (SystemMemoryMap mmap)
{
	/* Initialize the real console */
	terminal_initialize ();

	printf ("Hi there, the terminal is initialized now and printf works!\n");

	/* Initialize a page frame allocator */
	PageFrameAllocator pfa;

	uint64_t memory_size = SystemMemoryMap_get_memory_size (mmap);

	pfa.mmap = mmap;
	pfa.frame_size = 4096;
	pfa.frame_count = memory_size / pfa.frame_size;
	pfa.bitmap_size = (pfa.frame_count + 7) / 8;

	/* Round up to full page frames as only those can be allocated so far */
	pfa.bitmap_size = ((pfa.bitmap_size + pfa.frame_size - 1) / pfa.frame_size) * pfa.frame_size;

	printf ("Memory size: %d MB\n", (int) memory_size / 1024 / 1024);

	/* Figure out a bitmap location */
	extern uint8_t kernel_end;

	/* Lowest possible bitmap location */
	uint32_t pfa_bitmap_location = ((intptr_t) &kernel_end + pfa.frame_size - 1) & ~(pfa.frame_size - 1);

	do
	{
		/* Check each mmap entry for intersection */
		SystemMemoryMap cm = mmap;
		uint8_t intersection = 0;

		while (cm)
		{
			if (pfa_bitmap_location + pfa.bitmap_size > cm->start &&
					pfa_bitmap_location < cm->start + cm->size &&
					cm->type != SYSTEM_MEMORY_MAP_ENTRY_FREE)
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
		/* No location for the bitmap found. Halt here. */
		printf ("FATAL: No location for the pfa bitmap found.\n");
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

	/* The system memory map */
	for (SystemMemoryMap_entry *cme = mmap; cme; cme = cme->next)
	{
		if (cme->type != SYSTEM_MEMORY_MAP_ENTRY_FREE)
		{
			PageFrameAllocator_mark_range_used (
					&pfa,
					(intptr_t) cme->start,
					cme->size);
		}
	}

	/* Initialize the memory allocator */
	/* MemoryAllocator ma;

	ma.pfa = &pfa;
	ma. */

	/* Well, let's have some fun here! */
	printf ("APIC base: 0x%llx\n", (long long) rdmsr64 (IA32_APIC_BASE));

	printf ("debugctl: 0x%lx\n", (long) rdmsr32 (IA32_DEBUGCTL));
	printf ("ds area:  0x%llx\n", (long long) rdmsr64 (IA32_DS_AREA));

	// uint64_t debugctl = rdmsr64 (IA32_DEBUGCTL);

	// debugctl |= 0x41;
	// wrmsr64 (IA32_DEBUGCTL, debugctl);

	// printf ("debugctl: 0x%lx\n", (long) rdmsr32 (IA32_DEBUGCTL));

	/* volatile uint8_t* p1 = (void*) (intptr_t) PageFrameAllocator_allocate (&pfa);
	volatile uint8_t* p2 = (void*) (intptr_t) PageFrameAllocator_allocate (&pfa);


	printf ("p1 is at 0x%x, p2 at 0x%x.\n", (intptr_t) p1, (intptr_t) p2);

	// p1[0] = 1;
	p2[0] = 2;

	printf ("p1[0] = %d, p2[0] = %d\n", (int) p1[0], (int) p2[0]);

	hypercall1 (11, (intptr_t) p1);
	hypercall1 (11, (intptr_t) p2); */

	struct ds_buffer_management_area {
			uint64_t bts_buffer_base;
			uint64_t bts_index;
			uint64_t bts_absolute_maximum;
			uint64_t bts_interrupt_threshold;

			uint64_t pebs_buffer_base;
			uint64_t pebs_index;
			uint64_t pebs_absolute_maximum;
			uint64_t pebs_interrupt_threshold;
			uint64_t pebs_counter_reset;
			uint64_t res;
	} __attribute__((packed)) *dsbma;

	dsbma = (void*) 0x10000000;

	printf ("bts buffer base: %llx, index: %llx\n",
			dsbma->bts_buffer_base, dsbma->bts_index);

	hypercall1 (11, (intptr_t) dsbma);

	printf ("bts buffer base: %llx, index: %llx\n",
			dsbma->bts_buffer_base, dsbma->bts_index);

	cpu_halt ();
}
