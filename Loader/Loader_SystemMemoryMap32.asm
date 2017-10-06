; Data structure for storing the system memory map

%include "CommonConstants.inc"
%include "CommonlyUsedData.inc"
%include "Loader_EarlyDynamicMemory32.inc"
%include "Loader_console32.inc"

bits 32

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
global p_SystemMemoryMap_init
p_SystemMemoryMap_init:
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
global p_SystemMemoryMap_add
p_SystemMemoryMap_add:
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi

	; If size == 0, we're done.
	or ecx, ecx
	jnz .size_bigger_0

	or edx, edx
	jnz .size_bigger_0
	jmp .success

.size_bigger_0:
	; Create new entry
	push eax

	mov eax, SYSTEM_MEMORY_MAP_ENTRY_SIZE
	call p_EarlyDynamicMemory_allocate

	mov edi, eax
	pop eax

	jc .error

	; Fill out fields
	; Type
	mov [edi + 8], esi

	; Base
	mov [edi + 0ch], eax
	mov [edi + 0ch + 4], ebx

	; Size
	mov [edi + 14h], ecx
	mov [edi + 14h + 4], edx

	; Meta data
	xor eax, eax
	mov [edi], eax
	mov [edi + 4], eax

	mov ebx, edi

	; Add ebx to the list
	; esi = current list
	mov esi, [system_memory_map]

	; edi = new list
	xor edi, edi

	; eax = popFront(esi)
	call SystemMemoryMap_popFront
	mov eax, ecx

	; Main loop that runs until all ranges are handled
.main_loop:
	; If eax == 0 && ebx == 0, we're done
	or eax, eax
	jnz .main_loop_body

	or ebx, ebx
	jnz .main_loop_body
	jmp .main_loop_done

.main_loop_body:
	; If eax == 0, add ebx and continue
	or eax, eax
	jnz .main_loop_check_ebx_0

	mov edx, ebx
	call SystemMemoryMap_pushBack

	xor ebx, ebx
	jmp .main_loop

.main_loop_check_ebx_0:
	; If ebx == 0, add eax
	or ebx, ebx
	jnz .main_loop_both_valid

	mov edx, eax
	call SystemMemoryMap_pushBack

	; eax = popFront(esi)
	call SystemMemoryMap_popFront
	mov eax, ecx
	jmp .main_loop

.main_loop_both_valid:
	; Distinguish eax.base <= ebx.base
	; equivalent: ebx.base >= eax.base
	mov ecx, [ebx + 0ch]
	mov edx, [ebx + 0ch + 4]

	sub ecx, [eax + 0ch]
	sbb edx, [eax + 0ch + 4]
	jb .main_loop_ebx_base_lower

	; eax.base <= ebx.base
	; eax intersects with ebx?
	call SystemMemoryMap_intersectsWith
	jnc .eax_base_lower_no_intersection

	; eax, ebx intersect
	call SystemMemoryMap_addIntersectingElement
	jc .error

	; If eax.size == 0, free eax and fetch next range from esi
	; Then, continue.
	mov ecx, [eax + 14h]
	mov edx, [eax + 14h + 4]

	or ecx, ecx
	jnz .main_loop

	or edx, edx
	jnz .main_loop

	; Free memory
	call p_EarlyDynamicMemory_free
	jc .error

	; Fetch next element
	call SystemMemoryMap_popFront
	mov eax, ecx
	jmp .main_loop

.eax_base_lower_no_intersection:
	; eax, ebx disjoint
	; Add eax and fetch next range from esi
	mov edx, eax
	call SystemMemoryMap_pushBack

	call SystemMemoryMap_popFront
	mov eax, ecx
	jmp .main_loop

.main_loop_ebx_base_lower:
	; eax.base > ebx.base
	; Do eax and ebx intersect?
	call SystemMemoryMap_intersectsWith
	jnc .ebx_base_lower_no_intersection

	; eax, ebx intersect
	; eax.base > ebx.base
	xchg eax, ebx

	call SystemMemoryMap_addIntersectingElement
	jc .error

	xchg eax, ebx

	; If ebx.size == 0, set ebx = 0
	; Then, continue.
	mov ecx, [ebx + 14h]
	mov edx, [ebx + 14h + 4]

	or ecx, ecx
	jnz .main_loop

	or edx, edx
	jnz .main_loop

	; Free memory
	push eax

	mov eax, ebx
	call p_EarlyDynamicMemory_free

	pop eax
	jc .error

	xor ebx, ebx
	jmp .main_loop

