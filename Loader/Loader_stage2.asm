section .text
; org 0x7E00  ; done by linker
bits 16

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
; symbolic constants
TEXT_VIDEO_START equ 0xB8000

; extern symbols
extern floppy_init, floppy_timer, floppy_get_drive_type, floppy_get_reset_count
extern floppy_get_error_count, floppy_IRQ6_handler, floppy_debug_update
extern floppy_debug_set, floppy_test, floppy_read_data

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

	; setup IDT and enable interrupts
	call create_IDT    ; NMI will be enabled afterwards
	call init_PICs     ; init PICs and set vector offsets, all IRQs are masked

	sti                ; enable regular interrupts

	; set floppy debug view
	mov eax, TEXT_VIDEO_START + 15 * 80 * 2  ; line 15
	call floppy_debug_set                    ; set floppy debug video memory

	; initialize PIT, f_ticks = 1000 Hz
	mov ebx, 1000 << 8   ; 24.8 fixed
	call PIT_init_ticks

	; initialize floppy
	mov esi, .p_msgFloppyInitializing
	call p_print_string

	call floppy_init    ; initialize floppy subsystem
	or eax, eax         ; is EAX 0?
	jnz .floppy_failed  ; if not, print error message

	mov esi, .p_msgOK		; otherwise, print OK
	call p_print_string

	call .floppy_info  ; print some information

	mov esi, .p_msgFloppyReading
	call p_print_string

	; Read first sector of kernel that contains size information
	mov al, 0			; drive 0
	extern text_size
	mov ebx, text_size		; offset on disk in bytes (aligned to 200h)
	shr ebx, 9			; LBA
	mov ecx, 1			; sector count
	mov edi, 0x100000		; 1 MB
	call floppy_read_data		; read data
	or eax, eax			; is EAX 0?
	jnz .floppy_read_error

	mov esi, .p_msgOK
	call p_print_string

	mov ecx, [0x100000]		; read kernel size

	mov esi, .p_msgKernelSize1	; print kernel size
	call p_print_string

	mov eax, ecx			; value
	call p_print_hex

	mov esi, .p_msgKernelSize2	; suffix and CRLF
	call p_print_string

	cmp ecx, 0E00000h		; kernel to large to fit below ISA memory hole?
	ja .kernel_too_large

	add ecx, 1FFh			; round to full sectors
	shr ecx, 9			; bytes to sectors

	cmp ecx, 1			; if size <= 1 sector, we're done
	jbe .transfer_control

	mov esi, .p_msgFloppyReading
	call p_print_string

	dec ecx				; one sector already read
	inc ebx				; update LBA
	add edi, 200h			; update destination
	mov al, 0			; drive number was destroyed
	call floppy_read_data		; read remaining sectors
	or eax, eax			; is EAX 0?
	jnz .floppy_read_error

	mov esi, .p_msgOK
	call p_print_string

.transfer_control:
	mov esi, .p_msgKernelExecution
	call p_print_string

;	mov ecx, 5
;
;.wait_transfer:
;	mov eax, ecx
;	call p_print_hex
;
;	mov al, 0x0D
;	call p_putchar
;
;	mov eax, 1000			; 1 second
;	call sleep
;	loop .wait_transfer, ecx

	mov al, 0FFh			; disable interrupts
	out 0x21, al			; write to primary PIC
	out 0xA1, al			; write to secondary PIC

	jmp 0x100004			; Kernel's entry point

.end:
	hlt
	jmp .end

; error handlers
.floppy_failed:
	mov esi, .p_msgFailed  ; print error message
	call p_print_string

	call .floppy_info
	jmp .end

.floppy_read_error:
	mov esi, .p_msgFailed
	call p_print_string
	jmp .end

.kernel_too_large:
	mov esi, .p_msgKernelTooLarge
	call p_print_string
	jmp .end

.floppy_info:
	call floppy_get_drive_type	; retrieve detected drive type
	mov esi, eax			; prepare parameter
	call p_print_string		; print it

	mov esi, .p_msgFloppyResetCount  ; print floppy controller reset count message
	call p_print_string

	call floppy_get_reset_count      ; retrieve floppy controller reset count
	call p_print_hex                 ; print reset count

	mov esi, p_msgCRLF               ; print CRLF
	call p_print_string

	mov esi, .p_msgFloppyErrorCount ; print floppy error count message
	call p_print_string

	call floppy_get_error_count	; retrieve floppy error count
	call p_print_hex		; print error count

	mov esi, p_msgCRLF		; print CRLF
	call p_print_string
	ret


