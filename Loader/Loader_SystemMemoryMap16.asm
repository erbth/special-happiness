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

	; eax = esi.pop_front
	mov eax, esi
	mov esi, [esi + 4]

	xor ebx, ebx
	mov [esi], ebx

	; if (edi = NULL)
	or edi, edi
	jz .new_list_empty_yet

	; else
	; Find position in the already existing part of the new list
	; ebx = newList
	mov ebx, edi

.find_position_loop:
	; ebx->value >= eax->value?
	; Only jb, jae working, because only CF is set right. Since sorting doesn't
	; need to be stable, it is ok to use >= instead of >.
	mov ecx, [ebx + 0ch]
	mov edx, [ebx + 0ch + 4]

	sub ecx, [eax + 0ch]
	sbb edx, [eax + 0ch + 4]

	; if not, continue
	jb .find_position_check_end

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
	jz .find_position_adjust_start

	mov [ecx + 4], eax

.find_position_adjust_start:
	; if (ebx == edi)	// that is, eax was prepended
	cmp ebx, edi
	jne .sort_next_round

	mov edi, eax
	jmp .sort_next_round

.find_position_check_end:
	; At the end of the so-far new list?
	; ebx->next == NULL?
	mov ecx, [ebx + 4]
	or ecx, ecx

	; If not, continue
	jnz .find_position_next_round

	; If so, append eax; break
	; ebx->next = eax
	mov [ebx + 4], eax

	; eax->prev = ebx
	mov [eax], ebx

	; eax->next = NULL
	xor ecx, ecx
	mov [eax + 4], ecx

	; Element appended.
	jmp .sort_next_round

.find_position_next_round:
	mov ebx, [ebx + 4]
	jmp .find_position_loop

.new_list_empty_yet:
	; ... edi = eax; eax->prev = eax->next = NULL
	xor ebx, ebx
	mov [eax], ebx
	mov [eax + 4], ebx

	mov edi, eax

.sort_next_round:
	jmp .sort_loop


.sort_done:
	; list = new list
	mov [system_memory_map], edi

.end:
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret


; Function:   SystemMemoryMap_collate
; Purpose:    to combine adjacent blocks of same type to one block of memory.
;             Fully CPU state preserving.
; Parameters: None.
global SystemMemoryMap_collate
SystemMemoryMap_collate:
	push eax

.end:
	pop eax
	ret


; Function:   SystemMemoryMap_makeDisjoint
; Purpose:    to remove overlapping in the memory map with the following
;             priority: 1.) reserved, 2.) ACPI NVS, 3.) ACPI Reclaim,
;             4.) Well-known-PC locations, 5.) Loader.text+data,
;             6.) Loader.bss, 7.) Kernel.text+data, 8.) Kernel.bss, 9.) free
; Parameters: None.
; Returns:    CARRY: Set on error, cleared otherwise
global SystemMemoryMap_makeDisjoint
SystemMemoryMap_makeDisjoint:
	push eax
	push ebx
	push ecx
	push edx		; general purpose
	push esi
	push edi		; general purpose

	; Sort list

	; for each type in priority_list:
	xor ecx, ecx

.types_loop:
	mov eax, [.priority_list + ecx * 4]

	jmp .all_elements_handled

	;	for each element of list:
	; element =: ebx
	mov ebx, [system_memory_map]

.all_elements_loop:
	or ebx, ebx
	jz .all_elements_handled

	;		if (element.type == type):
	cmp [ebx + 8], eax
	jne .all_elements_continue

	;			for each c of list:
	mov esi, [system_memory_map]

