; 16 bit version of the Memory manager that supplies dynamically allocatable
; memory during early boot phase. The physical memory is allocated in
; in this module.

%include "EarlyDynamicMemory.inc"
%include "EarlyConsole.inc"

section .bss
; Physical memory used for early dynamically allocated memory
global early_dynamic_memory
early_dynamic_memory resb EARLY_DYNAMIC_MEMORY_SIZE

section .text
bits 16

; Structure of a memory header:
; 0x00	size		32 bit
; 0x04	previous	32 bit
; 0x08	next		32 bit
; 0x0C	flags		32 bit
;
; flags is a combination of EARLY_MEMORY_HEADER_* bitmasks defined in
; EarlyDynamicMemory.inc
EARLY_DYNAMIC_MEMORY_HEADER_SIZE equ 16

; Function:   EarlyDynamicMemory_init
; Purpose:    Initialize the physical memory for use by the memory manager.
;             Must be called before the first allocation. Fully CPU state
;             preserving.
; Parameters: None.
global EarlyDynamicMemory_init
EarlyDynamicMemory_init:
	push eax

	mov eax, EARLY_DYNAMIC_MEMORY_SIZE - EARLY_DYNAMIC_MEMORY_HEADER_SIZE
	mov [early_dynamic_memory], eax

	xor eax, eax
	mov [early_dynamic_memory + 4], eax
	mov [early_dynamic_memory + 8], eax

	xor eax, eax
	mov [early_dynamic_memory + 12], eax

	pop eax
	ret

; Function:   EarlyDynamicMemory_allocate
; Purpose:    Allocate memory. Fully CPU state preserving.
; Parameters: EAX [IN]:  Requested size in bytes
; Returns:    EAX [OUT]: Pointer to the allocated memory on success, left
;                        unchanged otherwise
;             CARRY:     Set on error (non free memory of requested size),
;                        cleared otherwise
global EarlyDynamicMemory_allocate
EarlyDynamicMemory_allocate:
	push ebx
	push ecx
	push edx
	push eax

	; search for first free block of requested size
	lea ebx, [early_dynamic_memory]

.search_block:
	cmp [ebx], eax
	jb .next_block

	test dword [ebx + 12], EARLY_DYNAMIC_MEMORY_HEADER_OCCUPIED
	jne .next_block

	jmp .block_found

.next_block:
	mov ebx, [ebx + 8]
	or ebx, ebx
	je .no_more_blocks

	jmp .search_block

.block_found:
	; is block big enough for splitting?
	mov ecx, eax
	; additional header + at least 1 byte
	add ecx, EARLY_DYNAMIC_MEMORY_HEADER_SIZE + 1

	cmp [ebx], ecx
	jb .occupy_block

	; location of new header
	mov edx, ebx
	add edx, eax
	add edx, EARLY_DYNAMIC_MEMORY_HEADER_SIZE

	; size of new block in ecx
	mov ecx, [ebx]
	sub ecx, eax
	sub ecx, EARLY_DYNAMIC_MEMORY_HEADER_SIZE

	; initialize new header
	mov [edx], ecx

	mov [edx + 4], ebx

	mov ecx, [ebx + 8]
	mov [edx + 8], ecx

	; keep flags of old header
	mov ecx, [ebx + 12]
	mov [edx + 12], ecx

	; adapt old header
	mov [ebx], eax
	mov [ebx + 8], edx

	; adapt potential next header
	mov ecx, [edx + 8]
	or ecx, ecx
	jz .occupy_block

	mov [ecx + 4], edx

.occupy_block:
	or dword [ebx + 12], EARLY_DYNAMIC_MEMORY_HEADER_OCCUPIED

	; compute address of allocated memory
	mov eax, ebx
	add eax, EARLY_DYNAMIC_MEMORY_HEADER_SIZE

.success:
	clc
	pop ebx			; discard saved copy of eax

.end:
	pop edx
	pop ecx
	pop ebx
	ret


.no_more_blocks:
.error:
	stc
	pop eax
	jmp .end


