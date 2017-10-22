%include "asm_utils.inc"
%include "stdio.inc"

bits 32
section .text

extern IDT, IDT_SIZE

; Function:   isrh_add_handler
; Purpose:    to add an interrupt handler located in the code segment to the
;             IDT.
; Cc:         cdecl
; Parameters: 1st [IN] (dword): Address (must be in the code segment)
;             2nd [IN] (byte) : ISR number at which the handler should be
;                               installed
; Returns:    Nothing.
global isrh_add_handler
isrh_add_handler:
	enter 0,0

	; Disable interrupts to make it atomic
	pushfd

	in al, 0x70  ; Disable NMI
	mov cl, al   ; Preserve NMI state
	and cl, 0x80
	or al, 0x80
	out 0x70, al

	; Construct descriptor
	movzx edx, byte [ebp + 12]
	shl edx, 3					; Calculate byte offset
	add edx, IDT				; Add to base address

	mov eax, [ebp + 8]			; Offset 0..15
	mov [edx], ax

	mov ax, cs					; Segment Selector
	mov [edx + 2], ax

	mov ax, 0x8E00				; Present, DPL 0, 32 bit
	mov [edx + 4], ax

	shr eax, 16					; Offset 16..31
	mov [edx + 6], ax

	in al, 0x70		; Restore NMI state
	and al, 0x7E
	or al, cl
	out 0x70, al

	popfd			; Restore IF state

	leave
	ret
