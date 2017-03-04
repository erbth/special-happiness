section .text
org 0x7E00
bits 16

dd after_code-$$ ;  size of stage 2

entry:
	; open address line 20
	call open_a20
	or ax, ax
	jnz .a20_error

	; create and load gdt
	call create_GDT

	mov si, .msgPModeSwitch
	call print_string

	; switch to protected mode
	cli
	; in al, 0x70
	; or al, 0x80
	; out 0x70, al  ; disable nmi

	mov eax, cr0
	or al, 1  ; set pmode bit
	mov cr0, eax

	; continue with 32 bit code
	jmp dword 8h:entry_of_protected_mode ;  all 16 bit code will be invalid from now (until we switch back to real mode)

; --- Error handlers ---
.a20_error:
	mov si, .msgErrorA20
	call print_string

	jmp .error

.error:
	cli
	hlt


; --- Messages ---
.msgErrorA20	db 'Could not open the A20 line.', 0x0D, 0x0A, 0
.msgPModeSwitch	db 'Switching to protected mode ...', 0x0D, 0x0A, 0


; ================
; Calls start here
; ================


; Function: create_gdt
;
; Purpose: to initialize the GDT and load the GDTR
;
; Paramters: none
create_GDT:
	cli

	mov di, GDT
	mov ax, ds
	mov es, ax

	xor ax,ax  ; null descriptor
	mov cl, 4

.null:
	mov [di], ax
	add di, 2
	dec cl
	jnz .null


	mov si, .code_descriptor  ; code descriptor
	mov cl, 4

.code:
	lodsw
	stosw
	dec cl
	jnz .code


	mov si, .data_descriptor  ; data descriptor
	mov cl, 4

.data:
	lodsw
	stosw
	dec cl
	jnz .data

	mov ax, GDT_SIZE
	mov bx, GDT
	call load_gdtr  ; load gdtr

	sti
	ret

; Code descriptor
; 31 ...... 24, 23,   22,     21,   20,   19 ...... 16, 15,   14, 13, 12,   11,       10,   9,    8,    7 ......... 0
; ------------------------------------------------------------------------------------------------------------------|
; | Base 31:24 | G=0 | D/B=1 | L=0 | AVL | Limit 19:16 | P=1 | DPL=0 | S=1 | Code(1) | C=0 | R=0 | A=0 | Base 23:16 |
; |-----------------------------------------------------------------------------------------------------------------|
; |                         Base 15:0                  |                       Limit 15:0                           |
; -------------------------------------------------------------------------------------------------------------------

.code_descriptor dw 0xFFFF, 0x0000, 0x9800, 0x004F

; Data descriptor
; 31 ...... 24, 23,   22,     21,   20,   19 ...... 16, 15,   14, 13, 12,   11,       10,   9,    8,    7 ......... 0
; ------------------------------------------------------------------------------------------------------------------|
; | Base 31:24 | G=0 | D/B=1 | L=0 | AVL | Limit 19:16 | P=1 | DPL=0 | S=1 | Data(0) | D=0 | W=1 | A=0 | Base 23:16 |
; |-----------------------------------------------------------------------------------------------------------------|
; |                         Base 15:0                  |                       Limit 15:0                           |
; -------------------------------------------------------------------------------------------------------------------

.data_descriptor dw 0xFFFF, 0x0000, 0x9200, 0x004F

; Function: load_gdtr
;
; Purpose: to load the GDT Register
;
; Parameters: AX [IN] = size of GDT
;             BX [IN] = location of GDT
;
load_gdtr:
	mov word [.gdtd], ax

	xor eax,eax  ; offset

	mov ax, ds
	shl eax, 4  ; segment

	and ebx, 0xFFFF
	add eax, ebx  ; + offset
	mov [.gdtd+2], eax

	lgdt [.gdtd]

	ret

.gdtd:
	dw 0 ; size
	dd 0 ; offset

; GDT, 3 entries per 8 byte
GDT times 3*8 db 0
GDT_SIZE equ ($-GDT)




; Function: open_a20
;
; Purpose: to open the a20 line
;
; Parameters: none
;
; Returns: 0 in ax on success
;          1 in ax on failure
;
; see http://wiki.osdev.org/A20_Line
open_a20:
	call check_a20
	cmp ax, 1
	je .success

	mov si, .msgClosed
	call print_string

	call open_a20_bios ;  try bios function

	call check_a20
	cmp ax, 1
	je .success

	mov si, .msgClosed
	call print_string

	call open_a20_keyboard_controller ;  try the keyboard controller method

	mov cx, 10000

.waitKbd:
	call check_a20 ;  might work slowly, try in a loop with timeout
	cmp ax, 1
	je .success
	loop .waitKbd

	call open_a20_fast ;  try the Fast A20 method

	mov cx, 10000

.waitFast:
	call check_a20 ;  might work slowly, try in a loop with timeout
	cmp ax, 1
	je .success
	loop .waitFast

.failure:
	mov si, .msgClosed  ; nothing worked, give up
	call print_string

	mov ax, 1
	jmp .end

.success:
	mov si, .msgOpen
	call print_string

	mov ax, 0
.end:
	ret

.msgOpen db 'A20 open', 0x0D, 0x0A, 0
.msgClosed db 'A20 closed', 0x0D, 0x0A, 0


