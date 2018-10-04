; Memory management. Provides dynamically allocatable memory and defines the
; kmalloc and kfree macros.
%ifndef MEMORY_MANAGEMENT_INC
%define MEMORY_MANAGEMENT_INC

%define kmalloc MemoryManagement_allocate
%define kfree MemoryManagement_free

extern MemoryManagement_allocate
extern MemoryManagement_free
extern MemoryManagement_getTotalMemory
extern MemoryManagement_getFreeMemory
extern MemoryManagement_addRegion
extern MemoryManagement_addFromSMAP
extern MemoryManagement_print

%endif
