#ifndef PAGE_FRAME_ALLOCATOR_H
#define PAGE_FRAME_ALLOCATOR_H

#include <stdint.h>

typedef struct _pfa_ctx pfa_ctx;
struct _pfa_ctx
{

	/* The size of the bitmap in bytes. */
	unsigned int bitmap_size;
	uint8_t *bitmap;
};

#endif /* PAGE_FRAME_ALLOCATOR_H */
