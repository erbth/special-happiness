%ifndef EARLY_DYNAMIC_MEMORY_INC
%define EARLY_DYNAMIC_MEMORY_INC

; Usually you don't want to include this file directly but rather a word size
; specific version.

; Size of physical memory for early dynamically allocatable memory
%define EARLY_DYNAMIC_MEMORY_SIZE 16384

; Bitmasks for early memory manager memory header flags
%define EARLY_DYNAMIC_MEMORY_HEADER_OCCUPIED	0x00000001

%endif
