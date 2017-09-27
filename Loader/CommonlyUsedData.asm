%include "CommonConstants.inc"

; In this module shall lay no executable code. The address- and operation size
; is undefined.
section .bss
; Physical memory used for early dynamically allocated memory
global early_dynamic_memory
early_dynamic_memory resb EARLY_DYNAMIC_MEMORY_SIZE

; Address of System Memory Map
global system_memory_map
system_memory_map resd 1
