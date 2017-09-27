; Data structure for storing the system memory map

%include "CommonConstants.inc"
%include "CommonlyUsedData.inc"
%include "Loader_EarlyDynamicMemory16.inc"
%include "Loader_console.inc"

bits 16

; System Memory Map entry:
; 0x00	previous	32 bit
; 0x04	next		32 bit
; 0x08	type		32 bit
; 0x0C	start		64 bit
; 0x14	size		64 bit
;
; type is one of SYSTEM_MEMORY_MAP_ENTRY_* defined in CommonConstants.h
SYSTEM_MEMORY_MAP_ENTRY_SIZE equ 28


; Function:   SystemMemoryMap_init
; Purpose:    Initialize the memory map. Must be called before any other
;             function of this module. Fully CPU state preserving.
; Parameters: None.
global SystemMemoryMap_init
SystemMemoryMap_init:
	push eax

	xor eax, eax
	mov [system_memory_map], eax

	pop eax
	ret

; Function:   SystemMemoryMap_add
; Purpose:    Add a memory range to the map.
;             Fully CPU state preserving.
; Parameters: EBX:EAX [IN]: Start address
;             EDX:ECX [IN]: Size in bytes
;             ESI     [IN]: One of SYSTEM_MEMORY_MAP_ENTRY_* describing the
;                           new entry (be CAREFUL, not checked !)
; Returns:    CARRY:        Set on error, cleared on success
global SystemMemoryMap_add
SystemMemoryMap_add:
	push eax
	push edi

	; eax shall not be altered, but is needed as parameter
	xchg eax, edi

	; Allocate memory for the new entry
	mov eax, SYSTEM_MEMORY_MAP_ENTRY_SIZE
	call EarlyDynamicMemory_allocate
	jc .error

	xchg edi, eax

	; Fill out fields
	; Start address
	mov [edi + 0ch], eax
	mov [edi + 0ch + 4], ebx

	; Size
	mov [edi + 14h], ecx
	mov [edi + 14h + 4], edx

	; type
	mov [edi + 8], esi

	; Prepend the entry to the list (it's O(1))
	xor eax, eax
	mov [edi], eax

	mov eax, [system_memory_map]
	mov [edi + 4], eax
	mov [system_memory_map], edi

	or eax, eax
	jz .adding_list_done

	mov [eax], edi

.adding_list_done:
.success:
	clc

.end:
	pop edi
	pop eax
	ret


.error:
	stc
	jmp .end


; Function:   SystemMemoryMap_sort
; Purpose:    to sort the memory map by start address.
;             Fully CPU state preserving.
; Parameters: None.
;
; Pseudo-code:
;
;	Input: list
;	Output: list
;
;	decl newList = NULL
;
;	while (list != NULL)
;		e = list
;		list = list->next
;		list->prev = 0
;
;		if (newList == NULL)
;			e->next = e->prev = NULL
;			newList = e
;		else
;			b = newList
;
;			for (;;)
;				if (b.value > e.value)
;					e->prev = b->prev
;					e->prev->next=e
;					e->next = b
;					e->next->prev = e
;					break
;
;				if (b->next == NULL)
;					b->next = e
;					e->prev = b
;					e->next = NULL
;					break;
;
;				b = b->next
;
;	list = newList
;
global SystemMemoryMap_sort
SystemMemoryMap_sort:
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi

	; esi = original list
	mov esi, [system_memory_map]

	; edi = new list
	xor edi, edi

.sort_loop:
	; Is an unsorted element left?
	or esi, esi
	jz .sort_done

	mov eax, esi
	mov esi, [esi + 4]

	xor ebx, ebx
	mov [esi], ebx

	or edi, edi
	jz .new_list_empty_yet

	; Find position in the already existing part of the new list
	mov ebx, edi

.find_position_loop:
	; ebx->value > eax->value?
	mov ecx, [ebx + 0ch]
	mov edx, [ebx + 0ch + 4]

	sub ecx, [eax + 0ch]
	sbb edx, [eax + 0ch + 4]
	jbe .find_position_check_end

	; Position found. Insert.
	; eax->next = ebx
	mov [eax + 4], ebx

	; eax->prev = ebx->prev
	mov ecx, [ebx]
	mov [eax], ecx

	; ebx->prev = eax
	mov [ebx], eax

	; if (eax->prev) eax->prev->next = eax
	mov ecx, [eax]
	or ecx, ecx
	jz .find_position_insert_no_prev

	mov [ecx + 4], eax

.find_position_insert_no_prev:
	; Element inserted.
	jmp .sort_next_round

.find_position_check_end:
	; At the end of the so-far new list?
	mov ecx, [ebx + 4]
	or ecx, ecx
	jnz .find_position_loop

	; ebx->next = eax
	mov [ebx + 4], eax

	; eax->prev = ebx
	mov [eax], ebx

	; eax->next = NULL
	xor ecx, ecx
	mov [eax + 4], ecx

	; Element appended.
	jmp .sort_next_round

.new_list_empty_yet:
	xor ebx, ebx
	mov [eax], ebx
	mov [eax + 4], ebx

	mov edi, eax

.sort_next_round:
	jmp .sort_loop


.sort_done:
	mov [system_memory_map], edi

.end:
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret


; Function:   SystemMemoryMap_print
; Purpose:    to print the memory map for debugging purposes.
;             Fully CPU state preserving
; Parameters: None.
global SystemMemoryMap_print
SystemMemoryMap_print:
	push eax
	push ebx
	push si

	; Print info message
	mov si, .msgInfo
	call print_string

	mov ebx, [system_memory_map]

	; Print list start address
	mov si, .msgListStart
	call print_string

	mov eax, ebx
	call print_hex_dword

	mov si, .msgCrLf
	call print_string

.print_entry:
	or ebx, ebx
	jz .print_end

	; Start
	mov si, .msgStart
	call print_string

	mov eax, [ebx + 0ch + 4]
	call print_hex_dword

	mov eax, [ebx + 0ch]
	call print_hex_dword

	; Size
	mov si, .msgSize
	call print_string

	mov eax, [ebx + 14h + 4]
	call print_hex_dword

	mov eax, [ebx + 14h]
	call print_hex_dword

	mov si, .msgSizeEnd
	call print_string

	; Type
	mov eax, [ebx + 8]
	cmp eax, SYSTEM_MEMORY_MAP_ENTRY_FREE
	je .select_free

	cmp eax, SYSTEM_MEMORY_MAP_ENTRY_RESERVED
	je .select_reserved

	cmp eax, SYSTEM_MEMORY_MAP_ENTRY_ACPI_RECLAIM
	je .select_acpi_reclaim

	cmp eax, SYSTEM_MEMORY_MAP_ENTRY_ACPI_NVS
	je .select_acpi_nvs

	mov si, .msgEntryUndefined

.print_type:
	call print_string

	; List data
	; Entry's Address
	mov si, .msgAddress
	call print_string

	mov eax, ebx
	call print_hex_dword

	; Previous entry
	mov si, .msgPrevious
	call print_string

	mov eax, [ebx]
	call print_hex_dword

	; Next entry
	mov si, .msgNext
	call print_string

	mov eax, [ebx + 4]
	call print_hex_dword

	mov si, .msgCrLf
	call print_string

	; Next entry
	mov ebx, [ebx + 4]
	jmp .print_entry

.print_end:
	mov si, .msgEnd
	call print_string

.end:
	pop si
	pop ebx
	pop eax
	ret


.select_free:
	mov si, .msgEntryFree
	jmp .print_type

.select_reserved:
	mov si, .msgEntryReserved
	jmp .print_type

.select_acpi_reclaim:
	mov si, .msgEntryAcpiReclaim
	jmp .print_type

.select_acpi_nvs:
	mov si, .msgEntryAcpiNVS
	jmp .print_type

.msgInfo				db '****************************** System Memory Map ******************************', 0dh, 0ah, 0
.msgListStart			db 'system_memory_map: 0x', 0
.msgStart				db 'Start: 0x', 0
.msgSize				db ', Size: ', 0
.msgSizeEnd				db 'h ', 0
.msgEntryFree			db '[    free    ]', 0
.msgEntryReserved		db '[  reserved  ]', 0
.msgEntryAcpiReclaim	db '[ACPI RECLAIM]', 0
.msgEntryAcpiNVS		db '[  ACPI NVS  ]', 0
.msgEntryUndefined		db '[ undefined  ]', 0
.msgAddress				db 0dh, 0ah, '    Address: 0x', 0
.msgPrevious			db ', Previous: 0x', 0
.msgNext				db ', Next: 0x', 0
.msgCrLf				db 0dh, 0ah, 0
.msgEnd					db '--- end ---', 0dh, 0ah, 0
