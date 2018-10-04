#include <stddef.h>
#include <stdint.h>
#include "stdio.h"
#include "CommonlyUsedData.h"
#include "Kernel_SystemMemoryMap.h"

kSystemMemoryMap_entry*
kSystemMemoryMap_getNextEntry(kSystemMemoryMap_entry* current)
{
	if (current == NULL)
	{
		return system_memory_map;
	}
	else
	{
		return current->next;
	}
}

void kSystemMemoryMap_print(void)
{
	printf("****************************** System Memory Map ******************************\n"
		"system_memory_map: %p\n", system_memory_map);

	for (kSystemMemoryMap_entry* e = system_memory_map; e; e = e->next)
	{
		kSystemMemoryMap_printEntry(e);
	}

	printf("--- end ---\n\n");
}

void kSystemMemoryMap_printEntry(kSystemMemoryMap_entry* e)
{
	if (e)
	{
		printf("Start: 0x%llx, Size: %llxh ", e->base, e->size);
		switch (e->type)
		{
			case SYSTEM_MEMORY_MAP_ENTRY_RESERVED:
				printf("[  reserved  ]");
				break;

			case SYSTEM_MEMORY_MAP_ENTRY_ACPI_NVS:
				printf("[  ACPI NVS  ]");
				break;

			case SYSTEM_MEMORY_MAP_ENTRY_ACPI_RECLAIM:
				printf("[ACPI RECLAIM]");
				break;

			case SYSTEM_MEMORY_MAP_ENTRY_WELL_KNOWN_PC:
				printf("[ Well known ]");
				break;

			case SYSTEM_MEMORY_MAP_ENTRY_KERNEL_TEXT_DATA:
				printf("[ Kernel.TD  ]");
				break;

			case SYSTEM_MEMORY_MAP_ENTRY_LOADER_TEXT_DATA:
				printf("[ Loader.TD  ]");
				break;

			case SYSTEM_MEMORY_MAP_ENTRY_KERNEL_BSS:
				printf("[ Kernel.bss ]");
				break;

			case SYSTEM_MEMORY_MAP_ENTRY_LOADER_BSS:
				printf("[ Loader.bss ]");
				break;

			case SYSTEM_MEMORY_MAP_ENTRY_FREE:
				printf("[    free    ]");
				break;

			default:
				printf("[ undefined  ]");
				break;
		}

		printf("\n");
	}
	else
	{
		printf("nil");
	}
}
