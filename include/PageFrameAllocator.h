#ifndef PAGE_FRAME_ALLOCATOR_H
#define PAGE_FRAME_ALLOCATOR_H

#include <stdint.h>
#include "SystemMemoryMap.h"

/******************************** Usage ***************************************
 *
 * ## Initializing a Page Frame Allocator
 *   1. Somehow allocate a PageFrameAllocator structure.
 *   2. Fill mmap with a system's memory map
 *   3. Set frame_count to the number of frames available on the system
 *   4. Fill bitmap_size and bitmap with a bitmap that is big enough
 *      to monitor the entire physical memory range
 *   5. Fill frame_size with the desired page frame size
 *   6. Call PageFrameAllocator_init_bitmap to initialize the bitmap from the
 *      memory map
 *   7. Use PageFrameAllocator_mark_used and PageFrameAllocator_mark_free to
 *      adapt the usage information the way you like
 *
 *   Then you're done.
 *
 *****************************************************************************/

typedef struct _PageFrameAllocator PageFrameAllocator;
struct _PageFrameAllocator
{
	SystemMemoryMap mmap;

	uint32_t frame_size;

	/* The size of the bitmap in bytes. */
	unsigned int bitmap_size;
	uint8_t *bitmap;

	/* Number of frames available on the system */
	uint32_t frame_count;
};

/* Functions' and procedures' prototypes */
void PageFrameAllocator_init_bitmap (PageFrameAllocator *pfa);
void PageFrameAllocator_mark_used (PageFrameAllocator *pfa, uint32_t frame);
void PageFrameAllocator_mark_range_free
	(PageFrameAllocator *pfa, uint32_t first_frame, uint32_t count);

void PageFrameAllocator_mark_free (PageFrameAllocator *pfa, uint32_t frame);
void PageFrameAllocator_mark_range_used
	(PageFrameAllocator *pfa, uint32_t first_frame, uint32_t count);

int PageFrameAllocator_check_frames_available (
		PageFrameAllocator *pfa, unsigned int count);

#endif /* PAGE_FRAME_ALLOCATOR_H */
