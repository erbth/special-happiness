%include "EarlyDynamicMemory16.inc"
%include "SystemMemoryMap16.inc"
%include "SystemMemoryMap32.inc"

section .text
; org 0x7E00  ; done by linker
bits 16

; The size of the code to load in sectors
extern bootstrapped_blocks_to_load
dw bootstrapped_blocks_to_load

stage2_x86_asm_entry:
	; This is the entrypoint of stage 2. The next part of the OS that is loaded
	; from the drive is loaded by the actual OS itself and not the stage 1
	; bootstrapper.

	; open address line 20
	call open_a20
	or ax, ax
	jnz .a20_error

	; Initialize early dynamically allocatable memory
	call EarlyDynamicMemory_init

	; Initialize System Memory Map
	call SystemMemoryMap_init

	; Retrieve memory map using int 15h with ax=e820h
	call retrieve_memory_map_int15
	jc .int15_error

	; Add well-known BIOS ranges to SMAP
	mov esi, SYSTEM_MEMORY_MAP_ENTRY_WELL_KNOWN_PC

	; Real-mode IVT
	xor eax, eax
	xor ebx, ebx
	mov ecx, 400h
	xor edx, edx

	call SystemMemoryMap_add
	jc .smap_add_error

	; BDA
	mov eax, 0x400
	mov ecx, 100h

	call SystemMemoryMap_add
	jc .smap_add_error

	; EBDA
	mov eax, 0x9fc00
	mov ecx, 400h

	call SystemMemoryMap_add
	jc .smap_add_error

	; Video and ROM
	mov eax, 0xa0000
	mov ecx, 60000h

	call SystemMemoryMap_add
	jc .smap_add_error

	; Print SMAP
	call SystemMemoryMap_print

	; create and load temporary gdt
	call create_temporary_GDT

	mov si, .msgPressAnyKey
	call print_string
	call wait_for_keypress

	mov si, .msgPModeSwitch
	call print_string

	; switch to protected mode
	cli  ; disable regular interrupts
	in al, 0x70
	or al, 0x80
	out 0x70, al  ; disable NMIs

	mov eax, cr0
	or al, 1  ; set pmode bit
	mov cr0, eax

	; continue with 32 bit code
	jmp dword 8h:entry_of_protected_mode ;  all 16 bit code will be invalid from now (until we switch back to real mode)

; --- Error handlers ---
.smap_disjoint_error:
	mov si, .msgErrorSmapDisjoint
	call print_string
	jmp .error

.smap_add_error:
	mov si, .msgErrorSmapAdd
	call print_string
	jmp .error

.int15_error:
	mov si, .msgErrorInt15
	call print_string
	jmp .error

.a20_error:
	mov si, .msgErrorA20
	call print_string
	jmp .error

.error:
	hlt
	jmp .error


; --- Messages ---
.msgErrorSmapDisjoint	db 'Failed to make SMAP disjoint', 0dh, 0ah, 0
.msgErrorSmapAdd		db 'Failed to add an entry to the SMAP', 0dh, 0ah, 0
.msgErrorInt15			db 'Failed to retrieve the System Memory Map through int 15.', 0dh, 0ah, 0
.msgErrorA20			db 'Could not open the A20 line.', 0x0D, 0x0A, 0
.msgPModeSwitch			db 'Switching to protected mode ...', 0x0D, 0x0A, 0
.msgPressAnyKey			db 'Press any key to continue ...', 0x0d, 0x0a, 0


; ================
; Calls start here
; ================


; Function: create_gdt
;
; Purpose: to initialize a temporary GDT and load the GDTR
;
; Paramters: none
create_temporary_GDT:
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

	ret

; Code descriptor
; 31 ...... 24, 23,   22,     21,   20,   19 ...... 16, 15,   14, 13, 12,   11,       10,   9,    8,    7 ......... 0
; ------------------------------------------------------------------------------------------------------------------|
; | Base 31:24 | G=1 | D/B=1 | L=0 | AVL | Limit 19:16 | P=1 | DPL=0 | S=1 | Code(1) | C=0 | R=0 | A=0 | Base 23:16 |
; |-----------------------------------------------------------------------------------------------------------------|
; |                         Base 15:0                  |                       Limit 15:0                           |
; -------------------------------------------------------------------------------------------------------------------

.code_descriptor dw 0xFFFF, 0x0000, 0x9800, 0x00CF

; Data descriptor
; 31 ...... 24, 23,   22,     21,   20,   19 ...... 16, 15,   14, 13, 12,   11,       10,   9,    8,    7 ......... 0
; ------------------------------------------------------------------------------------------------------------------|
; | Base 31:24 | G=1 | D/B=1 | L=0 | AVL | Limit 19:16 | P=1 | DPL=0 | S=1 | Data(0) | D=0 | W=1 | A=0 | Base 23:16 |
; |-----------------------------------------------------------------------------------------------------------------|
; |                         Base 15:0                  |                       Limit 15:0                           |
; -------------------------------------------------------------------------------------------------------------------

