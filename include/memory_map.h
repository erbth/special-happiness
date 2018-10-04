#ifndef MEMORY_MAP_H
#define MEMORY_MAP_H

#include <stdint.h>

/* A structure for holding a Memory Map retrieved via INT 15, AX = 0xe820. */
#define E820_MMAP_REGION_TYPE_USABLE				0x01
#define E820_MMAP_REGION_TYPE_RESERVED				0x02
#define E820_MMAP_REGION_TYPE_ACPI_RECLAIMABLE		0x03
#define E820_MMAP_REGION_TYPE_ACPI_NVS				0x04
#define E820_MMAP_REGION_TYPE_BAD					0x05

/* Offsets into the ACPI 3.0 extended attributes flags. */
#define E820_MMAP_REGION_ACPI_3_0_EXTENDED_ATTRIBUTES_IGNORE		0
#define E820_MMAP_REGION_ACPI_3_0_EXTENDED_ATTRIBUTES_NON_VOLATILE	1

/* Such an entry is actually called `region' */
typedef struct _e820_mmap_entry e820_mmap_entry;
struct _e820_mmap_entry
{
	uint64_t base_address;
	uint64_t length;
	uint32_t type;

	/* Non-zero if the ACPI 3.0 extended attributes field is valid (that is was
	 * returned by the firmware), zero if not. */
	uint32_t have_acpi_3_0_extended_attributes;
	uint32_t acpi_3_0_extended_attributes;
} __attribute__((packed));

typedef struct _e820_mmap e820_mmap;
struct _e820_mmap
{
	/* Number of entries */
	uint32_t num_entries;

	/* This is actually a pointer to an array of e820_mmap_entries however it
	 * should be platform independent. */
	uint32_t entries_address;
} __attribute__((packed));


/********************** A more sofisticated memory map ***********************/
// Definitions for System Memory Map Entry's type
// The order of the entries defines the preferrence among each other, in case
// two ranges overlap. The lower number preceeds the higher one.
#define SYSTEM_MEMORY_MAP_ENTRY_RESERVED			0x00000001
#define SYSTEM_MEMORY_MAP_ENTRY_ACPI_NVS 			0x00000002
#define SYSTEM_MEMORY_MAP_ENTRY_ACPI_RECLAIM		0x00000003
#define SYSTEM_MEMORY_MAP_ENTRY_WELL_KNOWN_PC		0x00000004
#define SYSTEM_MEMORY_MAP_ENTRY_FREE				0xffffffff

typedef struct _system_memory_map_entry system_memory_map_entry;
struct _system_memory_map_entry
{
	system_memory_map_entry *previous;
	system_memory_map_entry *next;
	uint32_t type;
	uint64_t base;
	uint64_t size;
} __attribute__((packed));

// kSystemMemoryMap_entry*
// kSystemMemoryMap_getNextEntry(kSystemMemoryMap_entry* current);
// void kSystemMemoryMap_print(void);
// void kSystemMemoryMap_printEntry(kSystemMemoryMap_entry* e);

#endif /* MEMORY_MAP_H */