.xprod_loop:
	or esi, esi
	jz .xprod_handled

	;				if (element intersects with c):
	; ebx < esi && ebx + ebx.size > esi ?
	mov edx, [ebx + 0ch]
	mov edi, [ebx + 0ch + 4]

	sub edx, [esi + 0ch]
	sbb edi, [esi + 0ch + 4]

	jae .xprod_loop_ebx_above

	; ebx + ebx.size
	mov edx, [ebx + 0ch]
	mov edi, [ebx + 0ch + 4]

	add edx, [ebx + 14h]
	adc edi, [ebx + 14h + 4]

	; ebx + ebx.size - 1 >= esi
	stc
	sbb edx, [esi + 0ch]
	sbb edi, [esi + 0ch + 4]
	jae .xprod_loop_intersect

	jmp .xprod_continue

.xprod_loop_ebx_above:
	; esi <= ebx !, esi + esi.size > ebx ?
	; esi + esi.size
	mov edx, [esi + 0ch]
	mov edi, [esi + 0ch + 4]

	add edx, [esi + 14h]
	adc edi, [esi + 14h + 4]

	; esi + esi.size - 1 >= eax
	stc
	sbb edx, [ebx + 0ch]
	sbb edi, [ebx + 0ch + 4]
	jae .xprod_loop_intersect

	jmp .xprod_continue

.xprod_loop_intersect:
	;					if (element != c):
	cmp ebx, esi
	je .xprod_continue

	;						if (element.type == c.type):
	mov edx, [ebx + 8]
	cmp edx, [esi + 8]
	jne .xprod_loop_types_differ

	;							unite element, c (c.start > element.start)
	;							--> element swallows c
	; ebx.size = ebx.size + esi.size - (ebx + ebx.size - esi)
	;          = ebx.size + esi.size + esi - ebx - ebx.size
	;          = esi + esi.size - ebx = esi - ebx + esi.size
	mov edx, [esi + 0ch]
	mov edi, [esi + 0ch + 4]

	sub edx, [ebx + 0ch]
	sbb edi, [ebx + 0ch + 4]

	add edx, [esi + 14h]
	adc edi, [esi + 14h + 4]

	mov [ebx + 14h], edx
	mov [ebx + 14h + 4], edi

	; remove element (ebx) from list
	mov edx, [ebx]
	mov edi, [ebx + 4]

	; if (ebx.prev) ebx.prev.next = ebx.next
	or edx, edx
	jz .xprod_loop_intersect_remove_foreward

	mov [edx + 4], edi

.xprod_loop_intersect_remove_foreward:
	; if (ebx.next) ebx.next.prev = ebx.prev
	or edi, edi
	jz .xprod_loop_intersect_free_element

	mov [edi], edx

.xprod_loop_intersect_free_element:
	; free memory of element (ebx)
	push eax

	mov eax, ebx

	; c := c.prev, only then c := c.next in .all_elements_continue will have
	; the same effect as if c was not removed.
	mov ebx, [ebx]
	call EarlyDynamicMemory_free

	pop eax
	jc .error

	jmp .xprod_continue

.xprod_loop_types_differ:
	;						else:
	;							Entry d = NULL
	xor edx, edx
	mov [.entryD], edx

	;
	;							if (element + element.size > c + c.size):
	;								add d = [c + c.size,element + element.size)

	;							if (element < c):
	; ebx < esi ?
	mov edx, [ebx + 0ch]
	mov edi, [ebx + 0ch + 4]

	sub edx, [esi + 0ch]
	sbb edi, [esi + 0ch + 4]
	jae .xprod_loop_types_differ_no_lower

	;								element.size = c - element
	; ebx.size = esi - ebx
	mov edx, [esi + 0ch]
	mov edi, [esi + 0ch + 4]

	sub edx, [ebx + 0ch]
	sbb edi, [ebx + 0ch + 4]

	jmp .xprod_continue

.xprod_loop_types_differ_no_lower:
	;							else:
	;								remove element
	mov edx, [ebx]
	mov edi, [ebx + 4]

	; if (ebx.prev) ebx.prev.next = ebx.next
	or edx, edx
	jz .xprod_loop_types_differ_upper_remove_foreward

	mov [edx + 4], edi