; --- Messages ---
.p_msgPModeEntered db 'Entered protected mode.', 0x0D, 0x0A, 0
.p_msgFloppyInitializing db 'Initializing floppy (controller and driver) ... ', 0
.p_msgFloppyResetCount db 'floppy controller reset count: 0x', 0
.p_msgFloppyErrorCount db 'floppy error count: 0x', 0
.p_msgFloppyReading db 'Reading from floppy ... ', 0
.p_msgOK db '[ OK ]', 0x0D, 0x0A, 0
.p_msgFailed db '[failed]', 0x0D, 0x0A, 0
.p_msgKernelSize1 db 'Kernel size: ', 0
.p_msgKernelSize2 db 'h bytes', 0x0D, 0x0A, 0
.p_msgKernelTooLarge db 'The Kernel is too large to fit below the ISA memory hole.', 0x0D, 0x0A, 0
.p_msgKernelExecution db 'Transfering execution to the kernel in:', 0x0D, 0x0A, 0
p_msgCRLF db 0x0D, 0x0A, 0


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

	mov edi, TEXT_VIDEO_START + 14 * 80 * 2	; line 14 (2 bytes per character)
	mov ecx, 80				; 80 characters per line
	mov ah, 04h				; attrib: red on black
	mov al, '='				; symbol

	cld
	rep stosw				; rep prefix

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

; Function:   create_IDT
; Purpose:    to create the IDT containing the popular exception and interrupt
;             handlers and load the IDTR. Additionally, NMI is enabled, regular
;             interrupts get preventively disabled, because the PICs might not
;             have been initialized yet.
; Parameters: EBX [IN] = Destination where to put the IDT
create_IDT:
	; fill with nonpresent descriptors
	mov ecx, 256
.fill:
	xor eax, eax    ; handler address doesn't matter

	mov ebx, ecx    ; descriptor index
	shl ebx, 3      ; offset is descriptor index * 8 during to 8 byte descriptors
	add ebx, IDT-8  ; add IDT's base to get the descriptor's address.
	                ; Trick: ecx goes from 1 to 256, subtract 1 descriptor.

	xor edx, edx    ; descriptor not present

	call encode_IDT_entry
	loop .fill

	; Register #DE handler
	mov eax, isr_DE
	mov ebx, IDT
	add ebx, 0h * 8  ; #DE is vector no. 0
	mov edx, 1       ; present

	call encode_IDT_entry

	; register NMI handler
	mov eax, isr_NMI
	mov ebx, IDT
	add ebx, 2h * 8  ; NMI is vector no. 2
	mov edx, 1       ; present

	call encode_IDT_entry

	; register Double Fault Exception handler
	mov eax, isr_DF
	mov ebx, IDT + 8h * 8  ; #DF is vector no. 8
	mov edx, 1             ; present
	call encode_IDT_entry

	; register handler for Segment Not Present exceptions
	mov eax, isr_NP
	mov ebx, IDT + 0Bh * 8  ; #NP is vector no. 11
	mov edx, 1              ; present
	call encode_IDT_entry

	; register GPF handler
	mov eax, isr_GPF
	mov ebx, IDT
	add ebx, 0Dh * 8  ; #GP is vector no. 0x0D
	mov edx, 1        ; present

	call encode_IDT_entry

	; register IRQ0 handler
	mov eax, isr_IRQ0_PIT
	mov ebx, IDT + 20h * 8  ; IRQ0 is vector no. 20h
	mov edx, 1              ; present
	call encode_IDT_entry

	; register IRQ6 handler
	mov eax, floppy_IRQ6_handler
	mov ebx, IDT + 26h * 8  ; IRQ6 is vector no. 26h
	mov edx, 1              ; present
	call encode_IDT_entry

	; load IDTR and enable NMI
	mov ax, IDT_SIZE
	mov ebx, IDT      ; flat memory model, every address is a linear address
	call load_IDTR

	ret

; The IDT
align 8, db 0
IDT times 8*256 db 0
IDT_SIZE equ $-IDT

; Function:   encode_IDT_entry
; Purpose:    to encode an IDT entry
; Parameters: EAX [IN] = Handler procedure address
;             EBX [IN] = Entry's destination
;             EDX [IN] = 1: entry present, 0: entry not present
encode_IDT_entry:
	mov [ebx], ax		; offset bits 0..15
	mov word [ebx+2], 8h	; selector (kernel, code)

	shl dx, 15		; shift present bit to msb
	or dx, 0E00h		; 32 bit interrupt gate, DPL = 0
	mov [ebx+4], dx

	rol eax, 16
	mov [ebx+6], ax		; offset bits 16..31
	ret

