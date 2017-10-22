%include "asm_utils.inc"

bits 32
section .text

; Function:   NE2000_isr_handler
; Purpose:    to handle interrupt requests from NE2000. Wrapper for
;             c_NE2000_handler that saves registers, ensures stack alignment
;             and signals EOI.
; Parameters: -- ISR handler --
; Returns:    -- ISR handler --
global NE2000_isr_handler
NE2000_isr_handler:
	push eax
	push ecx
	push edx

	extern c_NE2000_isr_handler

	call asm_utils_align_stack16
	call c_NE2000_isr_handler
	call asm_utils_restore_aligned_stack

	mov al, 20h		; Signal EOI
	out 0x20, al

	pop edx
	pop ecx
	pop eax
	iretd
