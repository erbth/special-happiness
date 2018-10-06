#include "PageFrameAllocator.h"

void PageFrameAllocator_init_bitmap (PageFrameAllocator *pfa)
{
	SystemMemoryMap mmap = pfa->mmap;

	/* Zero the whole bitmap */
	for (unsigned int i = 0; i < pfa->bitmap_size; i++)
		pfa->bitmap[i] = 0;

	/* Mark used and reserved frames as used */
	while (mmap)
	{
		if (mmap->type == SYSTEM_MEMORY_MAP_ENTRY_FREE)
		{
			uint32_t lowest_frame = mmap->start / pfa->frame_size;
			uint32_t highest_frame = (mmap->start + mmap->size) / pfa->frame_size ;

			for (uint32_t i = lowest_frame; i <= highest_frame; i++)
				PageFrameAllocator_mark_used (pfa, i);
		}

		mmap = mmap->next;
	}

	/* Mark unavailable frames at the end of the map (padding) as used */
	uint32_t count = pfa->bitmap_size * 8 - pfa->frame_count;
	PageFrameAllocator_mark_range_used (pfa, pfa->frame_count, count);
}

void PageFrameAllocator_mark_used (PageFrameAllocator *pfa, uint32_t frame)
{
	uint32_t byte = frame / 8;
	uint8_t bit = frame % 8;

	if (byte < pfa->bitmap_size)
	{
		pfa->bitmap[byte] |= (1 << bit);
	}
}

void PageFrameAllocator_mark_range_used
	(PageFrameAllocator *pfa, uint32_t first_frame, uint32_t count)
{
	uint32_t frame = first_frame;

	while (frame < first_frame + count)
		PageFrameAllocator_mark_used (pfa, frame++);
}

void PageFrameAllocator_mark_free (PageFrameAllocator *pfa, uint32_t frame)
{
	uint32_t byte = frame / 8;
	uint8_t bit = frame % 8;

	if (byte < pfa->bitmap_size)
	{
		pfa->bitmap[byte] &= ~(1 << bit);
	}
}

void PageFrameAllocator_mark_range_free
	(PageFrameAllocator *pfa, uint32_t first_frame, uint32_t count)
{
	uint32_t frame = first_frame;

	while (frame < first_frame + count)
		PageFrameAllocator_mark_free (pfa, frame++);
}

int PageFrameAllocator_check_frames_available (
		PageFrameAllocator *pfa, unsigned int count)
{
	for (uint32_t i = 0; i < pfa->frame_count && count > 0; i++)
	{
		if ((pfa->bitmap[i / 8] & (1 << (i % 8))) == 0)
			count--;
	}

	return count == 0 ? 1 : 0;
}