; Function:   load_IDTR
; Purpose:    to load the IDTR and enable NMI afterwards. Regular interrupts get
;             preventively disabled.
; Parameters:  AX [IN] = size of IDT in bytes
;             EBX [IN] = linear address of IDT
load_IDTR:
	sub ax, 1        ; idtr containes size of IDT - 1
	mov [.idtd], ax
	mov [.idtd+2], ebx

	cli  ; disable regular interrupts

	lidt [.idtd]  ; no problem occurs from not disabling NMIs before lidt,
	              ; because NMIs are taken on an instruction boundary.
		      ; Therefore, in aspect of NMIs, each instruction is atomic.

	in al, 0x70
	and al, 0x7F
	out 0x70, al  ; enable NMI

	ret

.idtd:
	dw 0  ; size of IDT in bytes - 1
	dd 0  ; linear address of IDT

; Function:   init_PICs
; Purpose:    to initialize the master and slave 8259 PIC, map interrupt
;             vectors to 20h-27h and 28h-2Fh, respectively.
;             After initialization, all vectors are masked.
; Parameters: none
; see:        http://wiki.osdev.org/PIC#Protected_Mode
init_PICs:
	mov al, 0x11  ; Initialization, ICW4 required
	out 0x20, al  ; start initialization sequence on the master PIC
	call .iowait  ; give the PIC some time to react to the command

	out 0xA0, al  ; start initialization sequence on the slave PIC
	call .iowait

	mov al, 20h   ; ICW2: Master PIC vector offset
	out 0x21, al
	call .iowait

	mov al, 28h   ; ICW2: Slave PIC vector offset
	out 0xA1, al
	call .iowait

	mov al, 4     ; ICW3: tell Master PIC that there is a slave PIC at IRQ2 (0000 0100)
	out 0x21, al
	call .iowait

	mov al, 2     ; ICW3: tell slave PIC its cascade identity
	out 0xA1, al
	call .iowait

	mov al, 1h    ; 8086/8088 mode, normal EOI
	out 0x21, al  ; set master PIC's operationing mode
	call .iowait

	out 0xA1, al  ; set slave PIC's operationing mode
	call .iowait

	xor al, al    ; mask all IRQs
	not al
	out 0x21, al
	out 0xA1, al

	ret

.iowait:
	jmp .iowait1
.iowait1:
	jmp .iowait2
.iowait2:
	ret


; =============================
; Interrupt handlers start here
; =============================
; Function:   isr_DE
; Purpose:    to handle Divide-by-zero exceptions being registeres in the IDT
isr_DE:
	; I don't think there's a way to recover from this.
	; saving processor state doesn't make much sense as we won't return.
	mov esi, .msg
	call p_print_string

.endless_loop:
	hlt
	jmp .endless_loop  ; stick here in case of NMI/SMI (?)

.msg db 'Exception: Divide Error, either DIV/IDIV by 0 or result not representable.', 0x0D, 0x0A, 0

; Function:   isr_DF
; Purpose:    to handle a Double Fault Exception
isr_DF:
	; saving the processor state doesn't make much sense as this is in class
	; Abort.
	mov esi, .msg
	call p_print_string

.endless_loop:
	hlt
	jmp .endless_loop  ; stick here in case of NMI/SMI

.msg db 'Exception: Double Fault', 0x0D, 0x0A, 0

; Function:   isr_NP
; Purpose:    to handle Segment Not Present exceptions
isr_NP:
	push eax  ; save processor state
	push ebx
	push esi

	mov ebx, [esp+12]  ; get error code

	test ebx, 2h      ; IDT flag set?
	jnz .IDT          ; If yes, handle that

	mov esi, .msgNP_1   ; otherwise a segment is really not present
	call p_print_string  ; print some text

	mov eax, ebx

	rol eax, 16          ; extract selector index out of error code
	xor ax, ax
	rol eax, 16
	shr eax, 3

	call p_print_hex     ; print selector index

	; LDT or GDT?
	mov esi, .msgNP_2   ; assume GDT first

	test ebx, 4h         ; determine whether the selector refers to LDT or GDT
	jz .GDT

	mov esi, .msgNP_3   ; load LDT text
.GDT:
	call p_print_string  ; some more informal text

.loopNP:
	hlt          ; halt for now
	jmp .loopNP  ; stick here in case of NMI/SMI