.ebx_base_lower_no_intersection:
	; eax, ebx disjoint
	; Add ebx
	mov edx, ebx
	call SystemMemoryMap_pushBack

	xor ebx, ebx
	jmp .main_loop

.main_loop_done:
	; Write new list to memory
	mov [system_memory_map], edi

	; Consolidate list
	call SystemMemoryMap_consolidate
	jc .error

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


; Function:   SystemMemoryMap_addIntersectingElement
; Purpose:    helper function for SystemMemoryMap_add, used when two memory
;             ranges intersect. Fully CPU state preserving.
; Parameters: EDI [IN OUT]: Map's list to which ranges are added
;             EAX [IN]:     Range with lower (or equal) base address
;             EBX [IN]:     Range with higher (or equal) base address
; Returns:    CARRY:        Set on error (memory allocation!),
;                           cleared otherwise.
SystemMemoryMap_addIntersectingElement:
	push ecx
	push edx

	; For now, always prefer right element (ebx)
	; eax.base < ebx.base ?
	mov ecx, [eax + 0ch]
	mov edx, [eax + 0ch + 4]

	sub ecx, [ebx + 0ch]
	sbb edx, [ebx + 0ch + 4]
	jae .right_part

	; If so, add [eax.base, ebx.base)
	; Allocate memory for the new entry
	push eax

	mov eax, SYSTEM_MEMORY_MAP_ENTRY_SIZE
	call p_EarlyDynamicMemory_allocate

	mov edx, eax
	pop eax

	jc .error

	; Fill out fields
	; Meta data
	xor ecx, ecx
	mov [edx], ecx
	mov [edx + 4], ecx

	; Type
	mov ecx, [eax + 8]
	mov [edx + 8], ecx

	; edx.base = eax.base
	mov ecx, [eax + 0ch]
	mov [edx + 0ch], ecx

	mov ecx, [eax + 0ch + 4]
	mov [edx + 0ch + 4], ecx

	; edx.size = ebx.base - eax.base
	mov ecx, [ebx + 0ch]
	sub ecx, [eax + 0ch]
	mov [edx + 14h], ecx

	mov ecx, [ebx + 0ch + 4]
	sbb ecx, [eax + 0ch + 4]
	mov [edx + 14h + 4], ecx

	; eax.size -= edx.size
	mov ecx, [edx + 14h]
	sub [eax + 14h], ecx

	mov ecx, [edx + 14h + 4]
	sbb [eax + 14h + 4], ecx

	; eax.base = ebx.base
	mov ecx, [ebx + 0ch]
	mov [eax + 0ch], ecx

	mov ecx, [ebx + 0ch + 4]
	mov [eax + 0ch + 4], ecx

	; Add edx to edi
	call SystemMemoryMap_pushBack

.right_part:
	; Compute eax.base + eax.size and ebx.base + ebx.size and put it onto the
	; stack.
	; esp + C: HIGH(ebx.base + ebx.size)
	; esp + 8: LOW (ebx.base + ebx.size)
	; esp + 4: HIGH(eax.base + eax.size)
	; esp + 0: LOW (eax.base + eax.size)

	; ebx.base + ebx.size
	mov ecx, [ebx + 0ch]
	mov edx, [ebx + 0ch + 4]

	add ecx, [ebx + 14h]
	adc edx, [ebx + 14h + 4]

	push edx
	push ecx

	; eax.base + eax.size
	mov ecx, [eax + 0ch]
	mov edx, [eax + 0ch + 4]

	add ecx, [eax + 14h]
	adc edx, [eax + 14h + 4]

	push edx
	push ecx

	; eax.base + eax.size > ebx.base + ebx.size ?
	; equivalent: ebx.base + ebx.size < eax.base + eax.size
	mov ecx, [esp + 8]
	mov edx, [esp + 0ch]

	sub ecx, [esp]
	sbb edx, [esp + 4]

	jae .right_part_check_ebx_bigger

	; Adapt eax to represent the right part
	; eax.size := eax.base + eax.size - (ebx.base + ebx.size)
	mov ecx, [esp]
	mov edx, [esp + 4]

	sub ecx, [esp + 8]
	sbb edx, [esp + 0ch]

	; Write to memory
	mov [eax + 14h], ecx
	mov [eax + 14h + 4], edx

	; eax.base = ebx.base + ebx.size
	mov ecx, [esp + 8]
	mov edx, [esp + 0ch]

	mov [eax + 0ch], ecx
	mov [eax + 0ch + 4], edx

	; r.type = preferred type
	call SystemMemoryMap_getPreferredType
	mov [ebx + 8], ecx
	jmp .right_part_clean_stack

