// Currently, only #define, #ifndef and #endif are supported herein, because of
// htoinc.sh
#ifndef COMMON_CONSTANTS_H
#define COMMON_CONSTANTS_H

// Definitions for System Memory Map Entry's type
// The order of the entries defines the preferrence among each other, in case
// two ranges overlap. The lower number preceeds the higher one.
#define SYSTEM_MEMORY_MAP_ENTRY_RESERVED			0x00000001
#define SYSTEM_MEMORY_MAP_ENTRY_ACPI_NVS 			0x00000002
#define SYSTEM_MEMORY_MAP_ENTRY_ACPI_RECLAIM		0x00000003
#define SYSTEM_MEMORY_MAP_ENTRY_WELL_KNOWN_PC		0x00000004
#define SYSTEM_MEMORY_MAP_ENTRY_KERNEL_TEXT_DATA	0x00000005
#define SYSTEM_MEMORY_MAP_ENTRY_LOADER_TEXT_DATA	0x00000006
#define SYSTEM_MEMORY_MAP_ENTRY_KERNEL_BSS 			0x00000007
#define SYSTEM_MEMORY_MAP_ENTRY_LOADER_BSS 			0x00000008
#define SYSTEM_MEMORY_MAP_ENTRY_FREE				0x00000009

// Size of physical memory for early dynamically allocatable memory
#define EARLY_DYNAMIC_MEMORY_SIZE 16384

// Bitmasks for early memory manager memory header flags
#define EARLY_DYNAMIC_MEMORY_HEADER_OCCUPIED	0x00000001

#endif /* COMMON_CONSTANTS_H */