.end:
	add esp, 4  ; remove error code from stack
	pop esi
	pop ebx
	pop eax     ; restore processor state
	iretd

.IDT:
	mov esi, .msgIDT_info
	call p_print_string        ; print some informal text

	mov eax, ebx

	rol eax, 16                ; extract vector number out of error code
	xor ax, ax
	rol eax, 16
	shr eax, 3

	call p_print_hex           ; print vector number

	; internal or external source?
	mov esi, .msgIDT_internal  ; assume internal source first

	test ebx, 1h               ; external or internal source?
	jz .internal

	mov esi, .msgIDT_external  ; choose the right text

.internal:
	call p_print_string  ; print more text

.loopIDT:
	hlt           ; halt for now
	jmp .loopIDT  ; stick here in case of NMI/SMI
	jmp .end

.msgNP_1 db 'Exception: Segment with index ', 0
.msgNP_2 db 'h in the GDT not present.', 0x0D, 0x0A, 0
.msgNP_3 db 'h in the current LDT not present.', 0x0D, 0x0A, 0

.msgIDT_info db 'Exception: Gate descriptor ', 0
.msgIDT_external db 'h in IDT not present (external source)', 0x0D, 0x0A, 0
.msgIDT_internal db 'h in IDT not present (internal source)', 0x0D, 0x0A, 0

; Function:   isr_GPF
; Purpose:    to handle General Protection Fault Exceptions being registered in
;             the IDT
isr_GPF:
	push eax  ; save registers
	push esi

	mov esi, .msg1
	call p_print_string

	mov eax, [esp+8]
	call p_print_hex

	mov esi, .msg2
	call p_print_string

.endless_loop:
	hlt
	jmp .endless_loop  ; stick here for now (loop in case of NMI)

	pop esi  ; restore registers
	pop eax
	add esp, 4  ; GPF has a 32 bit error code pushed onto the stack
	iretd

.msg1 db 0x0D, 0x0A, 'Exception: General Protection Fault (Error code: ', 0
.msg2 db 'h)', 0x0D, 0x0A, 0

; Function:   isr_NMI
; Purpose:    to handle Non-maskable Interrupts by aborting execution
isr_NMI:
	push eax  ; save eax, modified by p_print_string
	push esi

	mov esi, .msg
	call p_print_string

.endless_loop:
	hlt                ; halt the processor
	jmp .endless_loop  ; just in case of SMI

	pop esi  ; restore registers
	pop eax
	iretd

.msg db 'Interrupt: Non-maskable Interrupt', 0x0D, 0x0A, 0

; Function:    isr_IRQ0_PIT
; Purpose:     to handle IRQ0 (generated by PIT), perform several tasks:
;               * Timer for sleep function
isr_IRQ0_PIT:
	push eax

	call floppy_timer		; floppy timer for motors (and possibly
	                                ; other things), interrupts are disabled

	call .update_debug_views	; update debug view(s)

	cmp byte [sleep_engaged], 0	; is a sleep to be performed currently?
	je .end				; if not, we're done

	dec dword [sleep_delay]		; decrement sleep counter
	jnz .end			; if it is not zero, we're done

	mov byte [sleep_engaged], 0	; otherwise, de-engage sleep

.end:
	mov al, 20h
	out 0x20, al  ; signal EOI

	pop eax
	iretd

.update_debug_views:
	inc byte [debug_update_counter]		; simple prescaler
	cmp byte [debug_update_counter], 33	; / 33
	jb .no_action				; not reached yet

	xor al, al
	mov byte [debug_update_counter], al	; clear counter

	call floppy_debug_update		; perform update

.no_action:
	ret


; ========================
; Interfacing with the PIT
; ========================
; PIT operating modes
PIT_MODE0_InterruptOnTerminalCount		equ 0
PIT_MODE1_HardwareReTriggerableInterrupt	equ 1
PIT_MODE2_RateGenerator				equ 2
PIT_MODE3_SquareWaceGenerator			equ 3
PIT_MODE4_SoftwareTriggeredStrobe		equ 4
PIT_MODE5_HardwareTriggeredStrobe		equ 5

