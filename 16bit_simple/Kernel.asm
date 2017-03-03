section .text

bits 16

kernelSize dd afterCode-$$  ; size of entire kernel to be loaded by the bootloader

begin:
	xor ax, ax  ; Add the System Call handler to the IVT
	mov es, ax

	mov al, 80h
	mov bl, 4h
	mul bl
	mov bx, ax

	mov [es:bx], word inthandler
	add bx, 2
	mov [es:bx], cs

	mov ax,ds
	mov es,ax

	mov si, welcome
	call print_string

mainloop:
	mov si, prompt
	call print_string

	mov di, buffer
	call get_string

	mov si, buffer
	cmp byte [si], 0  ; blank line?
	je mainloop       ; yes, ignore it

	mov si, buffer
	mov di, cmd_hi  ; "hi" command
	call strcmp
	jc .hi

	mov si, buffer
	mov di, cmd_print_hex  ; "print_hex" command
	call strcmp
	jc .print_hex

	mov si, buffer
	mov di, cmd_ticks  ; "ticks" command
	call strcmp
	jc .ticks

	mov si, buffer
	mov di, cmd_random  ; "random" command
	call strcmp
	jc .random

	mov si, buffer
	mov di, cmd_time  ; "time" command
	call strcmp
	jc .time

	mov si, buffer
	mov di, cmd_1sek  ; "1sek" command
	call strcmp
	jc .1sek

	mov si, buffer
	mov di, cmd_5sek  ; "5sek" command
	call strcmp
	jc .5sek

	mov si, buffer
	mov di, cmd_help  ; "help" command
	call strcmp
	jc .help

	mov si, badcommand
	call print_string
	jmp mainloop

.hi:
	mov si, msg_hi
	call print_string

	jmp mainloop

.print_hex:
	mov ax, 0x7A7F
	call print_hex

	mov si, crlf
	call print_string

	jmp mainloop

.ticks:
	mov ah, 0
	int 80h

	mov si, msg_ticks.1
	call print_string

	mov ax, cx
	call print_hex

	mov si, msg_ticks.2
	call print_string

	mov ax, dx
	call print_hex

	mov si, crlf
	call print_string

	jmp mainloop

.random:
	mov ah, 1
	int 80h

	call print_hex

	mov si, crlf
	call print_string

	jmp mainloop

.time:
	mov ah, 0
	int 80h    ; CX = hour, DX = sub-hour

	mov ax, cx
	call print_hex

	mov si, msg_time
	call print_string

	mov ax, dx
	xor dx, dx

	mov cx, 1092
	div cx

	call print_hex

	mov si, crlf
	call print_string

	jmp mainloop

.1sek:
	mov ah, 2
	mov cx, 0Fh
	mov dx, 4240h
	int 80h

	jmp mainloop

.5sek:
	mov ah, 2
	mov cx, 4Ch
	mov dx, 4B40h
	int 80h

	jmp mainloop

.help:
	mov si, msg_help
	call print_string

	jmp mainloop

welcome db 'Welcome to My OS!', 0x0D, 0x0A, 0
badcommand db 'Bad command entered.', 0x0D, 0x0A, 0
prompt db '>', 0
crlf db 0x0D, 0x0A, 0
cmd_hi db 'hi', 0
cmd_print_hex db 'print_hex', 0
cmd_ticks db 'ticks', 0
cmd_random db 'random', 0
cmd_time db 'time', 0
cmd_1sek db '1sek', 0
cmd_5sek db '5sek', 0
cmd_help db 'help', 0
msg_hi   db 'Hello OSDev World!', 0x0D, 0x0A, 0
msg_ticks:
 .1 db 'Timer ticks since midnight: ', 0
 .2 db ':', 0
msg_time db ':', 0
msg_help db 'My OS: Commands: hi, print_hex, ticks, random, time, 1sek, 5sek, help', 0x0D, 0x0A, 0
buffer times 64 db 0

; ================
; calls start here
; ================

; BIOS INT style handler for system calls
inthandler:
	cmp ah,0
	je .ahzero

	cmp ah,1
	je .ahone

	cmp ah,2
	je .ahtwo

	mov si,.msgBadAH
	call print_string
	cli
	hlt

.ahzero:  ; ah = 0: report ticks in cx:dx
	xor ax,ax
	int 1Ah    ; retrieve timer ticks since midnight
	iret

.ahone:  ; ah = 1: return (pseudo- ?)random number in dx
	xor ax,ax
	int 1Ah

	mov cx, dx

	mov ax, 25173
	mul cx
	add ax, 13849

	iret

.ahtwo:  ; ah = 2: microsecond timing, CX:DX =  interval of microseconds to wait
	mov ah,86h
	int 15h
	iret

.msgBadAH db 'System Call with bad AH!', 0

print_string:
	lodsb		; grab a byte from si

	or al, al  ; logical or AL by itself
	jz .done   ; if the result is zero, get out

	mov ah, 0x0E
	int 0x10      ; otherwise, print out the character!

	jmp print_string

.done:
	ret

get_string:
	xor cl, cl

.loop:
	mov ah, 0
	int 0x16   ; wait for keypress

	cmp al, 0x08    ; backspace pressed?
	je .backspace   ; yes, handle it

	cmp al, 0x0D  ; enter pressed?
	je .done      ; yes, we're done

	cmp cl, 0x3F  ; 63 chars inputed?
	je .loop     ; yes, only let in backspace and enter

	mov ah, 0x0E
	int 0x10      ; print out character

	stosb  ; put character in buffer
	inc cl
	jmp .loop

.backspace:
	cmp cl, 0	; beginning of string?
	je .loop	; yes, ignore the key

	dec di
	mov byte [di], 0	; delete character
	dec cl			; decrement counter as well

	mov ah, 0x0E
	mov al, 0x08
	int 10h			; backspace on the screen

	mov al, ' '
	int 10h			; blank character out

	mov al, 0x08
	int 10h			; backspace again

	jmp .loop	; go to the main loop

.done:
	mov al, 0	; null terminator
	stosb

	mov ah, 0x0E
	mov al, 0x0D
	int 0x10
	mov al, 0x0A
	int 0x10		; newline

	ret

strcmp:
.loop:
	mov al, [si]   ; grab a byte from SI
	mov bl, [di]   ; grab a byte from DI
	cmp al, bl     ; are they equal?
	jne .notequal  ; nope, we're done.

	cmp al, 0  ; are both bytes (they were equal before) null?
	je .done   ; yes, we're done.

	inc di     ; increment DI
	inc si     ; increment SI
	jmp .loop  ; loop!

.notequal:
	clc  ; not equal, clear the carry flag
	ret

.done:
	stc  ; equal, set the carry flag
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


afterCode:
