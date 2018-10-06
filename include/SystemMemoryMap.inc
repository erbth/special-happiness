%ifndef SYSTEM_MEMORY_MAP_INC
%define SYSTEM_MEMORY_MAP_INC

; Usually you don't want to include this file directly but rather an bitness
; specific version.

; Definitions for System Memory Map Entry's type
; The order of the entries defines the preferrence among each other, in case
; two ranges overlap. The lower number preceeds the higher one.
%define SYSTEM_MEMORY_MAP_ENTRY_RESERVED			0x00000001
%define SYSTEM_MEMORY_MAP_ENTRY_ACPI_NVS 			0x00000002
%define SYSTEM_MEMORY_MAP_ENTRY_ACPI_RECLAIM		0x00000003
%define SYSTEM_MEMORY_MAP_ENTRY_WELL_KNOWN_PC		0x00000004
; %define SYSTEM_MEMORY_MAP_ENTRY_KERNEL_TEXT_DATA	0x00000005
; %define SYSTEM_MEMORY_MAP_ENTRY_LOADER_TEXT_DATA	0x00000006
; %define SYSTEM_MEMORY_MAP_ENTRY_KERNEL_BSS 			0x00000007
; %define SYSTEM_MEMORY_MAP_ENTRY_LOADER_BSS 			0x00000008
%define SYSTEM_MEMORY_MAP_ENTRY_FREE				0xffffffff

%endif
