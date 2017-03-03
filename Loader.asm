%macro PRINT_CRLF 0
	mov si,msgCRLF
	call print_string
%endmacro

section .text

org 0x7C00	; add 0x7C00 to label addresses
bits 16		; tell the assembler we want 16 bit code

	mov ax, 0
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7C00

load_kernel:
	; load kernel from floppy
	mov dl, 0
	call get_drive_geometry

	jc halt_error

	call print_drive_geometry

	mov [floppy.NumberOfHeads], dh
	mov [floppy.SectorsPerTrack], cl

	; load first block, which contains the kernel size dword
	mov ax,1
	mov dl,0
	mov di,0x7E00
	call drive_read_block

	jc halt_error

	; determine kernel size and load subsequent blocks
	mov cx, [0x7E00]

	mov si, msgKernelSize
	call print_string

	mov ax,cx
	call print_hex
	PRINT_CRLF

	or cx,cx
	jz .done    ; if kernel size is zero, we are done.


	add cx,0x1FF
	shr cx, 9     ; divide by 512 rounding up

	sub cx, 1
	mov ax, 2
	mov dl, 0
	mov di, 0x8000

	call drive_read  ; otherwise, read remaining blocks
	jc halt_error

.done:
	; open address line 20

	mov si, msgOK
	call print_string

	; create segment table
	call create_GDT

	; switch to protected mode
	; flush segment registers and jump to entrance

; ===================================
; global messages and data structures
; ===================================

msgKernelSize db 'Kernel size: ',0
msgOK db 'OK.', 0x0D, 0x0A, 0
msgCRLF db 13,10,0

floppy:
	.NumberOfHeads db 1
	.SectorsPerTrack db 1


; ================
; calls start here
;=================

; print error message and halt
halt_error:
	mov si, .msgError
	call print_string
	cli
	hlt  ; halt in case of error

.msgError db 'Error.', 0

; DL [IN] = BIOS drive number,
; DL [OUT] = number of drives,
; DH [OUT] = Number of Heads,
; CL [OUT] = Sectors per Track,
; BX [OUT] = Number of Cylinders,
; CF set on error
get_drive_geometry:
	mov ah, 0x08
	int 13h

	jc .done  ; on error return immediately, so add/and won't override CF

	add dh, 1

	mov bl,ch
	mov bh,cl
	shr bh,6
	add bx, 1
	and cl, 3Fh

.done:
	ret

; AX [IN] = LBA,
; AX [OUT] = Cylinder,
; BX [OUT] = Head,
; CX [OUT] = Sector,
; no side effects
LBA_to_CHS:
	push dx

	; Temp = LBA / (Sectors per Track)
	xor dx, dx

	xor cx, cx
	mov cl, [floppy.SectorsPerTrack]

	div cx

	; Sector = (LBA % (Sectors per Track)) + 1
	mov cx,dx
	add cx,1

	; Cylinder = Temp / (Number of Heads)
	xor dx,dx

	xor bx,bx
	mov bl, [floppy.NumberOfHeads]

	div bx

	; Head = Temp % (Number of Heads)
	mov bx,dx

	pop dx
	ret

; loads a block (512 bytes) from a drive
; AX [IN] = LBA,
; DL [IN] = BIOS drive number,
; DI [IN] = destination,
; CF set on error,
; no side effects
drive_read_block:
	push ax
	push bx
	push cx
	push dx
	push si
	push di

	call LBA_to_CHS

	; set up parameters for INT 13h
	mov ch,al

	shr ax,2
	and al, 0xC0
	or cl,al

	mov dh, bl
	mov bx, di

	mov ax,ds
	mov es,ax  ; set ES to DS

	mov al,1
	mov ah,2

	int 13h

	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	ret

; Creates the global descriptor table
create_GDT:
	xor ax,ax
	mov [GDT], ax
	mov [GDT+2], ax
	mov [GDT+4], ax
	mov [GDT+6], ax  ; null descriptor


; Code descriptor
; 31 ...... 24, 23,   22,     21,   20,   19 ...... 16, 15,   14, 13, 12,   11,       10,   9,    8,    7 ......... 0
; ------------------------------------------------------------------------------------------------------------------|
; | Base 31:24 | G=0 | D/B=1 | L=0 | AVL | Limit 19:26 | P=1 | DPL=0 | S=1 | Code(1) | C=0 | R=0 | A=0 | Base 23:16 |
; |-----------------------------------------------------------------------------------------------------------------|
; |                         Base 15:0                  |                       Limit 15:0                           |
; -------------------------------------------------------------------------------------------------------------------

%macro descriptor_bit(S,D) 2
	mov cx, [S]
	and cx, 1h
	shl cx, D
	or bx, cx
%endmacro

; AX [IN] = destination
; code_descriptor [IN] = descriptor
create_descriptor:
	mov bx, [codedescriptor.limit]
	mov [ax], bx

	mov bx, [codedescriptor.base]
	mov [ax], bx

	mov bx, [codedescriptor.base+2]
	and bx, 0Fh

	descriptor_bit



code_descriptor:
 .base dw 0
 .limit dw 0
 .G db 0
 .D_B db 1
 .L db 0
 .AVL db 0
 .P db 1
 .DPL db 0
 .S db 1
 .Code db 1
 .C db 0
 .R db 0
 .A db 0

; loads multiple blocks (each 512 bytes) from a drive
; AX [IN] = LBA start address,
; DL [IN] = BIOS drive number,
; CX [IN] = count of blocks,
; DI [IN] = destination,
; CF set on error
drive_read:
	or cx,cx   ; or cx with itself, or cleares CF
	jz .done  ; if it is zero, we are done.

	call drive_read_block  ; otherwise, read a block
	jc .done               ; on error, return immediately

	inc ax
	dec cx
	add di,0x200  ; update parameters
	jmp drive_read

.done:
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

; prints output from get_drive_geometry,
; DL [IN] = number of drives,
; DH [IN] = Number of Heads,
; CL [IN] = Sectors per Track,
; BX [IN] = Number of Cylinders,
; parameters are not changed
print_drive_geometry:
	mov si, .msgDrive  ; print BIOS drive number
	call print_string

	xor ax,ax
	mov al,dl
	call print_hex

	PRINT_CRLF

	mov si, .msgCylinders  ; print count of cylinders
	call print_string

	mov ax,bx
	call print_hex

	PRINT_CRLF

	mov si, .msgHeads  ; print count of heads
	call print_string

	xor ax,ax
	mov al,dh
	call print_hex

	PRINT_CRLF

	mov si, .msgSectors  ; print count of sectors
	call print_string

	xor ax,ax
	mov al,cl
	call print_hex

	PRINT_CRLF
	ret

.msgDrive     db 'drives:    ',0
.msgCylinders db 'Cylinders: ',0
.msgHeads     db 'Heads:     ',0
.msgSectors   db 'Sectors:   ',0


	times 510-($-$$) db 0
	dw 0AA55h ; some BIOSes require this signature