.xprod_loop_types_differ_upper_remove_foreward:
	; if (ebx.next) ebx.next.prev = ebx.prev
	or edi, edi
	jz .xprod_loop_types_differ_upper_free_element

	mov [edi + 4], edx

.xprod_loop_types_differ_upper_free_element:
	; free memory of element (ebx)
	push eax
	mov eax, ebx

	; element := element.prev, otherwise element := element.next in
	; .all_elements_continue would not have the same effect as if element was
	; not removed.
	mov ebx, [ebx]
	call EarlyDynamicMemory_free
	pop eax

	jc .error

	;
	;							if (d):
	mov edx, [.entryD]
	or edx, edx
	jz .xprod_continue

	;								element = d
	mov ebx, [.entryD]
	jmp .xprod_continue

.xprod_continue:
	; Next element
	mov esi, [esi + 4]

.xprod_handled:
.all_elements_continue:
	; Next element
	mov ebx, [ebx + 4]

.all_elements_handled:
	; increase types loop index
	inc ecx
	cmp ecx, 9
	jb .types_loop

.success:
	clc

.end:
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret


.error:
	stc
	jmp .end

.priority_list:
	dd SYSTEM_MEMORY_MAP_ENTRY_FREE
	dd SYSTEM_MEMORY_MAP_ENTRY_KERNEL_BSS
	dd SYSTEM_MEMORY_MAP_ENTRY_KERNEL_TEXT_DATA
	dd SYSTEM_MEMORY_MAP_ENTRY_LOADER_BSS
	dd SYSTEM_MEMORY_MAP_ENTRY_LOADER_TEXT_DATA
	dd SYSTEM_MEMORY_MAP_ENTRY_WELL_KNOWN_PC
	dd SYSTEM_MEMORY_MAP_ENTRY_ACPI_RECLAIM
	dd SYSTEM_MEMORY_MAP_ENTRY_ACPI_NVS
	dd SYSTEM_MEMORY_MAP_ENTRY_RESERVED

.entryD dd 0


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

	cmp eax, SYSTEM_MEMORY_MAP_ENTRY_LOADER_TEXT_DATA
	je .select_loader_text_data

	cmp eax, SYSTEM_MEMORY_MAP_ENTRY_LOADER_BSS
	je .select_loader_bss

	cmp eax, SYSTEM_MEMORY_MAP_ENTRY_KERNEL_TEXT_DATA
	je .select_kernel_text_data

	cmp eax, SYSTEM_MEMORY_MAP_ENTRY_KERNEL_BSS
	je .select_kernel_bss

	cmp eax, SYSTEM_MEMORY_MAP_ENTRY_WELL_KNOWN_PC
	je .select_well_known_pc

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

.select_loader_text_data:
	mov si, .msgEntryLoaderTD
	jmp .print_type

.select_loader_bss:
	mov si, .msgEntryLoaderBss
	jmp .print_type

.select_kernel_text_data:
	mov si, .msgEntryKernelTD
	jmp .print_type

.select_kernel_bss:
	mov si, .msgEntryKernelBss
	jmp .print_type

.select_well_known_pc:
	mov si, .msgEntryWellKnownPc
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
.msgEntryLoaderTD		db '[ Loader.TD  ]', 0
.msgEntryLoaderBss		db '[ Loader.bss ]', 0
.msgEntryKernelTD		db '[ Kernel.TD  ]', 0
.msgEntryKernelBss		db '[ Kernel.bss ]', 0
.msgEntryWellKnownPc	db '[ Well known ]', 0
.msgEntryUndefined		db '[ undefined  ]', 0
.msgAddress				db 0dh, 0ah, '    Address: 0x', 0
.msgPrevious			db ', Previous: 0x', 0
.msgNext				db ', Next: 0x', 0
.msgCrLf				db 0dh, 0ah, 0
.msgEnd					db '--- end ---', 0dh, 0ah, 0