.data_descriptor dw 0xFFFF, 0x0000, 0x9200, 0x00CF

; Function: load_gdtr
;
; Purpose: to load the GDT Register
;
; Parameters: AX [IN] = size of GDT
;             BX [IN] = location of GDT
;
load_gdtr:
	sub ax, 1
	mov word [.gdtd], ax

	xor eax,eax  ; offset

	mov ax, ds
	shl eax, 4  ; segment

	and ebx, 0xFFFF
	add eax, ebx  ; + offset
	mov [.gdtd+2], eax

	o32 lgdt [.gdtd]

	ret

.gdtd:
	dw 0 ; size of GDT in bytes - 1
	dd 0 ; offset as linear address

; GDT, 3 entries per 8 byte
align 8, db 0
GDT times 3*8 db 0
GDT_SIZE equ ($-GDT)


; Function:   open_a20
; Purpose:    to open the a20 line
; Parameters: none
; Returns:    0 in ax on success
;             1 in ax on failure
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
	jne .failure	; couldn't activate the gate

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

	mov al, [es:di]
	push ax

	mov al, [ds:si]
	push ax

	mov byte [es:di], 0x00
	mov byte [ds:si], 0xFF

	cmp byte [es:di], 0xFF

	pop ax
	mov [ds:si], al

	pop ax
	mov [es:di], al

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

; These two functions are defined in stage 1.
extern print_string, print_hex

; AL [IN] = character to print, fully state preserving
global print_char
print_char:
	push ax
	push bx

	mov ah, 0x0E
	xor bx, bx		; fg pixel color may go in bl ??
	int 10h

	pop bx
	pop ax
	ret

; Print entire eax
global print_hex_dword
print_hex_dword:
	rol eax, 16
	call print_hex

	rol eax, 16
	call print_hex
	ret


; Function:   wait_for_keypress
; Purpose:    to wait until a key is pressed. Fully CPU state preserving.
; Parameters: None.
wait_for_keypress:
	push ax

	xor ah, ah
	int 16h

	pop ax
	ret


; Function:   retrieve_memory_map_int15
; Purpose:    to query the memory map from the BIOS using int 15h with ax=e820h.
;             Self consistent in a fully CPU state preserving way.
; Parameters: none
; Returns:    CARRY: Set on error, cleared otherwise
retrieve_memory_map_int15:
	push eax
	push ebx
	push ecx
	push edx
	push si
	push di
	push es

	; print message
	mov si, .msgMemMap
	call print_string

	; Initialize Continuation
	xor ebx, ebx

.query_loop:
	; setup ES
	mov ax, 0
	mov es, ax

	; system call
	mov eax, 0e820h
	mov di, .descriptor
	mov ecx, 20
	mov edx, 'PAMS'		; respect little endian

	int 15h

	; evaluate result
	jnc .no_error

	; possible error, but the last valid descriptor might be indicated with
	; carry
	cmp byte [.first], 1
	je .success
	jmp .error

.no_error:
	; indicate success
	mov byte [.first], 1

	; Store entry in System Memory Map
	push eax
	push ebx
	push ecx
	push edx

	mov eax, [.descriptor]
	mov ebx, [.descriptor + 4]
	mov ecx, [.descriptor + 8]
	mov edx, [.descriptor + 12]

	cmp dword [.descriptor + 16], 1
	je .add_free_entry

	cmp dword [.descriptor + 16], 2
	je .add_reserved_entry

	cmp dword [.descriptor + 16], 3
	je .add_acpi_reclaim_entry

	cmp dword [.descriptor + 16],4
	je .add_acpi_nvs_entry

	; Undefined entry type, treat as reserved
	mov si, .msgUndefinedType
	call print_string

	mov eax, [.descriptor + 16]
	call print_hex_dword

	mov si, .msgUndefinedTypeEnd
	call print_string

	; Treat undefined entry as reserved
	jmp .add_reserved_entry

.descriptor_add_entry:
	call SystemMemoryMap_add
	jc .error

	pop edx
	pop ecx
	pop ebx
	pop eax

	cmp ebx, 0
	jne .query_loop

.success:
	mov si, .msgOk
	call print_string

	; Indicate OK
	clc

.end:
	pop es
	pop di
	pop si
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

.error:
	mov si, .msgError
	call print_string

	; Indicate error
	stc
	jmp .end


.add_free_entry:
	mov esi, SYSTEM_MEMORY_MAP_ENTRY_FREE
	jmp .descriptor_add_entry

.add_reserved_entry:
	mov esi, SYSTEM_MEMORY_MAP_ENTRY_RESERVED
	jmp .descriptor_add_entry