.right_part_check_ebx_bigger:
	; ebx.base + ebx.size > eax.base + eax.size ?
	; equivalent: eax.base + eax.size < ebx.base + ebx.size ?
	mov ecx, [esp]
	mov edx, [esp + 4]

	sub ecx, [esp + 8]
	sbb edx, [esp + 0ch]

	jae .no_right_part

	; ebx.size = ebx.base + ebx.size - (eax.base + eax.size)
	mov ecx, [esp + 8]
	mov edx, [esp + 0ch]

	sub ecx, [esp]
	sbb edx, [esp + 4]

	mov [ebx + 14h], ecx
	mov [ebx + 14h + 4], edx

	; ebx.base = eax.base + eax.size
	mov ecx, [esp]
	mov edx, [esp + 4]

	mov [ebx + 0ch], ecx
	mov [ebx + 0ch + 4], edx

	; l.type = preferred type
	call SystemMemoryMap_getPreferredType
	mov [eax + 8], ecx
	jmp .right_part_clean_stack

.no_right_part:
	; No right part. Signal this by setting eax.size = 0.
	xor ecx, ecx
	mov [eax + 14h], ecx
	mov [eax + 14h + 4], ecx

	; ebx.type = preferred type
	call SystemMemoryMap_getPreferredType
	mov [ebx + 8], ecx
	jmp .right_part_clean_stack

.right_part_clean_stack:
	add esp, 16

.success:
	clc

.end:
	pop edx
	pop ecx
	ret

.error:
	stc
	jmp .end


; Function:   SystemMemoryMap_getPreferredType
; Purpose:    to return the preferred type of the two memory ranges.
;             Helper function for SystemMemoryMap_addIntersectingElement.
;             Fully CPU state preserving.
; Parameters: EAX [IN]:  First memory range
;             EBX [IN]:  Second memory range
; Returns:    ECX [OUT]: The preferred type of the two ranges.
SystemMemoryMap_getPreferredType:
	push edx

	; eax.type > ebx.type ?
	mov ecx, [eax + 8]
	mov edx, [ebx + 8]

	cmp ecx, edx
	jbe .ebx_bigger

	; If so, ebx.type is preferred
	mov ecx, edx
	jmp .end

.ebx_bigger:
	; If ebx.type > eax.type, eax.type is preferred.

.end:
	pop edx
	ret


; Function:   SystemMemoryMap_consolidate
; Purpose:    helper function for SystemMemoryMap_add, consolidates touching
;             memory ranges. Fully CPU state preserving.
; Parameters: None.
; Returns:    CARRY: Set on error, cleared otherwise.
SystemMemoryMap_consolidate:
	push eax
	push ebx
	push ecx

	; Fetch the list's start address
	mov eax, [system_memory_map]

	; If the list's empty, we're done.
	or eax, eax
	jz .success

	; Main loop to walk through list
.main_loop:
	; Get eax.next
	mov ebx, [eax + 4]
	or ebx, ebx
	jz .success

	; Are eax, ebx in touch?
	call SystemMemoryMap_inTouchWith
	jnc .no_merge

	; eax.type == ebx.type ?
	mov ecx, [eax + 8]
	cmp ecx, [ebx + 8]
	jne .no_merge

	; eax, ebx are in touch, remove ebx from list
	; eax.next = ebx.next
	mov ecx, [ebx + 4]
	mov [eax + 4], ecx

	; if ebx.next, ebx.next.previous = eax
	or ecx, ecx
	jz .in_touch_adjust_size

	mov [ecx], eax

.in_touch_adjust_size:
	; eax.size += ebx.size
	mov ecx, [ebx + 14h]
	add [eax + 14h], ecx

	mov ecx, [ebx + 14h + 4]
	add [eax + 14h + 4], ecx

	; Free memory
	push eax

	mov eax, ebx
	call p_EarlyDynamicMemory_free

	pop eax

	jc .error
	jmp .main_loop

.no_merge:
	; Next element
	mov eax, ebx
	jmp .main_loop

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


; Function:   SystemMemoryMap_intersectsWith
; Purpose:    to find out if two memory ranges intersect.
;             Fully CPU state preserving.
;             For module-local use only.
; Parameters: EAX [IN]: First range
;             EBX [IN]: Second range
; Returns:    CARRY:    Set if ranges intersect, cleared otherwise
SystemMemoryMap_intersectsWith:
	push ecx
	push edx
	push esi
	push edi

	; If eax.size == 0 || ebx.size == 0, we're done.
	mov ecx, [eax + 14h]
	or ecx, ecx
	jnz .check_ebx_size

	mov ecx, [eax + 14h + 4]
	or ecx, ecx
	jnz .check_ebx_size
	jmp .no_intersection

.check_ebx_size:
	mov ecx, [ebx + 14h]
	or ecx, ecx
	jnz .no_size_0

	mov ecx, [ebx + 14h + 4]
	or ecx, ecx
	jnz .no_size_0
	jmp .no_intersection

.no_size_0:
	; eax.base < ebx.base?
	mov ecx, [eax + 0ch]
	mov edx, [eax + 0ch + 4]

	sub ecx, [ebx + 0ch]
	sbb edx, [ebx + 0ch + 4]
	jae .eax_base_bigger

	; Intersection exactly if eax.base + eax.size - 1 >= ebx.base
	mov ecx, [eax + 0ch]
	mov edx, [eax + 0ch + 4]

	; eax.base + eax.size
	add ecx, [eax + 14h]
	adc edx, [eax + 14h + 4]

	; - 1 done separately from comparison for handling
	; eax.base + eax.size = 2^64.
	; This is possible, because eax.size > 0 here.
	xor esi, esi
	inc esi
	xor edi, edi

	sub ecx, esi
	sbb edx, edi

	; Actual comparison
	sub ecx, [ebx + 0ch]
	sbb edx, [ebx + 0ch + 4]
	jae .intersection
	jmp .no_intersection


.eax_base_bigger:
	; Intersection exactly if ebx.base + ebx.size - 1 >= eax.base
	mov ecx, [ebx + 0ch]
	mov edx, [ebx + 0ch + 4]

	; ebx.base + ebx.size
	add ecx, [ebx + 14h]
	adc edx, [ebx + 14h + 4]

	; - 1 (see above)
	xor esi, esi
	inc esi
	xor edi, edi

	sub ecx, esi
	sbb edx, edi

	; Actual comparison
	sub ecx, [eax + 0ch]
	sbb edx, [eax + 0ch + 4]
	jae .intersection
	jmp .no_intersection

.intersection:
	stc
	jmp .end

.no_intersection:
	clc

.end:
	pop edi
	pop esi
	pop edx
	pop ecx
	ret


; Function:   SystemMemoryMap_inTouchWith
; Purpose:    to find out if two memory ranges have touching borders that is
;             if there's no space between their borders and they're disjoint.
;             Fully CPU state preserving.
; Parameters: EAX [IN]: First range
;             EBX [IN]: Second range
; Returns:    CARRY:    Set if the ranges are touching, cleared otherwise
SystemMemoryMap_inTouchWith:
	push ecx
	push edx

	; If eax.size == 0 || ebx.size == 0, we're done.
	mov ecx, [eax + 14h]
	or ecx, ecx
	jnz .check_ebx_size_0

	mov ecx, [eax + 14h + 4]
	jnz .check_ebx_size_0
	jmp .not_touching

.check_ebx_size_0:
	mov ecx, [ebx + 14h]
	or ecx, ecx
	jnz .no_size_0

	mov ecx, [ebx + 14h + 4]
	or ecx, ecx
	jnz .no_size_0
	jmp .not_touching

.no_size_0:
	; eax.base + eax.size == ebx.base ?
	mov ecx, [eax + 0ch]
	mov edx, [eax + 0ch + 4]

	add ecx, [eax + 14h]
	adc edx, [eax + 14h + 4]

	cmp ecx, [ebx + 0ch]
	jne .check_other_end

	cmp edx, [ebx + 0ch + 4]
	jne .check_other_end
	jmp .touching

.check_other_end:
	; ebx.base + ebx.size == eax.base ?
	mov ecx, [ebx + 0ch]
	mov edx, [ebx + 0ch + 4]

	add ecx, [ebx + 14h]
	adc edx, [ebx + 14h + 4]

	cmp ecx, [eax + 0ch]
	jne .not_touching

	cmp edx, [eax + 0ch + 4]
	jne .not_touching
	jmp .touching

.touching:
	stc
	jmp .end

.not_touching:
	clc

.end:
	pop edx
	pop ecx
	ret


