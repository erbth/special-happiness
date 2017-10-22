bits 32
section .text

; Function:   asm_utils_align_stack16
; Purpose:    to align the stack on a 16 byte boundary prior to e.g. a cdecl
;             call. The original stack pointer is saved in EBP, EBP in turn is
;             saved on the stack before. That means, between
;             asm_utils_align_stackXX and asm_utils_restore_aligned_stack EBP
;             canot be used.
;             Fully CPU state preserving.
; Parameters: None.
; Returns:    Nothing.
global asm_utils_align_stack16
asm_utils_align_stack16:
	enter 0, 0
	and esp, ~0xF
	jmp [ebp + 4]	; Strange return because ESP is garbage

; Function:   asm_utils_restore_aligned_stack
; Purpose:    to restore ESP after a call to asm_utils_align_stackXX and having
;             the corresponding work done. Each call to asm_utils_align_stackXX
;             shall be followed by a call to asm_utils_restore_aligned_stack.
;             Fully CPU state preserving.
; Parameters: None.
; Returns:    Nothing.
global asm_utils_restore_aligned_stack
asm_utils_restore_aligned_stack:
	pop dword [ebp + 4]
	leave
	ret