; Function:   PIT_configure_channel
; Purpose:    to configure a PIT channel in a fully state-preserving way (except
;             EFLAGS). If the channel number is greater than 2, nothing happens.
; Parameters: AL [IN] = channel (0, 1 or 2, where channel 1 doesn't need to be present)
;             AH [IN] = operating mode (use above constants)
PIT_configure_channel:
	push eax

	cmp al, 2		; ensure channel number is in range
	ja .end			; if not, simply return

	shl al, 6		; channel number is in the two most significant bits
	and al, 0b110000	; Access mode: lobyte/hibyte, binary mode

	shl ah, 5		; clip ah to least significant three bits
	shr ah, 4		; adjust indent of mode bits
	or al, ah		; or other control bits with mode bits together

	out 0x43, al		; write to mode/command register

.end:
	pop eax
	ret

; Function:   PIT_unmask_interrupt
; Purpose:    to unmask IRQ0, which is asserted by PIT channel 0, in a fully
;             state-preserving way (except EFLAGS)
; Parameters: none
PIT_unmask_interrupt:
	push eax

	in al, 0x21
	and al, 0FEh
	out 0x21, al

	pop eax
	ret

; Function:   PIT_load_reload_value
; Purpose:    to load the reload value of a PIT channel in a fully state-preserving
;             way. If the channel number is greater than 2, nothing happens.
; Parameters: AX [IN] = new reload value
;             DL [IN] = channel (0, 1 or 2, where channel 1 doesn't need to be present)
PIT_load_reload_value:
	push eax
	push edx

	cmp dl, 2  ; make sure that the channel number is valid
	ja .end

	xor dh, dh
	add dx, 0x40  ; channel's data register is at address 0x40 + channel number

	pushfd
	cli		; disable interrupts to make loading an atomic operation
			; Important in case an interrupt handler loads the PIT.
	out dx, al	; write low value to PIT
	mov al, ah	; write high value to PIT
	out dx, al
	popfd		; finally, restore IF state by restoring EFLAGS

.end:
	pop edx
	pop eax
	ret

; Function:   PIT_init_ticks
; Purpose:    to initialize the PIT in a appropriate way to generate IRQ0 ticks
;             with a specified frequency. IRQ0 is unmasked. The function is
;             fully state-preserving (except EFLAGS).
; Parameters: EBX [IN] = (24.8 fixed) frequency in Hz
PIT_init_ticks:
	push eax  ; save registers
	push ebx
	push edx

	; initialize PIT
	mov al, 0
	mov ah, PIT_MODE2_RateGenerator
	call PIT_configure_channel

	; Compute and load reload value
	; f_PIT   := 3,579,545 / 3 Hz
	; f_ticks := f_PIT / N
	; N	  := prescaler, reload value
	;
	; --> N = f_PIT / f_ticks = 3,579,545 Hz / f_PIT / 3
	mov eax, 3579545  ; edx:eax = 3,579,545
	rol eax, 16       ; converto to 24.16 fixed format (2^24 = 16,777,216)
	movzx edx, ax
	xor ax, ax

	div ebx           ; eax = f_PIT / f_ticks in 24.8 fixed format

	mov ebx, 300h     ; 3 in 24.8 fixed format
	xor edx, edx

	div ebx           ; eax = f_PIT / f_ticks / 3 = N integer

	cmp edx, 180h     ; perform rounding (1.5 in 24.8 fixed format ...)
	jb .roundDown3    ; round down if remainder below half of 3

	inc eax

.roundDown3:
	mov dl, 0
	call PIT_load_reload_value  ; load value to the PIT

	; unmask PIT interrupt IRQ0
	call PIT_unmask_interrupt

	pop edx
	pop ebx
	pop eax  ; restore registers
	ret

; ========
; Sleeping
; ========
; Function:   sleep
; Purpose:    to wait for a specific delay (using IRQ0 and the PIT) in a fully
;             state-preserving way (except EFLAGS). Make sure to setup the PIT
;             and the IRQ0 handler before. Interrupts must be enabled.
;             If you want to make sure that execution is paused for at least the
;             specified delay, add 1 to the delay. Execution might be paused for
;             up to 1 ms less during to the timer interrupt beeing not synchronized
;             with the begin of sleeping periods.
; Parameters: EAX [IN] = time to sleep in milliseconds
global sleep
sleep:
	pushfd
	cli  ; disable interrupts to make writing to the sleep timer registers atomic

	mov [sleep_delay], eax       ; store delay
	mov byte [sleep_engaged], 1  ; engage sleep timer

	popfd                        ; reset interrupt state (should be enabled)

	; for now, just wait until specific time is over (can't use hlt here,
	; because signalling wouldn't work properly)
.loop:
	cmp byte [sleep_engaged], 0
	jne .loop

	ret

; ---------------------------------------------------
xpos db 0
ypos db 0

sleep_engaged db 0
sleep_delay   dd 0

debug_update_counter db 0	; prescaler for updating debug view(s)