; Function: open_a20_bios
;
; Purpose: to ask the BIOS to open the a20 line
;
; Returns: 0 in ax on success
;          1 in ax on failure
;
; see http://wiki.osdev.org/A20_Line
open_a20_bios:
	mov ax, 2403h	; --- A20-Gate support ---
	int 15h
	jc .failure	; INT 15h is not supported
	cmp ah, 0
	jc .failure	; INT 15h is not supported

	mov ax, 2402h	; --- A20-Gate status ---
	int 15h
	jc .failure	; couldn't get status
	cmp ah, 0
	jne .failure	; couldn't get status

	cmp al, 1
	je .success	; A20 is already activated

	mov ax, 2401h	; --- A20-Gate activate ---
	int 15h
	jne .failure	; couldn't activate the gate
	cmp ah, 0
	jne .failure	; cou;dn't activate the gate

.success:
	mov ax, 0
	jmp .end

.failure:
	mov ax, 1
.end:
	ret

; Function: open_a20_keyboard_controller
;
; Purpose: to ask the Keyboard Controller (8042 chip) to open the a20 line
;
; Returns: none
;
; see http://wiki.osdev.org/A20_Line
open_a20_keyboard_controller:
	cli

	call .wait
	mov al, 0xAD  ; disable keyboard
	out 0x64, al

	call .wait
	mov al, 0xD0  ; read from input
	out 0x64, al

	call .wait2
	in al, 0x60
	push ax

	call .wait
	mov al, 0xD1  ; write to output
	out 0x64, al

	call .wait
	pop ax
	or al, 2
	out 0x60, al

	call .wait
	mov al, 0xAE
	out 0x64, al

	call .wait
	sti
	ret

; wait until keyboard controller is done processing
.wait:
	in al, 0x64
	test al, 2
	jnz .wait
	ret

; wait until data arrives (?)
.wait2:
	in al, 0x64
	test al, 1
	jz .wait2
	ret

; Function: open_a20_fast
;
; Purpose: open the A20 line using the A20 Fast method
;
; Returns: none
;
; see http://wiki.osdev.org/A20_Line
open_a20_fast:
	in al, 0x92
	test al, 2
	jnz .end
	or al, 2
	and al, 0xFE
	out 0x92, al

.end:
	ret

; Function: check_a20
;
; Purpose: to check the status of the a20 line in a completely self-contained
;          state-preserving way.
;
; Returns: 0 in ax if the a20 line is disabled (memory wraps around)
;          1 in ax if the a20 line is enabled (memory does not wrap around)
;
; see http://wiki.osdev.org/A20_Line#Testing_the_A20_line
check_a20:
	pushf
	push ds
	push es
	push di
	push si

	cli

	xor ax, ax ; ax = 0
	mov ds, ax

	not ax ; ax = 0xFFFF
	mov es, ax

	mov di, 0x500
	mov si, 0x510

	mov al, [ds:di]
	push ax

	mov al, [es:si]
	push ax

	mov byte [ds:di], 0x00
	mov byte [es:si], 0xFF

	cmp byte [ds:di], 0xFF

	pop ax
	mov [es:si], al

	pop ax
	mov [ds:di], al

	mov ax, 0
	je .end

	mov ax, 1

.end:
	pop si
	pop di
	pop es
	pop ds
	popf
	ret

; SI [IN] = location of zero terminated string to print
print_string:
	lodsb		; grab byte from si

	or al, al  ; logical or AL by itself
	jz .done   ; if the result is zero, get out

	mov ah, 0x0E
	int 0x10      ; otherwise, print out the character!

	jmp print_string
.done:
	ret

; basically from there: http://wiki.osdev.org/Real_mode_assembly_II,
; extended to whole ax
print_hex:
	call .byte
	mov ax, [.temp]
	xchg al, ah
	call .byte
	ret
.byte:
	mov [.temp],ax
	shr ax,12
	cmp al,10
	sbb al,69h
	das

	mov ah,0Eh
	int 10h

	mov ax,[.temp]
	rol ax,4
	shr ax,12
	cmp al,10
	sbb al,69h
	das

	mov ah,0Eh
	int 10h

	ret

.temp dw 0


; ====================================
; protected mode execution starts here
; ====================================
bits 32
entry_of_protected_mode:
	; load segment registers
	mov ax, 10h
	mov ds, ax
	mov es, ax
	mov ss, ax

	; load stack pointer
	movzx esp, sp

	mov esi, .p_msgPModeEntered
	call p_print_string

	hlt

; --- Messages ---
.p_msgPModeEntered db 'Entered protected mode.', 0x0D, 0x0A, 0


; =======================
; 32 bit calls start here
; =======================
; Function: p_print_string
; Purpose: to print a zero-terminated string in protected mode (without the BIOS)
; Parameters: ESI [IN] = start address
; Returns: nothing
p_print_string:
	lodsb
	or al, al
	jz .done   ; zero-byte, we are done

	call p_putchar
	jmp p_print_string

.done:
	ret

; Function: p_putchar
; Purpose: to print a character in protected mode (without the BIOS),
;          state-preserving
; Parameters: AL [IN] = character
; Returns: nothing
;
; see http://wiki.osdev.org/Babystep4
p_putchar:
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

	mov ebx, 0xB8000		; text video memory starts at 0xB8000

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
	cmp al, 25
	jb .end

	mov al, 0
	jmp .end

; ---------------------------------------------------
xpos db 0
ypos db 0


times 512 - (($-$$) % 512) db 0  ; easier if size of stage 2 is aligned to block
                                 ; size
after_code:
