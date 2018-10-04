section .text

; Function:   cpu_halt
; Purpose:    to halt the cpu
; Parameters: none
	global cpu_halt
cpu_halt:
	cli
.loop:
	hlt
	jmp .loop