; Function:   SystemMemoryMap_popFront
; Purpose:    to remove the first element from the map's list.
;             Fully CPU state preserving.
; Parameters: ESI [IN OUT]:  Pointer to the head of the list
; Returns:    ECX [OUT]:     The removed first element or 0 if ESI is 0
;                            (List empty)
SystemMemoryMap_popFront:
	push eax

	; First element
	mov ecx, esi

	; If the list's empty, we're done.
	or esi, esi
	jz .end

	; Advance esi
	mov esi, [esi + 4]

	; Clear backward reference
	xor eax, eax
	mov [esi], eax

	; Clear ecx's references
	mov [ecx], eax
	mov [ecx + 4], eax

.end:
	; Return
	pop eax
	ret


; Function:   SystemMemoryMap_pushBack
; Purpose:    to append an element to the map's list.
;             Fully CPU state preserving. Use with care, no error checking is
;             done!
; Parameters: EDI [IN OUT]: Pointer to the head of the list.
;             EDX [IN]:     The element to add
; Returns:    Nothing.
SystemMemoryMap_pushBack:
	push eax
	push ebx

	; If the list is still empty, it's trivial.
	or edi, edi
	jnz .list_not_empty

	mov edi, edx
	jmp .end

.list_not_empty:
	; Go to the end of the list
	mov ebx, edi

.seek_end_loop:
	mov eax, [ebx + 4]
	or eax, eax
	jz .seek_end_reached

	mov ebx, eax
	jmp .seek_end_loop

.seek_end_reached:
	; ebx->next = edx
	mov [ebx + 4], edx

	; edx->previous = ebx
	mov [edx], ebx

	; edx->next = NULL
	xor eax, eax
	mov [edx + 4], eax
	jmp .end

.end:
	pop ebx
	pop eax
	ret


; Function:   SystemMemoryMap_print
; Purpose:    to print the memory map for debugging purposes.
;             Fully CPU state preserving
; Parameters: None.
global p_SystemMemoryMap_print
p_SystemMemoryMap_print:
	push eax
	push ebx
	push esi

	; Print info message
	mov esi, .msgInfo
	call p_print_string

	mov ebx, [system_memory_map]

	; Print list start address
	mov esi, .msgListStart
	call p_print_string

	mov eax, ebx
	call p_print_hex

	mov esi, .msgCrLf
	call p_print_string

.print_entry:
	or ebx, ebx
	jz .print_end

	; Start
	mov esi, .msgStart
	call p_print_string

	mov eax, [ebx + 0ch + 4]
	call p_print_hex

	mov eax, [ebx + 0ch]
	call p_print_hex

	; Size
	mov esi, .msgSize
	call p_print_string

	mov eax, [ebx + 14h + 4]
	call p_print_hex

	mov eax, [ebx + 14h]
	call p_print_hex

	mov esi, .msgSizeEnd
	call p_print_string

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

	mov esi, .msgEntryUndefined

.print_type:
	call p_print_string

	; List data
	; Skip for now ...
	jmp .print_continue

	; Entry's Address
	mov esi, .msgAddress
	call p_print_string

	mov eax, ebx
	call p_print_hex

	; Previous entry
	mov esi, .msgPrevious
	call p_print_string

	mov eax, [ebx]
	call p_print_hex

	; Next entry
	mov esi, .msgNext
	call p_print_string

	mov eax, [ebx + 4]
	call p_print_hex

.print_continue:
	mov esi, .msgCrLf
	call p_print_string

	; Next entry
	mov ebx, [ebx + 4]
	jmp .print_entry

.print_end:
	mov esi, .msgEnd
	call p_print_string

.end:
	pop esi
	pop ebx
	pop eax
	ret


.select_free:
	mov esi, .msgEntryFree
	jmp .print_type

.select_reserved:
	mov esi, .msgEntryReserved
	jmp .print_type

.select_acpi_reclaim:
	mov esi, .msgEntryAcpiReclaim
	jmp .print_type

.select_acpi_nvs:
	mov esi, .msgEntryAcpiNVS
	jmp .print_type

.select_loader_text_data:
	mov esi, .msgEntryLoaderTD
	jmp .print_type

.select_loader_bss:
	mov esi, .msgEntryLoaderBss
	jmp .print_type

.select_kernel_text_data:
	mov esi, .msgEntryKernelTD
	jmp .print_type

.select_kernel_bss:
	mov esi, .msgEntryKernelBss
	jmp .print_type

.select_well_known_pc:
	mov esi, .msgEntryWellKnownPc
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
