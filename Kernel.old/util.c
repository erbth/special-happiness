#include "stdio.h"
#include "MemoryManagement.h"
#include "util.h"

/* Function:   kernel_print_memory_info
 * Purpose:    to print the total available memory and the amount of used
 *             memory.
 * Parameters: None.
 * Returns:    Nothing. */
void kernel_print_memory_info(void)
{

	printf("Memory: %d Mibi Bytes total, %d/%d bytes used.\n",
		(int) (MemoryManagement_getTotalMemory() / (1024.0 * 1024)),
		MemoryManagement_getTotalMemory() - MemoryManagement_getFreeMemory(),
		MemoryManagement_getTotalMemory());
}
