; 16 bit version of the Memory manager that supplies dynamically allocatable
; memory during early boot phase. The physical memory is allocated in
; CommonlyUsedData.asm

%include "CommonConstants.inc"
%include "CommonlyUsedData.inc"
%include "Loader_console.inc"

bits 32

; Structure of a memory header:
; 0x00	size		32 bit
; 0x04	previous	32 bit
; 0x08	next		32 bit
; 0x0C	flags		32 bit
;
; flags is a combination of EARLY_MEMORY_HEADER_* bitmasks defined in
; CommonConstants.h
EARLY_DYNAMIC_MEMORY_HEADER_SIZE equ 16

; Function:   EarlyDynamicMemory_init
; Purpose:    Initialize the physical memory for use by the memory manager.
;             Must be called before the first allocation. Fully CPU state
;             preserving.
; Parameters: None.
global p_EarlyDynamicMemory_init
p_EarlyDynamicMemory_init:
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
global p_EarlyDynamicMemory_allocate
p_EarlyDynamicMemory_allocate:
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
global p_EarlyDynamicMemory_free
p_EarlyDynamicMemory_free:
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