; Function:   EarlyDynamicMemory_free
; Purpose:    To free previously allocated memory. Fully CPU state preserving.
;             Actually, no real checks if the memory address is valid are
;             performed.
; Parameters: EAX [IN]: Memory chunk start address
; Returns:    CARRY:    Set on error, cleared otherwise
global EarlyDynamicMemory_free
EarlyDynamicMemory_free:
	push eax
	push ebx
	push ecx

	; Check if block lies within dedicated memory range
	lea ebx, [early_dynamic_memory]
	add ebx, EARLY_DYNAMIC_MEMORY_SIZE

	cmp eax, ebx
	jae .error

	sub eax, EARLY_DYNAMIC_MEMORY_HEADER_SIZE
	cmp eax, early_dynamic_memory
	jb .error

	; Check flags
	mov ebx, [eax + 12]
	cmp ebx, EARLY_DYNAMIC_MEMORY_HEADER_OCCUPIED
	jne .error

	; Free block
	and ebx, ~EARLY_DYNAMIC_MEMORY_HEADER_OCCUPIED
	mov [eax + 12], ebx

	; Merge the new free block with neighbours
	; Is there a next block?
	mov ebx, [eax + 8]
	or ebx, ebx
	jz .merge_previous

	; Is the next block free?
	mov ecx, [ebx + 12]
	test ecx, EARLY_DYNAMIC_MEMORY_HEADER_OCCUPIED
	jnz .merge_previous

	; adapt header
	; size
	mov ecx, [eax]
	add ecx, [ebx]
	add ecx, EARLY_DYNAMIC_MEMORY_HEADER_SIZE

	mov [eax], ecx

	; linked list
	mov ecx, [ebx + 8]
	mov [eax + 8], ecx

	; Is there a next-next block?
	or ecx, ecx
	jz .merge_previous

	mov [ecx + 4], eax

.merge_previous:
	; Is there a previous block?
	mov ebx, [eax + 4]
	or ebx, ebx
	jz .merge_done

	; Is the previous block free?
	mov ecx, [ebx + 12]
	test ecx, EARLY_DYNAMIC_MEMORY_HEADER_OCCUPIED
	jnz .merge_done

	; adapt previous header
	; size
	mov ecx, [ebx]
	add ecx, [eax]
	add ecx, EARLY_DYNAMIC_MEMORY_HEADER_SIZE

	mov [ebx], ecx

	; linked list
	mov ecx, [eax + 8]
	mov [ebx + 8], ecx

	; Is there a next block?
	or ecx, ecx
	jz .merge_done

	mov [ecx + 4], ebx

.merge_done:
.success:
	clc

.end:
	pop ecx
	pop ebx
	pop eax
	ret


.error:
	stc
	jmp .end


; Function:   EarlyDynamicMemory_print
; Purpose:    Print memory header list for debugging purpose. Fully CPU state
;             preserving.
; Parameters: None.
global EarlyDynamicMemory_print
EarlyDynamicMemory_print:
	push eax
	push ebx
	push si

	; info
	mov si, .msgInfo
	call print_string

	; early dynamic memory size
	mov si, .msgMemorySize
	call print_string

	mov eax, EARLY_DYNAMIC_MEMORY_SIZE
	call print_hex_dword

	mov si, .msgCrLf
	call print_string

	; print list of headers
	lea ebx, [early_dynamic_memory]

.header_list:
	mov si, .msgStart
	call print_string

	mov eax, ebx
	call print_hex_dword

	mov si, .msgSize
	call print_string

	mov eax, [ebx]
	call print_hex_dword

	mov si, .msgPrevious
	call print_string

	mov eax, [ebx + 4]
	call print_hex_dword

	mov si, .msgNext
	call print_string

	mov eax, [ebx + 8]
	call print_hex_dword

	mov eax, [ebx + 12]
	test eax, EARLY_DYNAMIC_MEMORY_HEADER_OCCUPIED
	je .free

	mov si, .msgOccupied
	jmp .print_status

.free:
	mov si, .msgFree

.print_status:
	call print_string

	mov si, .msgCrLf
	call print_string

	mov ebx, [ebx + 8]
	or ebx, ebx
	jz .header_list_end

	; retrieve next block
	jmp .header_list

.header_list_end:
	mov si, .msgCrLf
	call print_string

.end:
	pop si
	pop ebx
	pop eax
	ret

.msgInfo		db '******************* Early Dynamic Memory Manager - Debug info *****************', 0dh, 0ah, 0
.msgMemorySize	db 'EARLY_DYNAMIC_MEMORY_SIZE: ', 0
.msgCrLf 		db 0dh, 0ah, 0
.msgStart		db 'Start: 0x', 0
.msgSize		db ', Size: ', 0
.msgPrevious	db 'h, Prev: 0x', 0
.msgNext		db ', Next: 0x', 0
.msgOccupied	db ' [o]', 0
.msgFree		db ' [f]', 0
