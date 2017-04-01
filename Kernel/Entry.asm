section .text
bits 32

extern binary_size
dd binary_size  ; size of the kernel, must be the first dword

; extern symbols
extern kernel_main

; ===========
; Entry Point
; ===========
entry_point:
	call disable_floppy_motors	; disable floppy motors

	call create_IDT			; set our own IDT

	sti				; enable interrupts

	; The ABI requires the stack to be 16 byte aligned before the call
	; instruction. This shall be the case as we're not in a function
	; called, but rather check it.
	test esp, 0Fh
	jnz .error_stack_alignment

	call kernel_main		; the kernel's main function

.end:
	hlt
	jmp .end

.error_stack_alignment:
	mov esi, .msg_error_stack_alignment
	call print_string
	jmp .end

.msg_error_stack_alignment db 'stack is not aligned to 16 bytes', 0x0D, 0x0A, 0

; ================
; helper functions
; ================

disable_floppy_motors:
	mov dx, 0x3F2			; floppy DOR
	in al, dx			; read DOR
	and al, 0Fh			; mask motor bits
	out dx, al			; write DOR
	ret


; ==================
; Terminal interface
; ==================

section .data
global terminal_row, terminal_column
terminal_row db 0
terminal_column db 0

section .text

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

; Function:   print_hex
; Purpose:    to print a hex value in protected mode in a fully state preserving
;             way (except EFLAGS).
; Parameters: EAX [IN] = number to print
; see:        http://wiki.osdev.org/Real_mode_assembly_II
print_hex:
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

	call putchar

	mov eax,[.temp]
	rol eax,4
	shr eax,28
	cmp al,10
	sbb al,69h
	das

	call putchar
	ret

.temp dd 0


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
	cmp byte [terminal_column], 80
	jae .end

	cmp byte [terminal_row], 25
	jae .end

	; print character
	mov ah, 0x0F  ; attrib = white on black

	mov ebx, 0xB8000		; text video memory starts at 0xB8000

	movzx edx, byte [terminal_row]
	imul edx, 160		; 80 columns * 2 bytes
	add ebx, edx

	movzx edx, byte [terminal_column]
	shl edx, 1		; 2 bytes per character (attrib)
	add ebx, edx

	mov [ebx], ax
	inc byte [terminal_column]

.end:
	pop edx
	pop ebx
	pop eax
	ret

.CR:
	mov byte [terminal_column], 0
	jmp .end

.LF:
	mov al, [terminal_row]
	inc al

	xor ah, ah
	mov bl, 14  ; leave some space for status information
	div bl

	mov [terminal_row], ah
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

	; register Invalid Opcode Exception handler
	mov eax, isr_UD
	mov ebx, IDT + 6h * 8  ; #UD is vector no. 6
	mov edx, 1             ; present
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
	; mov eax, isr_IRQ0_PIT
	; mov ebx, IDT + 20h * 8  ; IRQ0 is vector no. 20h
	; mov edx, 1              ; present
	; call encode_IDT_entry

	; load IDTR
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
; Purpose:    to load the IDTR and enable NMI afterwards.
; Parameters:  AX [IN] = size of IDT in bytes
;             EBX [IN] = linear address of IDT
load_IDTR:
	sub ax, 1        ; idtr containes size of IDT - 1
	mov [.idtd], ax
	mov [.idtd+2], ebx

	pushfd  ; save IF state
	cli     ; disable regular interrupts

	in al, 0x70  ; disable NMI
	or al, 0x80
	out 0x70, al

	lidt [.idtd]  ; no problem occurs from not disabling NMIs before lidt,
	              ; because NMIs are taken on an instruction boundary.
		      ; Therefore, in aspect of NMIs, each instruction is atomic.

	in al, 0x70
	and al, 0x7F
	out 0x70, al  ; enable NMI

	popfd  ; restore IF state

	ret

.idtd:
	dw 0  ; size of IDT in bytes - 1
	dd 0  ; linear address of IDT


; =============================
; Interrupt handlers start here
; =============================
; Function:   isr_DE
; Purpose:    to handle Divide-by-zero exceptions being registeres in the IDT
isr_DE:
	; I don't think there's a way to recover from this.
	; saving processor state doesn't make much sense as we won't return.
	mov esi, .msg
	call print_string

.endless_loop:
	hlt
	jmp .endless_loop  ; stick here in case of NMI/SMI (?)

.msg db 'Exception: Divide Error, either DIV/IDIV by 0 or result not representable.', 0x0D, 0x0A, 0

; Function:   isr_UD
; Purpose:    to handle a Invalid Opcode Exception
isr_UD:
	; saving the processor state doesn't make much sense as there's no way
	; to fix this in a program semantic keeping manner even though it is a Fault.
	mov esi, .msg1
	call print_string

	mov eax, [esp+4]		; print CS at #UD-ing instrucition
	call print_hex

	mov esi, .msg2
	call print_string

	mov eax, [esp]			; print EIP at #UD-ing instruction
	call print_hex

	mov esi, .msg3
	call print_string

.endless_loop:
	hlt
	jmp .endless_loop  ; stick here in case of NMI/SMI

.msg1 db 'Exception: Invalid Opcode at address 0x', 0
.msg2 db ':0x', 0
.msg3 db 0x0D, 0x0A, 0

; Function:   isr_DF
; Purpose:    to handle a Double Fault Exception
isr_DF:
	; saving the processor state doesn't make much sense as this is in class
	; Abort.
	mov esi, .msg
	call print_string

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
	call print_string  ; print some text

	mov eax, ebx

	rol eax, 16          ; extract selector index out of error code
	xor ax, ax
	rol eax, 16
	shr eax, 3

	call print_hex     ; print selector index

	; LDT or GDT?
	mov esi, .msgNP_2   ; assume GDT first

	test ebx, 4h         ; determine whether the selector refers to LDT or GDT
	jz .GDT

	mov esi, .msgNP_3   ; load LDT text
.GDT:
	call print_string  ; some more informal text

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
	call print_string        ; print some informal text

	mov eax, ebx

	rol eax, 16                ; extract vector number out of error code
	xor ax, ax
	rol eax, 16
	shr eax, 3

	call print_hex           ; print vector number

	; internal or external source?
	mov esi, .msgIDT_internal  ; assume internal source first

	test ebx, 1h               ; external or internal source?
	jz .internal

	mov esi, .msgIDT_external  ; choose the right text

.internal:
	call print_string  ; print more text

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
	call print_string

	mov eax, [esp+8]
	call print_hex

	mov esi, .msg2
	call print_string

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
	push eax  ; save eax, modified by print_string
	push esi

	mov esi, .msg
	call print_string

.endless_loop:
	hlt                ; halt the processor
	jmp .endless_loop  ; just in case of SMI

	pop esi  ; restore registers
	pop eax
	iretd

.msg db 'Interrupt: Non-maskable Interrupt', 0x0D, 0x0A, 0
