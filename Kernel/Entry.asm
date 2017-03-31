section .text
bits 32

extern text_size
dd text_size  ; size of the kernel, must be the first dword

; extern symbols
extern text

; ===========
; Entry Point
; ===========
entry_point:
	call disable_floppy_motors	; disable floppy motors

	call screen_clear		; clear screen

	mov esi, text
	call print_string		; print text

.end:
	hlt
	jmp .end

disable_floppy_motors:
	mov dx, 0x3F2			; floppy DOR
	in al, dx			; read DOR
	and al, 0Fh			; mask motor bits
	out dx, al			; write DOR
	ret


TEXT_VIDEO_START equ 0xB8000		; text video memory starts here

; Function:   screen_clear
; Purpose:    to clear the screen, remove all characters and position the cursor
;             in the top left corner.
;             The processor state ins not modified (except EFLAGS).
; Parameters: none
screen_clear:
	push eax  ; save registers
	push ecx
	push edi

	xor ax, ax
	mov edi, TEXT_VIDEO_START	; start of text video memory
	mov ecx, 80 * 25		; 80 * 25 characters

	cld
	rep stosw			; rep prefix

	mov byte [xpos], al		; position the cursor in the top left corner
	mov byte [ypos], al

	pop edi  ; restore registers
	pop ecx
	pop eax
	ret

; Function:   print_string
; Purpose:    to print a zero-terminated string in protected mode (without the BIOS)
;             in a fully state preserving way (except EFLAGS).
; Parameters: ESI [IN] = start address
; Returns:    nothing
print_string:
	push eax  ; save registers
	push esi

	cld

.loop:
	lodsb
	or al, al
	jz .done   ; zero-byte, we are done

	call putchar
	jmp .loop

.done:
	pop esi  ; restore registers
	pop eax
	ret

; Function: putchar
; Purpose: to print a character in protected mode (without the BIOS),
;          state-preserving
; Parameters: AL [IN] = character
; Returns: nothing
;
; see http://wiki.osdev.org/Babystep4
putchar:
	push eax
	push ebx
	push edx

	cmp al, 0x0D  ; CR
	je .CR

	cmp al, 0x0A  ; LF
	je .LF

	; out of screen ?
	cmp byte [xpos], 80
	jae .end

	cmp byte [ypos], 25
	jae .end

	; print character
	mov ah, 0x0F  ; attrib = white on black

	mov ebx, TEXT_VIDEO_START		; text video memory starts here

	movzx edx, byte [ypos]
	imul edx, 160		; 80 columns * 2 bytes
	add ebx, edx

	movzx edx, byte [xpos]
	shl edx, 1		; 2 bytes per character (attrib)
	add ebx, edx

	mov [ebx], ax
	inc byte [xpos]

.end:
	pop edx
	pop ebx
	pop eax
	ret

.CR:
	mov byte [xpos], 0
	jmp .end

.LF:
	mov al, [ypos]
	inc al

	xor ah, ah
	mov bl, 14  ; leave some space for status information
	div bl

	mov [ypos], ah
	jmp .end


; ---------------------------------------------------
xpos db 0
ypos db 0
