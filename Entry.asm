section .text
bits 32

extern p_print_string

; ===========
; Entry Point
; ===========
entry_point:
	mov esi, .msgKernel
	call p_print_string

	extern screen_clear
	call screen_clear

	extern text
	mov esi, text
	call p_print_string

.end:
	jmp .end

.msgKernel db 'Kernel execution started', 0x0D, 0x0A, 0
