#include <stdint.h>
#include "memory_map.h"
#include "cpu_utils.h"

/* This file is compiled for a IA32 target. */

__attribute__((cdecl)) __attribute__((noreturn)) void stage2_i386_c_entry (uint32_t e820_mmap_address)
{
	e820_mmap *mmap = (e820_mmap *) (intptr_t) e820_mmap_address;

	// page_frame_allocator_
	cpu_halt ();
}