.add_acpi_reclaim_entry:
	mov esi, SYSTEM_MEMORY_MAP_ENTRY_ACPI_RECLAIM
	jmp .descriptor_add_entry

.add_acpi_nvs_entry:
	mov esi, SYSTEM_MEMORY_MAP_ENTRY_ACPI_NVS
	jmp .descriptor_add_entry

.first db 0

.descriptor times 20 db 0
.msgMemMap				db 'Retrieving memory map ', 0
.msgError				db ' [failed]', 0dh, 0ah, 0
.msgOk					db ' [OK]', 0dh, 0ah, 0
.msgUndefinedType		db 'Undefined descriptor type: ', 0
.msgUndefinedTypeEnd	db 'h, treeted as reserved.', 0dh, 0ah, 0



; ====================================
; protected mode execution starts here
; ====================================
; symbolic constants
TEXT_VIDEO_START equ 0xB8000

bits 32
entry_of_protected_mode:
	; load segment registers
	mov ax, 10h
	mov ds, ax
	mov es, ax

	; load stack pointer
	movzx esp, sp
	mov ss, ax     ; this would disable interrupts, debug exceptions and
	               ; single-step trap exceptions for one instruction, but it
		       ; might be better to not rely on that. This way it doesn't
		       ; matter if an interrupt occurs between those two instructions.

	call screen_clear
	call screen_home

	mov esi, .p_msgPModeEntered
	call p_print_string
	
	; Enter the fully platform specific C code of stage 2 (either a 32 bit or
	; 64 bit version).

	; Check and ensure stack alignment
	cmp esp, 0x7C00
	jne .errorStackPointerValue

	mov esi, .p_msgCallingCCode
	call p_print_string

	extern system_memory_map

	sub esp, 12
	push dword [system_memory_map]

	extern stage2_i386_c_entry
	call stage2_i386_c_entry

.end:
	hlt
	jmp .end

.errorStackPointerValue:
	mov esi, .p_msgStackPointerValue1
	call p_print_string

	mov eax, esp
	call p_print_hex

	mov esi, .p_msgStackPointerValue2
	call p_print_string
	jmp .end

; --- Messages ---
.p_msgPModeEntered db 'Entered protected mode.', 0x0D, 0x0A, 0
.p_msgCallingCCode db 'Calling C code.', 0x0d, 0x0a, 0
.p_msgStackPointerValue1 db "The Stack Pointer's value is not 0x7C00: ", 0
.p_msgStackPointerValue2 db 0x0d, 0x0a, 0


; =======================
; 32 bit calls start here
; =======================

; =================
; formatting output
; =================

; Function:   screen_clear
; Purpose:    to clear the screen, remove all characters and position the cursor
;             in the top left corner.
;             The processor state ins not modified (except EFLAGS).
; Parameters: none
global screen_clear
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

; Function:   screen_home
; Purpose:    to generate the basic layout of the screen in a fully processor
;             state preserving way (except EFLAGS).
; Parameters: none
screen_home:
	push eax  ; save registers
	push ecx
	push edi

	pop edi  ; restore registers
	pop ecx
	pop eax
	ret

; Function:   p_print_string
; Purpose:    to print a zero-terminated string in protected mode (without the BIOS)
;             in a fully state preserving way (except EFLAGS).
; Parameters: ESI [IN] = start address
; Returns:    nothing
global p_print_string
p_print_string:
	push eax  ; save registers
	push esi

	cld

.loop:
	lodsb
	or al, al
	jz .done   ; zero-byte, we are done

	call p_putchar
	jmp .loop

.done:
	pop esi  ; restore registers
	pop eax
	ret

; Function:   p_print_hex
; Purpose:    to print a hex value in protected mode in a fully state preserving
;             way (except EFLAGS).
; Parameters: EAX [IN] = number to print
; see:        http://wiki.osdev.org/Real_mode_assembly_II
global p_print_hex
p_print_hex:
	push eax

	call .word
	mov eax, [.temp]
	rol eax, 16
	call .word

	pop eax
	ret

.word:
	call .byte
	mov ax, [.temp+2]
	xchg ah, al
	shl eax, 16
	mov ax, [.temp]
	call .byte
	ret

.byte:
	mov [.temp],eax
	shr eax,28
	cmp al,10
	sbb al,69h
	das

	call p_putchar

	mov eax,[.temp]
	rol eax,4
	shr eax,28
	cmp al,10
	sbb al,69h
	das

	call p_putchar
	ret

.temp dd 0


; Function: p_putchar
; Purpose: to print a character in protected mode (without the BIOS),
;          state-preserving
; Parameters: AL [IN] = character
; Returns: nothing
;
; see http://wiki.osdev.org/Babystep4
global p_putchar
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

	xor ah, ah
	mov bl, 14  ; leave some space for status information
	div bl

	mov [ypos], ah
	jmp .end


; ---------------------------------------------------
xpos db 0
ypos db 0
