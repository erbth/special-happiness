; Protected mode floppy driver for the second stage of the bootloader
; Only the master drive is supported by this driver.
;
; On controller HUP the controller shall be left in a clean state on exit of any
; function that is it shall be reset on exit. When the controller is in a HUP
; state in a function in command issuing layer, the function resets the controller
; before exiting.
;
; If a certain procedure requires a specific drive to be selected, it should
; call floppy_reselect_drive before any command (except the first after
; floppy_drive_select) to make sure, the drive is actually selected. This is
; because the command issuing functions might perform controller resets which
; will load default values. This cannot be done automatically in a clean way
; (same way in every function) without the risk of recursion loops.
; When a command function requires the correct drive to be selected, it will
; reselect the drive after it performed a reset and before it retries the command.
; But after the last reset before a return with error, this is not done.
;
; Functions will assume that NMIs are enabled when accessing the CMOS, therfore,
; if NMIs are disabled, they will be enabled by those functions.
;
; Todo: HW reset ? currently: nothing will clear the reset flag in the DOR,
;                  all further commands after HW reset will fail.
;
;       out-of-order execution errors
;       motor on/off (no automatic of if on)
;       reset reselect drive
;
; see http://wiki.osdev.org/FDC
bits 32

%macro DEBUG 1
	push eax
	mov al, %1
	call p_putchar
	pop eax
%endmacro

; external symbols
extern p_print_hex, p_print_string, p_putchar
extern sleep

; symbolic constants
; see http://wiki.osdev.org/FDC#Registers
SRA		equ 0x3F0  ; read obly
SRB		equ 0x3F1  ; read only
DOR		equ 0x3F2
TDR		equ 0x3F3
MSR		equ 0x3F4  ; read only
DSR		equ 0x3F4  ; write only
FIFO		equ 0x3F5
DIR		equ 0x3F7  ; read only
CCR		equ 0x3F7  ; write only

; ========================
; main interface functions
; ========================

; Function:   floppy_init
; Purpose:    to initialize the floppy driver and controller. Has to be
;             successfully called once before the drive can be used.
;             If this function failed, it is always valid to call
;             floppy_get_drive_string and that will always return a correct value
;             (read from CMOS).
;             This function is fully state preserving (except EFLAGS).
; Parameters: none
; Returns:    0 in EAX if the initialization succeeded,
;             1 in EAX if the initialization failed
; see:        http://wiki.osdev.org/FDC#Procedures
global floppy_init
floppy_init:
	push edx  ; save registers

	xor ax,ax
	mov [floppy_status], ax		; clear status word

	call floppy_CMOS_get_type	; read drive type from CMOS

	cmp byte [floppy_type], 0	; is a master floppy connected?
	je .no_drive			; if not, we're done.

	cmp byte [floppy_type], 5	; is the drive type valid?
	ja .invalid_drive		; if not, we're done.

	mov dx, MSR			; query MSR
	in al, dx			; 16 bit IO port address
	test al, 10h			; query the CMD BSY flag
	jnz .not_idle			; return if the controller is busy

	call floppy_disable_interrupt	; make sure interrupt is disabled
	call floppy_wait_IRQ6_start	; wait for foreign interrupt

	in al, 0x21			; read master PIT's mask register
	and al, ~(1 << 6)		; enable IRQ 6
	out 0x21, al			; write master PIT's mask register

	mov eax, 51			; wait at least 50 ms for an interrupt that
					; might have been asserted before
	call floppy_wait_IRQ6_end

	call floppy_cmd_version		; issue a version command
	cmp ax, 90h			; is it a 82077AA or compatible?
	jne .unsupported_controller	; if not, return

	call floppy_cmd_configure	; issue a configure command
	or al, al			; quick test for AL 0
	jnz .configure_error		; return in case of failure

	mov al, 1			; lock settings
	call floppy_cmd_lock		; issue lock command
	or al, al			; AL == 0?
	jnz .lock_error			; return in case of failure

	call floppy_reset_reconfigure	; perform a contoller reset
	                                ; this will set the Specify Required and
					; the Select Required flags.
	or al, al			; AL == 0?
	jnz .reset_error		; return in case of failure

	mov al, 0			; recalibrate drive no. 0
	call floppy_recalibrate		; issue a recalibrate command
	or al, al			; is AL 0?
	jnz .recalibrate_error		; return in case of failure

	xor eax, eax			; success return code
	jmp .end			; otherwise return with success

.recalibrate_error:
.reset_error:
.lock_error:
.configure_error:
.unsupported_controller:
.not_idle:
.invalid_drive:
.no_drive:

	xor eax, eax
	inc eax       ; EAX := 1

.end:
	mov edx, eax			; save eax
	xor eax, eax			; drive 0
	call floppy_motor_off		; shut off motor
	mov eax, edx			; restore eax
	
	pop edx  ; restore registers
	ret


; Function:   floppy_get_drive_string
; Purpose:    to return a pointer to a static string that describes the connected
;             drive. If the connected drive is invalid, this function returns
;             'no drive' like it does, when no drive is connected.
;             The function is fully state preserving (except EFLAGS).
; Parameters: none
; Returns:    EAX [OUT] = pointer to static string describing the drive
global floppy_get_drive_type
floppy_get_drive_type:
	movzx eax, byte [floppy_type]      ; read floppy type
	cmp eax, 5                         ; is the drive type invalid?
	jbe .load_table                    ; if not, access type table

	xor eax, eax                       ; otherwise, return .msgNoDrive

.load_table:
	mov eax, [eax*4+.msgTable_Drives]  ; load pointer from table
	ret

.msgTable_Drives:
	dd .msgNoDrive
	dd .msgDrive_360
	dd .msgDrive_12
	dd .msgDrive_720
	dd .msgDrive_144
	dd .msgDrive_288

.msgNoDrive   db 'no drive', 0x0D, 0x0A, 0
.msgDrive_360 db 'detected a 360 KB 5.25 inch drive', 0x0D, 0x0A, 0
.msgDrive_12  db 'detected a 1.2 MB 5.25 inch drive', 0x0D, 0x0A, 0
.msgDrive_720 db 'detected a 720 KB 3.5 inch drive', 0x0D, 0x0A, 0
.msgDrive_144 db 'detected a 1.44 MB 3.5 inch drive', 0x0D, 0x0A, 0
.msgDrive_288 db 'detected a 2.88 MB 3.5 inch drive', 0x0D, 0x0A, 0


; Function:   floppy_get_reset_count
; Purpose:    to retrieve the floppy reset count, which is not exported, in a
;             fully state preserving way (except EFLAGS).
; Parameters: none
; Returns:    the reset count in eax
global floppy_get_reset_count
floppy_get_reset_count:
	mov eax, [floppy_reset_count]
	ret

; Function:   floppy_get_error_count
; Purpose:    to retrieve the error counter in a fully processor state preserving
;             way (except EFLAGS).
; Parameters: none
; Returns:    EAX [OUT] = error count
global floppy_get_error_count
floppy_get_error_count:
	mov eax, [floppy_error_count]
	ret

; Function:   floppy_timer
; Purpose:    to perform tasks on a regular time base (only motor cut off timer
;             at the moment). This shall be called every millisecond, usually by
;             an IRQ0. This function must be called only once a time and no other
;             floppy function must be called during the execution of this function
;             that is e.g. disable interrupts. However, calling this function in
;             a different floppy function is allowed. It is fully state
;             preserving (except EFLAGS), but NOT an IRQ handler!
; Parameters: none
global floppy_timer
floppy_timer:
	call floppy_motor_cutoff
	ret

; =============================
; internal functions start here
; =============================
; Function:   floppy_CMOS_get_type
; Purpose:    to read the type of the attached drive from CMOS in a fully
;             state preserving way (except EFLAGS). Only the master drive is
;             supported.
; Parameters: none
; Result:     (implicitely floppy_status [OUT])
floppy_CMOS_get_type:
	push eax  ; save registers

	or al, 0x90   ; query register 0x10, assume NMIs are enabled
	out 0x70, al

	in al, 0x71
	shr al, 4              ; only master drive supported
	mov [floppy_type], al  ; store floppy type

	pop eax  ; restore registers
	ret

; =====================
; command issuing layer
; =====================

; Function:   floppy_cmd_version
; Purpose:    to issue a Version command to the floppy controller in a fully
;             state preserving way (except EFLAGS)
; Parameters: none
; Result:     AX [OUT] = result of Version command or -1 in case of failure
floppy_cmd_version:
	push ebx  ; save registers
	push ecx

	mov bl, 3		; overall timeout: try command not more than 3 times
	jmp .begin		; jump to begin of command phase

.reset:
	call floppy_reset_reconfigure  ; A fatal error occured, reset the controller.
	                        ; (even if there are no more retries, to put the
				; controller in a clean state on exit)
	or al, al		; is AL 0?
	jnz .error		; if not, return with error

	dec bl			; decrement timeout
	jz .error		; return with failure if already tried 3 times

.begin:
	mov al, 16		; Version command has id 16
	call floppy_cmd_begin	; talk to the controller
	jc .reset		; reset controller in case of failure

	call floppy_cmd_result	; read result byte
	jc .reset		; reset controller in case of failure
	mov ah, al		; protect al

	call floppy_cmd_end	; wait for controller
	jc .reset		; reset controller in case of failure

	shr ax, 8		; prepare result

.done:
	pop ecx
	pop ebx  ; restore registers
	ret

.error:
	mov ax, -1		; error return code
	jmp .done


; Function:   floppy_cmd_configure
; Purpose:    to send a Configure command to the floppy controller using default
;             values:
;                     implied seek enabled,
;                     fifo enabled,
;                     drive polling disabled
;                     and threshold 8.
;             IMPORTANT: the configurationcould be lost after calling this
;             function (if a reset is performed). Usually, this is no problem,
;             because apart from initialization (where no configuration was
;             specified yet) this function should not be called manually,
;             floppy_reset_reconfigure will keep respect of this automatically.
;             The command is fully state preserving (except EFLAGS).
; Parameters: none
; Result:     0 in AL if command succeeded,
;             1 in AL if command failed.
floppy_cmd_configure:
	push ebx  ; save registers
	push ecx

	mov bl, 3		; overall timeout
	jmp .begin

.reset:
	call floppy_reset	; fatal error, reset controller
				; Use normal reset here as this is the configure
				; command and it will reconfigure the controller
				; in the next retry or it won't work generally.
				; Also, this prevents recursion loops.
				; However, this means the selected drive could
				; be lost after this command.

	dec bl			; decrement timeout
	jz .error		; return with failure if timeout exceeded

.begin:
	mov al, 19		; Configure command has id 19
	call floppy_cmd_begin	; talk to controller
	jc .reset		; reset controller in case of failure

	mov al, 0		; first parameter byte: 0
	call floppy_cmd_param	; talk to controller
	jc .reset		; reset controller in case of failure

	mov al, 57h		; implied seek enabled, fifo enabled, drive polling
	                        ; disabled, threshold 8
	call floppy_cmd_param	; talk to controller
	jc .reset		; reset controller in case of failure

	mov al, 0		; 3rd parameter byte: write precompensation 0
	call floppy_cmd_param	; talk to controller
	jc .reset		; reset controller in case of failure

	call floppy_cmd_end	; wait for controller
	jc .reset		; error

	xor al,al		; AL [OUT] = 0, success

.done:
	pop ecx  ; restore registers
	pop ebx
	ret

.error:
	mov al, 1		; error return code
	jmp .done


; Function:   floppy_cmd_lock
; Purpose:    to issue a lock command to the controller (in order to protect
;             fifo enabled, fifo threshold and precompensation settings from
;             reset) in a fully state preserving way (except EFLAGS).
; Parameters: AL [IN] = not 0: lock settings, 0: unlock settings.
; Returns:    0 in AL if command succeeded,
;             1 in AL if command failed.
floppy_cmd_lock:
	push ebx  ; save registers
	push ecx

	xor bh, bh		; assume settings shall be unlocked (MT 0)
	or al, al		; AL == 0?
	jz .unlock		; if yes, settings shall be unlocked

	or bh, 80h		; otherwise, set MT flag for locking

.unlock:
	mov bl, 3		; overall timeout
	jmp .begin

.reset:
	call floppy_reset_reconfigure  ; fatal error, reset controller
	or al, al		; id AL 0?
	jnz .error		; if not, return with error

	dec bl			; decrement timeout
	jz .error		; return with failure if timeout exceeded

.begin:
	mov al, 20		; Lock command has id 20
	or al, bh		; or with MT flag (lock bit)

	call floppy_cmd_begin	; talk to controller
	jc .reset		; reset controller in case of failure

	call floppy_cmd_result	; read result byte
	jc .reset		; reset controller in case of failure

	rol al, 3		; return code must be 0b 0 0 0 lck 0 0 0 0
	cmp al, bh		; does it match with lock bit (MT flag)?
	jne .reset		; if not, reset controller

	call floppy_cmd_end	; wait for controller to finish processing cmd
	jc .reset		; reset controller in case of failure

	xor al, al		; return code for success

.done:
	pop ecx  ; restore registers
	pop ebx
	ret

.error:
	mov al, 1		; error return code
	jmp .done


; Function:   floppy_cmd_recalibrate
; Purpose:    to issue a recalibrate command to the controller in a fully state
;             preserving way (except EFLAGS). The specified drive must be
;             selected already and have its motor on. (?)
; Parameters: AL [IN] = drive number
; Returns:    0 in AL if command succeeded,
;             1 in AL if command failed.
floppy_cmd_recalibrate:
	push ebx  ; save registers
	push ecx

	mov ch, al		; save drive number

	mov bl, 3		; overall timeout
	jmp .begin

.reset:
	call floppy_reset_reconfigure  ; fatal error, reset controller
	or al, al		; is AL 0?
	jnz .error		; if not, return with error

	dec bl			; decrement timeout
	jz .error		; return with failure if timeout exceeded

	call floppy_reselect_drive  ; reselect drive after reset
	or al, al		; is AL 0?
	jnz .error		; if not, return with error

.begin:
	mov al, 7		; Recalibrate command has id 7
	call floppy_cmd_begin	; talk to the controller
	jc .reset		; reset controller in case of failure

	mov al, ch		; parameter byte: drive number
	call floppy_cmd_param	; talk to controller
	jc .reset		; reset controller in case of failure

	call floppy_cmd_end	; wait for controller
	jc .reset		; reset controller in case of failure

	xor al, al		; success return code

.done:
	pop ecx  ; restore registers
	pop ebx
	ret

.error:
	mov al, 1		; error return code
	jmp .done


; Function:   floppy_cmd_sense_interrupt
; Purpose:    to issue a Sense Interrupt command in order to acknowledge an
;             IRQ6 after certain commands. The function is fully state preserving
;             (except EFLAGS).
; Parameters: none
; Returns:    AL [OUT] = 0 if function succeeded, 1 if function failed.
;             AH [OUT] = ST0
;             BL [OUT] = PCN
floppy_cmd_sense_interrupt:
	push ecx  ; save registers

	mov bl, 3		; overall timeout
	jmp .begin

.reset:
	call floppy_reset_reconfigure  ; fatal error, reset controller
	or al, al		; is AL 0?
	jnz .error		; if not, return with error

	dec bl			; decrement timeout
	jz .error		; if timeout exceeded, return with failure

.begin:
	mov al, 8		; Sense Interrupt command has id 8
	call floppy_cmd_begin	; talk to the controller
	jc .reset		; reset controller in case of failure

	call floppy_cmd_result	; read first result byte
	jc .reset		; reset controller in case of failure
	mov ah, al		; save return value

	call floppy_cmd_result	; read 2nd result byte
	jc .reset		; reset controller in case of failure
	mov ch, al		; save cylinder number

	call floppy_cmd_end	; wait for the controller
	jc .reset		; reset the controller in case of failure

	xor al, al		; success return code
	mov bl, ch		; prepare return value

.done:
	pop ecx  ; restore registers
	ret

.error:
	mov al, 1		; error return code
	jmp .done


; Function:   floppy_cmd_specify
; Purpose:    to send a Specify command to the controller using given values.
;             Reasonable default values for the Parameters are:
;             (see http://wiki.osdev.org/FDC#Specify and 82077AA's datasheet, page 31f)
;                SRT:   8 ms, value 8  (for 1.44" drive)
;                HLT:  30 ms, value 15 (for 1.44" drive)
;                HUT:  maximum, value 0
;             If invalid parameters are given, the function returns with error.
;             The function is fully state preserving (except EFLAGS).
; Parameters: AL [IN] = SRT  Step Rate Time
;             AH [IN] = HLT  Head Load Time
;             BL [IN] = HUT  Head Unload Time
;             BH [IN] = ND   0: DMA mode, non-0: NON-DMA (PIO) mode
; Returns:    0 in AL on success,
;             1 in AL on error
floppy_cmd_specify:
	push ebx  ; save registers
	push ecx
	push eax

	cmp al, 15		; is SRT <= 15 ?
	ja .error		; if not, return with error

	cmp ah, 127		; is HLT <= 127 ?
	ja .error		; if not, return with error

	cmp bl, 15		; is HUT <= 15 ?
	ja .error		; if not, return with error

	or bh, bh		; convert BH to 0/1
	jz .DMA

	mov bh, 1

.DMA:
	mov ch, al		; CH is 1st parameter byte
	shl ch, 4
	or ch, bl		; CH = SRT << 4 | HUT

	shl ah, 1		; contruct 2nd parameter byte
	or bh, ah		; BH = HLT << 1 | NDMA

	mov bl, 3		; retry communication 3 times
	jmp .begin

.reset:
	call floppy_reset_reconfigure  ; reset controller
	or al, al		; is AL 0?
	jnz .error		; if not, return with error

	dec bl			; decrement counter
	jz .error		; return if this was the 3rd retry

.begin:
	mov al, 3		; Specify command has id 3
	call floppy_cmd_begin	; talk to controller
	jc .reset		; reset controller in case of failure

	mov al, ch		; 1st parameter byte
	call floppy_cmd_param	; talk to controller
	jc .reset		; reset controller in case of failure

	mov al, bh		; 2nd parameter byte
	call floppy_cmd_param	; talk to controller
	jc .reset		; reset controller in case of failure

	call floppy_cmd_end	; wait for controller
	jc .reset		; reset in case of failure

	xor al, al		; success return code

.done:
	mov bl, al  ; save al
	pop eax     ; restore eax
	mov al, bl  ; reapply al

	pop ecx  ; restore other registers
	pop ebx
	ret

.error:
	mov al, 1		; error return code
	jmp .done

; Function:   floppy_cmd_dumpreg
; Purpose:    to issue a Dumpreg command. The results are stored in a 10 byte
;             memory buffer whose base address must be given as parameter.
;             It has the following structure (see 82077AA's datasheet, p. 22):
;                0x0: PCN-Drive 0
;                0x1: PCN-Drive 1
;                0x2: PCN-Drive 2
;                0x3: PCN-Drive 3
;                0x4: SRT, HUT
;                0x5: HLT, ND
;                0x6: SC/EOT
;                0x7: LOCK, D3, D2, D1, D0, GAP, WGATE
;                0x8: EIS, EFIFO, POLL, FIFOTHR
;                0x9: PRETRK
;             The function is fully processor state preserving (except EFLAGS).
; Parameters: EDI [IN] = address of a 10 byte memory buffer
; Returns:    0 in AL on success, 1 on error
floppy_cmd_dumpreg:
	push ebx  ; save registers
	push ecx
	push edi

	mov bl, 2+1		; retry 2 times
	jmp .begin

.reset:
	call floppy_reset_reconfigure  ; reset controller
	or al, al		; is AL 0?
	jnz .done		; if not, return with error (AL is 1)

	mov al, 1		; preload al with error return code
	dec bl			; decrement counter
	jz .done		; return with error if this would be the 3rd retry

	pop edi			; restore edi as it might have been altered
				; during reading result bytes
	push edi

.begin:
	mov al, 14		; Dumpreg has id 14
	call floppy_cmd_begin	; talk to controller
	jc .reset		; reset controller in case of failure

	mov ch, 10		; 10 result bytes
	cld			; clear direction flag

.result_loop:
	call floppy_cmd_result	; read result byte
	jc .reset		; reset controller in case of failure
	stosb			; store result byte

	dec ch			; decrement loop counter
	jnz .result_loop	; perform loop

	call floppy_cmd_end	; wait for controller
	jc .reset		; reset controller in case of failure

	xor al, al		; success return code

.done:
	pop edi  ; restore registers
	pop ecx
	pop ebx
	ret


; =================================
; functions for specific procedures
; =================================

; Function:   floppy_recalibrate
; Purpose:    to perform a recalbration sequence on a drive by performing a drive
;             select procedure, issuing a Recalibrate command and issuing a
;             Sense Interrupt command. The recalibration will be retried twice
;             in case of non-command level failure. Thus, if a disk with 83
;             cylinders is used, the required second recalibration sequence will
;             be performed.
;             The function is fully state preserving (except EFLAGS).
; Parameters: AL [IN] = drive number
; Returns:    0 in AL if function succeeded,
;             1 in AL if function failed.
floppy_recalibrate:
	push ebx  ; save registers
	push ecx
	push eax

	mov ch, al		; save drive number

	call floppy_select_drive  ; perform a drive select procedure
	or al, al		; is AL 0?
	jnz .error		; if not, return with error

	mov al, ch		; drive number
	call floppy_motor_on	; switch on drive motor

	mov bh, 2+1		; retry recalibration 2 times
	jmp .recalibration

.reset:
	call floppy_reset_reconfigure  ; reset controller
	or al, al		; is AL 0?
	jnz .error		; if not, return with error

.retry:
	dec bh			; decrease counter
	jz .error		; return with failure if this is the 3rd retry

	call floppy_reselect_drive  ; reselect drive after possible reset
	or al, al		; is AL 0?
	jnz .error

.recalibration:
	call floppy_wait_IRQ6_start   ; wait for interrupt
	call floppy_enable_interrupt  ; enable interrupts

	mov al, ch		; drive number
	call floppy_cmd_recalibrate  ; issue Recalibrate command
	or al, al		; is AL 0?
	jnz .error		; if not, return with error

	mov eax, 4001                  ; timeout: >~4s
	call floppy_wait_IRQ6_end      ; wait for interrupt
	call floppy_disable_interrupt  ; disable interrupts

	or eax, eax		; is EAX 0?
	jnz .reset		; reset controller in case of timeout

	call floppy_cmd_sense_interrupt  ; issue a Sense Interrupt command
	or al, al		; is AL 0?
	jnz .error		; return in case of failure on command issuing level

	mov al, ch		; compare ST0 with 20h | drive number
	or al, 20h
	cmp al, ah
	jne .retry		; if it doesn't match, retry recalibration
	                	; this might be the case due to failure or 83 cylinder disk

	or bl, bl		; is PCN 0?
	jnz .retry		; if not, retry recalibration

	xor al, al		; return code for success

.end:
	mov cl, al  ; save return value
	pop eax     ; restore eax
	mov al, cl  ; apply return value

	pop ecx  ; restore other registers
	pop ebx
	ret

.error:
	mov al, 1		; error return code
	jmp .end


; Function:   floppy_select_drive
; Purpose:    to perform a drive select procedure by setting the correct
;             datarate in CCR, eventually sending a specify command and setting
;             the "drive select" bits in DOR. The drive type must be valid
;             (1 <= drive type <= 5), this is usually the case after floppy_init
;             succeeded.
;             The function is fully state preserving (except EFLAGS).
; Parameters: AL [IN] = drive number
; Returns:    0 in AL in case of success,
;             1 in AL in case of failure
floppy_select_drive:
	push ebx  ; save registers
	push edx
	push eax

	mov [.drive_no], al		; save drive number

	test byte [floppy_status], 2h	; is a select procedure always required?
	jnz .do_select			; if yes, jump to select procedure

	cmp al, [floppy_selected_drive]	; is the drive already selected?
	je .succeeded			; if yes, we're done

.do_select:
	movzx edx, byte [floppy_type]	; read floppy type
	mov al, [.table_datarates+edx-1]  ; lookup correct datarate for drive

	mov dx, CCR			; DX = CCR
	out dx, al			; set CCR, upper 6 bits can be set to 0 safely

	test byte [floppy_status], 1h	; is a Specify command always required?
	jnz .send_Specify		; if yes, jump to sending Specify command

	; here would be the logic to determine whether a Specify command is
	; required, based on whether the new drive's type matches the previously
	; selected drives type. Currently, only drive 0 is supported, so this
	; is trivial "never".
	jmp .after_Specify

.send_Specify:
	mov dl, 2+1			; retry command 2 times
	jmp .begin

.retry:
	mov al, 1			; preload AL with error return code
	dec dl				; decrement counter
	jz .end				; return with failure if this was the 3rd
					; retry

.begin:
	movzx ebx, byte [floppy_type]	; drive type
	mov al, [.params_srt+ebx-1]	; SRT
	mov ah, [.params_hlt+ebx-1]	; HLT
	mov bl, [.params_hut+ebx-1]	; HUT
	mov bh, 1			; PIO mode

	call floppy_cmd_specify		; issue Specify command
	or al, al			; is AL 0?
	jnz .retry			; if not, retry command

.after_Specify:
	and word [floppy_status], ~1h	; remove Specify Required flag

	mov dx, DOR			; DX = DOR
	in al, dx			; read DOR
	and al, ~3h			; zero lower 2bits (drive number)
	or al, [.drive_no]		; set correct drive number
	out dx, al			; write to DOR

.succeeded:
	and word [floppy_status], ~2h	; remove Select Required flag
	mov al, [.drive_no]
	mov [floppy_selected_drive], al ; update selected drive variable
	xor al, al			; success return code

.end:
	mov bl, al  ; save AL
	pop eax     ; restore EAX
	mov al, bl  ; reapply AL

	pop edx  ; restore other registers
	pop ebx
	ret

.drive_no db 0

.table_datarates:
	db 2  ; 360 KB   (DD, 250 kbit/s)
	db 0  ; 1.2 MB   (HD, 500 kbit/s)
	db 2  ; 720 KB   (DD, 250 kbit/s)
	db 0  ; 1.44 MB  (HD, 500 kbit/s)
	db 3  ; 2.88 MB  (ED, 1 Mbit/s)

.params_srt:
	db  0  ; 360 KB  5.25"  (0 is maximum)
	db  0  ; 1.2 MB  5.25"
	db  0  ; 720 KB  3.5"
	db  8  ; 1.44 MB 3.5"
	db  0  ; 2.88 MB 3.5"

.params_hlt:
	db   0  ; 360 KB  5.25"  (0 is maximum)
	db   0  ; 1.2 MB  5.25"
	db   0  ; 720 KB  3.5"
	db  15  ; 1.44 MB 3.5"
	db   0  ; 2.88 MB 3.5"

.params_hut:
	db  0  ; 360 KB  5.25"  (0 is maximum)
	db  0  ; 1.2 MB  5.25"
	db  0  ; 720 KB  3.5"
	db  0  ; 1.44 MB 3.5"
	db  0  ; 2.88 MB 3.5"


; Function:   floppy_reselect_drive
; Purpose:    to reselect a drive after a reset in a fully state preserving way
;             (except EFLAGS). If not called after previous reset (that is,
;             Select Required flag is not set) it will do nothing, because the
;             drive will be selected already.
; Parameters: none
; Returns:    0 in Al on success,
;             1 in AL on error
floppy_reselect_drive:
	mov al, [floppy_selected_drive]
	call floppy_select_drive
	ret


; Function:   floppy_reset
; Purpose:    to reset the floppy controller in a fully processor state preserving
;             way (except EFLAGS). All flags of DOR are preserved, expecially the
;             reset flag. That means if the controller was in reset state before
;             calling this function, the controller will stay in reset state
;             (important for handling HW resets: any command will fail).
; Parameters: none
; see:        http://wiki.osdev.org/FDC#Procedures
floppy_reset:
	push eax  ; save registers
	push ebx
	push edx

	and word [floppy_status], ~4h  ; pause motor timers so motors won't be turned
	                               ; off and turned on again when restoring DOR

	; enter reset mode
	mov dx, DOR		; DX = DOR
	in al, dx		; save DOR
	mov bl, al

	xor al, al		; zero AL
	out dx, al		; enter reset mode

	mov eax, 2		; wait at least 1 ms
	call sleep

	mov al, bl		; restore original DOR
	out dx, al

	or word [floppy_status], 4h  ; enable motor timers

	; IRQs turned of, not required to wait for IRQ6
	; drive polling mode disabled, not required to send 4 Sense Interrupt commands
	; FIFOs locked, no need for new Configure command

	or word [floppy_status], 3h     ; set Specify Required flag as well as
	                                ; Select Required flag
	inc dword [floppy_reset_count]  ; increase reset count

.end:
	pop edx  ; restore registers
	pop ebx
	pop eax
	ret

; Function:   floppy_reset_reconfigure
; Purpose:    to perform a controller reset with reconfiguration afterwards.
;             A controller reset clears EIS and POLL bits. This function makes
;             sure that the controller is in the same state after the reset
;             as it was before. Normally, this function should always be used.
;             As all command layer functions used by this function leave the
;             controller in a clean state on error (after performing a reset
;             without, this Function leaves the controller in a clean state on
;             error, too.
;             The processor's state is not modified (except EFLAGS).
; Parameters: none
; Returns:    1 in AL in case of failure, 0 in case of success
floppy_reset_reconfigure:
	call floppy_reset		; reset controller

	call floppy_cmd_configure	; issue configure commans
	or al, al			; is AL 0?
	jnz .end			; if not, return with error (AL is 1)

.end:
	ret


; Function:   floppy_motor_on
; Purpose:    to make sure a specific drive's motor cutoff timer is disabled,
;             switch it's motor on (if it isn't already on) and wait an appropriate
;             delay for it to spin up. If the drive number is out of range, the
;             function simply returns. The function is fully state preserving
;             (except EFLAGS).
; Parameters: AL [IN] = drive number
floppy_motor_on:
	push eax  ; save registers
	push ecx
	push edx

	cmp al, 3		; is the drive number out of range?
	ja .end			; if yes, simply return

	movzx ecx, al		; copy drive number to ecx

	mov word [floppy_motors+ecx*2], 0  ; make sure the drive's motor cutoff
					   ; timer is disabled

	mov ah, 10h		; create bitmask for MOTX flag in DOR
	shl ah, cl

	mov dx, DOR		; DX = DOR
	in al, dx		; read the DOR

	test al, ah		; is the motor on already?
	jnz .end		; if yes, we're done

	or al, ah		; otherwise, switch it on
	out dx, al		; write DOR

	mov eax, 301		; wait an appropriate delay for the motor to spin up

	cmp byte [floppy_type], 3  ; is it a 3.5" drive?
	jae .3.5_inch		; if yes, 300 ms is enough

	add eax, 200		; otherwise it is a 5.25" drive, wait 500 ms

.3.5_inch:
	call sleep

.end:
	pop edx  ; restore registers
	pop ecx
	pop eax
	ret


; Function:   floppy_motor_off
; Purpose:    to enable a specific drive's motor cutoff timer (if it's motor
;             isn't already shut off). The drive's motor will be switched off
;             after 2 seconds if floppy_motor_on won't be called in this time.
;             If the specified drive number is out of range, the function will
;             simply return.
;             The processor state is preserved (except EFLAGS).
; Parameters: AL [IN] = drive number
floppy_motor_off:
	push eax  ; save register
	push ecx
	push edx

	cmp eax, 3		; drive number <= 3?
	ja .end			; if not, return

	mov ecx, eax		; copy eax to ecx

	mov ax, [floppy_motors+ecx*2]  ; read the drive's cutoff timer value
				       ; this is done first, then it is no problem,
				       ; if an cutoff timer interrupt fires between
				       ; the two tests.
	or ax, ax		; is it 0?
	jnz .end		; if not, the cutoff timer is already enabled, return

	mov ah, 10h		; prepare bitmask for DOR test
	shl ah, cl

	mov dx, DOR		; DX = DOR
	in al, dx		; read DOR
	test al, ah		; is the motor enabled?
	jz .end			; if not, return

	mov word [floppy_motors+ecx*2], 2000  ; otherwise, arm cutoff timer

.end:
	pop edx  ; restore registers
	pop ecx
	pop eax
	ret


; Function:   floppy_motor_cutoff
; Purpose:    to cut off the drive motors after a specific time of beeing idle.
;             This function shall be called every millisecond. This function must
;             be called only once a time and no other floppy function must be
;             called during the execution of this function (that is e.g. disable
;             interrupts). However, this function might be called in a different
;             floppy function.
;             It is fully state preserving (except EFLAGS).
; Parameters: none
floppy_motor_cutoff:
	push eax  ; save registers
	push ecx
	push edx

	test word [floppy_status], 4h  ; motor timers halted?
	jz .end			; if yes, return

	mov ecx, 4		; 4 drives
	mov dx, DOR		; DX = DOR

.loop:
	mov ax, [floppy_motors+ecx*2-2]  ; get timer value
	or ax, ax		; is the timer 0?
	jz .tail		; if yes, continue

	dec ax			; otherwise, decrement timer
	mov [floppy_motors+ecx*2-2], ax  ; set new timer value
	jnz .tail		; if the timer didn't reach zero, continue

	mov ah, 0F7h		; otherwise, shutdown the drive's motor
	rol ah, cl		; prepare bitmask by shifting 0b11110111

	in al, dx		; read the DOR
	and al, ah		; apply bitmask
	out dx, al		; write the DOR

.tail:
	loop .loop, ecx

.end:
	pop edx  ; restore registers
	pop ecx
	pop eax
	ret


; =================
; IRQ 6 interfacing
; =================
; Function:   floppy_IRQ6_handler
; Purpose:    ISR for IRQ6
global floppy_IRQ6_handler
floppy_IRQ6_handler:
	push eax  ; save registers
	push esi

	test word [floppy_status], FD_WAIT_INTERRUPT
	jz .not_expected	; this is an unexpected interrupt

	and word [floppy_status], ~FD_WAIT_INTERRUPT  ; remove wait state

.end:
	mov al, 20h
	out 0x20, al  ; signal EOI

	pop esi  ; restore registers
	pop eax
	iretd

.not_expected:
	inc dword [floppy_error_count]  ; increment error count

	mov esi, .msg_not_expected
	call p_print_string             ; print error information

	jmp .end                        ; return

.msg_not_expected db 'floppy: unexpected IRQ 6', 0x0D, 0x0A, 0

; Function:   floppy_wait_IRQ6
; Purpose:    to wait for an IRQ 6 to occur in a fully processor state preserving
;             way (except EFLAGS).
;             The timeout is not exactly the specified value X, it is between
;             X - 1 ms and X ms. This is due to the nature of the sleep function.
; Parameters: EAX [IN] = timeout in 1/100 seconds or INFINITE
; Returns:    EAX is set to 1 in case of timeout, 0 otherwise.
INFINITE equ -1  ; biggest 32 bit integer
floppy_wait_IRQ6:
	call floppy_wait_IRQ6_start
	call floppy_wait_IRQ6_end
	ret

; Function:   floppy_wait_IRQ6_start
; Purpose:    to start waiting for an IRQ 6 if it is likely that the interrupt
;             will occure before floppy_wait_IRQ6_end is called. MUST be followed
;             by a call to floppy_wait_IRQ6_end.
;             The function is fully processor state preserving (except EFLAGS).
; Parameters: none
floppy_wait_IRQ6_start:
	or dword [floppy_status], FD_WAIT_INTERRUPT
	ret

; Function:   floppy_wait_IRQ6_end
; Purpose:    to wait for an IRQ 6 that happened after floppy_wait_IRQ6_start
;             was called.
;             The timeout is not exactly the specified value X, it is between
;             X - 1 ms and X ms. This is due to the nature of the sleep function.
;             the funciton is fully processor state preserving (except EFLAGS).
; Parameters: EAX [IN] = timeout in milliseconds or INFINITE
; Returns:    EAX is set to 1 in case of timeout, 0 otherwise.
floppy_wait_IRQ6_end:
	cmp eax, INFINITE	; is EAX == INFINITE?
	je .wait_infinite

	push ebx  ; save registers

	mov ebx, eax		; EAX needed for parameters
	mov eax, 1		; wait at least 1 ms, waiting will get in sync
				; first waiting period

.loop:
	test word [floppy_status], FD_WAIT_INTERRUPT  ; did an interrupt already occur?
	jz .finished		; if yes, waiting finished

	or ebx, ebx		; is EBX 0?
	jz .timeout		; if yes, timeout

	call sleep		; otherwise, wait

	dec ebx			; decrement timeout
	jmp .loop

.timeout:
	mov eax, 1		; return with timeout
	jmp .end

.finished:
	xor eax, eax		; timeout didn't exceed
.end:
	pop ebx  ; restore registers
	ret

.wait_infinite:
	test word [floppy_status], FD_WAIT_INTERRUPT  ; test if flag still set
	jnz .wait_infinite	; if yes, wait longer

	xor eax, eax		; no timeout exceeded, because timeout is infinite
	ret

; =========================
; internal helper functions
; =========================
; Function:   floppy_cmd_begin
; Purpose:    to wait until the controller is ready to accept commands and send a
;             command byte.
;             AL, CL (and EFLAGS) are modified
; Parameters: AL [IN] = command byte
; Returns:    CF set in case of failure, cleared in case of success
floppy_cmd_begin:
	push edx  ; save registers

	mov [.param], al		; save AL

	mov cl, 200+1		; timeout
	mov dx, MSR		; DX = MSR

.wait:
	dec cl			; decrement timeout
	jz .error		; return with error if timeout exceeded

	in al, dx		; query MSR
	and al, 0C0h		; is RQM 1, DIO 0?
	cmp al, 80h
	jne .wait		; if not, wait

	mov al, [.param]	; restore AL
	mov dx, FIFO		; DX = FIFO
	out dx, al		; write command byte to port

	clc			; return with success
	jmp .end

.error:
	stc			; return with error

.end:
	pop edx  ; restore registers
	ret

.param db 0

; Function:   floppy_cmd_param
; Purpose:    to wait until the controller requests a parameter byte and write
;             that to the port.
;             AL, CL (and EFLAGS) are modified (AL is actually only modified
;             in case of failure)
; Parameters: AL [IN] = parameter byte
; Returnes:   CF set on error, cleared otherwise
floppy_cmd_param:
	push edx  ; save registers

	mov [.param], al	; save AL

	mov cl, 200+1		; timeout
	mov dx, MSR		; DX = MSR

.loop:
	dec cl			; decrement timeout
	jz .error		; in case of timeout return

	in al, dx		; query MSR
	and al, 0C0h		; RQM must be 1, DIO 0
	cmp al, 80h
	jne .loop		; if not, wait

	mov al, [.param]	; restore AL
	mov dx, FIFO		; DX = FIFO
	out dx, al		; write parameter byte to port

	clc			; return with success
	jmp .end

.error:
	stc			; failed

.end:
	pop edx  ; restore registers
	ret

.param db 0

; Function:   floppy_cmd_end
; Purpose:    to wait until the controller finished processing a command
;             that is after result phase (or execution phase or command phase
;             if the particular command has no result/neither a result nor an
;             execution phase).
;             AL, CL (and EFLAGS) are modified.
; Parameters: none
; Returns:    CF set on error (timeout or wrong state), cleared otherwise
floppy_cmd_end:
	push edx  ; save registers

	mov cl, 200+1		; timeout
	mov dx, MSR		; DX = MSR

.loop:
	dec cl			; decrement timeout
	jz .error		; return in case of timeout

	in al, dx		; query MSR
	and al, 0D0h		; RQM must be 1, DIO 0, BSY 0
	cmp al, 80h
	jne .loop		; if not, wait

	clc			; return with success
	jmp .end

.error:
	stc			; failed

.end:
	pop edx  ; restore registers
	ret

; Function:   floppy_cmd_result
; Purpose:    to wait with timeout until a result byte is available (RQM 1,
;             DIO 1, BSY 1) and read the byte.
;             AL, CL (and EFLAGS) are modified.
; Parameters: none
; Returns:    AL [OUT] = result byte
;             CF set on error (timeout or wrong state), cleared otherwise
floppy_cmd_result:
	push edx  ; save registers

	mov cl, 200+1		; timeout
	mov dx, MSR		; DX = MSR

.loop:
	dec cl			; decrement timeout
	jz .error		; return with error if timeout exceeded

	in al, dx		; query MSR
	and al, 0D0h		; is RQM 1, DIO 1, BSY 1?
	cmp al, 0D0h
	jne .loop		; if not, wait

	mov dx, FIFO		; DX = FIFO
	in al, dx		; read the result byte
	clc			; return with success
	jmp .end

.error:
	stc			; return with error

.end:
	pop edx  ; restore registers
	ret

; Function:   floppy_wait_drive
; Purpose:    to wait for a drive to complete a recalibrate or seek operation
;             with a timeout of at least 4 seconds. This function is fully state
;             preserving (except EFLAGS).
; Parameters: AL [IN] = drive number
; Returns:    CF set on timeout,
;             CF cleared if drive completed seeking/recalibrating in time
floppy_wait_drive:
	push eax  ; save registers
	push ebx
	push ecx
	push edx

	mov bx, 400+1		; timeout: >~4s

	mov cl, al		; copy drive number to cl
	mov ch, 1		; prepare bitmask to compare with MSR
	shl ch, cl		; DRV X BUSY flag

	mov dx, MSR

.wait_for_drive:
	stc			; preset CF (dec won't modify CF)
	dec bx			; decrement timeout
	jz .end			; return with timeout error

	in al, dx		; poll MSR
	test al, ch		; is DRV X BUSY set?
	jz .complete		; if not, recalibration completed

	mov eax, 11		; otherwise, wait at least 10 ms
	call sleep
	jmp .wait_for_drive

.complete:
	clc			; return with success

.end:
	pop edx  ; restore registers
	pop ecx
	pop ebx
	pop eax
	ret

; Function:   floppy_enable_interrupt
; Purpose:    to enable interrupt generation by the controller in a fully
;             processor state preserving way (except EFLAGS).
; Pramaters: none
floppy_enable_interrupt:
	push eax  ; save registers
	push edx

	mov dx, DOR		; DX = DOR
	in al, dx		; read DOR
	or al, 08h		; enable interrupts
	out dx, al		; write DOR

	pop edx  ; restore registers
	pop eax
	ret

; Function:   floppy_disable_interrupt
; Purpose:    to disable interrupt generation by the controller in a fully
;             processor state preserving way (except EFLAGS).
; Parameters: none
floppy_disable_interrupt:
	push eax  ; save registers
	push edx

	mov dx, DOR		; DX = DOR
	in al, dx		; read DOR
	and al, ~08h		; disable interrups
	out dx, al		; write DOR

	pop edx  ; restore registers
	pop eax
	ret

; ==============================
; Debugging functions start here
; ==============================

; Function:   floppy_debug_set
; Purpose:    to set the location of the text video memory where the debug view
;             is written to. The text video buffer which address is given as a
;             parameter must at least hold 10 lines per 80 characters.
;             The processor state isn't modified.
; Parameters: EAX [IN] = text video memory
global floppy_debug_set
floppy_debug_set:
	mov [floppy_debug_location], eax
	ret

; Function:   floppy_debug_update
; Purpose:    to update the debug view at the location set by floppy_debug_set.
;             a location address of 0 is considered as invalid (initialization
;             value), nothing will be done then (like NULL in C). This is to
;             avoid writing to an invalid memory location when floppy_debug_update
;             is called before floppy_debug_set is called.
;             The processor state isn't modified (except EFLAGS).
; Parameters: none
global floppy_debug_update
floppy_debug_update:
	push eax  ; save registers
	push ebx
	push ecx  ; available for sub functions
	push edx  ; available for sub functions
	push esi  ; available for sub functions
	push edi

	mov ebx, [floppy_debug_location]  ; start of debug output
	or ebx, ebx			  ; is EDI 0?
	jz .end				  ; if yes, do nothing

	cld				  ; clear direction flag

	call .do_line0
	call .do_line1
	call .do_dumpreg  ; occupies 3 lines
	call .do_line9

.end:
	pop edi  ; restore registers
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

.do_line0:
	mov edi, ebx  ; line 0
	call .do_MSR
	call .do_resets
	ret

.do_line1:
	lea edi, [ebx+80*2]  ; line 1
	call .do_DOR
	call .do_errors
	ret

.do_line9:
	lea edi, [ebx+9*80*2]; line 9
	call .do_driver_status
	ret

.do_MSR:
	mov esi, .msg_MSR		; MSR message
	call floppy_debug_string

	mov dx, MSR
	in al, dx			; read MSR

	mov cx, 8			; 8 bits
	mov esi, .msg_RQM
	mov dl, 80h			; bitmask

.loop_MSR:
	test al, dl			; bit set?
	call floppy_debug_case_string	; print bit
	shr dl, 1			; shift bitmask
	loop .loop_MSR, cx		; loop

	ret

.do_DOR:
	mov esi, .msg_DOR		; DOR message
	call floppy_debug_string

	mov dx, DOR
	in al, dx			; read DOR

	mov cx, 8			; 8 bits
	mov esi, .msg_MOTD
	mov dl, 80h			; bitmask

.loop_DOR:
	test al, dl			; bit set?
	call floppy_debug_case_string	; print bit
	shr dl, 1			; shift bitmask
	loop .loop_DOR, cx		; loop

	ret

.do_resets:
	mov esi, .msg_resets		; resets message
	call floppy_debug_string

	mov eax, [floppy_reset_count]	; read reset count
	call floppy_debug_dword		; print reset count
	ret

.do_errors:
	mov esi, .msg_errors		; errors message
	call floppy_debug_string

	mov eax, [floppy_error_count]	; read error count
	call floppy_debug_dword		; print error count
	ret

; occupies 3 lines
.do_dumpreg:
	jmp .dumpreg_disabled

	mov ecx, edi			; save destination address
	mov edi, .dumpreg_data		; Dumpreg command result location
	call floppy_cmd_dumpreg		; issue Dumpreg command
	mov edi, ecx			; restore destination address

	or al, al			; is AL 0?
	jnz .dumpreg_error		; if not, print error message

	mov esi, .msg_PCN3		; print PCN values
	mov ecx, 4			; 4 drives

.loop_PCN:
	call floppy_debug_string
	mov al, [.dumpreg_data+ecx-1]	; drive X's PCN
	call floppy_debug_byte
	loop .loop_PCN

	add edi, 13 * 2			; goto next line

	mov esi, .msg_SRT		; SRT message
	call floppy_debug_string

	movzx ax, byte [.dumpreg_data+4]  ; SRT
	ror ax, 4
	call floppy_debug_byte

	mov esi, .msg_HUT		; HUT message
	call floppy_debug_string

	xor al, al			; HUT
	rol ax, 4
	call floppy_debug_byte

	mov esi, .msg_HLT		; HLT message
	call floppy_debug_string

	movzx ax, byte [.dumpreg_data+5]  ; HLT
	ror ax, 1
	call floppy_debug_byte

	mov esi, .msg_ND		; ND bit
	test ah, 80h			; bit set?
	call floppy_debug_case_string	; print bit
					; 30 characters in line now

	mov esi, .msg_EOT		; EOT message
	call floppy_debug_string

	mov al, [.dumpreg_data+6]	; EOT
	call floppy_debug_byte

	mov al, [.dumpreg_data+7]	; more bits

	mov esi, .msg_LOCK		; LOCK flag
	test al, 80h
	call floppy_debug_case_string	; print flag

	mov esi, .msg_D3		; DX bits, GAP, WGATE
	mov dl, 20h			; bitmask
	mov cx, 6			; 6 bits

.loop_dx:
	test al, dl
	call floppy_debug_case_string	; print bit
	shr dl, 1			; shift bitmask
	loop .loop_dx, cx
					; 65 character in line now

	add edi, 15 * 2			; goto next line

	mov al, [.dumpreg_data+8]	; more bits ...

	mov esi, .msg_EIS		; EIS, EFIFO, POLL
	mov dl, 40h			; bitmask
	mov cx, 3			; 3 bits

.loop_eis:
	test al, dl
	call floppy_debug_case_string	; print bit
	shr dl, 1			; shift bitmask
	loop .loop_eis

	mov esi, .msg_FIFOTHR		; FIFOTHR message
	call floppy_debug_string

	and al, 0Fh			; mask upper 4 bits
	call floppy_debug_byte		; print FIFOTHR

	mov esi, .msg_PRETRK		; PRETRK message
	call floppy_debug_string

	mov al, [.dumpreg_data+9]	; PRETRK
	call floppy_debug_byte

	ret

.dumpreg_error:
	mov esi, .msg_dumpreg_error	; print error message
	call floppy_debug_string
	ret

.dumpreg_disabled:
	mov esi, .msg_dumpreg_disabled	; print disabled message
	call floppy_debug_string
	ret

.do_driver_status:
	mov esi, .msg_driver_status	; print message
	call floppy_debug_string

	mov esi, .msg_INT		; INT, COE, SLR, SPR
	mov dx, 0008h			; bitmask
	mov cx, 4			; 4 flags

.loop_driver_status:
	test [floppy_status], dx
	call floppy_debug_case_string	; print flag
	shr dx, 1			; shift bitmask
	loop .loop_driver_status
	ret


.msg_MSR  db 'MSR: ', 0
.msg_RQM  db ' rqm ', 0
.msg_DIO  db ' dio ', 0
.msg_NDMA db 'ndma ', 0
.msg_CB   db ' cb  ', 0
.msg_ACTD db 'actd ', 0
.msg_ACTC db 'actc ', 0
.msg_ACTB db 'actb ', 0
.msg_ACTA db 'acta', 0

.msg_DOR  db 'DOR: ', 0
.msg_MOTD db 'motd ', 0
.msg_MOTC db 'motc ', 0
.msg_MOTB db 'motb ', 0
.msg_MOTA db 'mota ', 0
.msg_DMGT db 'dmgt ', 0
.msg_RST  db ' rst ', 0
.msg_SEL1 db 'sel1 ', 0
.msg_SEL0 db 'sel0', 0

.msg_resets times 18 db ' '
		     db 'resets: ', 0
.msg_errors times 18 db ' '
		     db 'errors: ', 0

.msg_dumpreg_error db 'Dumpreg command failed', 0
.msg_dumpreg_disabled db 'Dumpreg disabled', 0
.msg_PCN3 db 'PCN-Drive 3: ', 0
.msg_PCN2 db ' PCN-Drive 2: ', 0
.msg_PCN1 db ' PCN-Drive 1: ', 0
.msg_PCN0 db ' PCN-Drive 0: ', 0

.msg_SRT  db 'SRT: ', 0
.msg_HUT  db ' HUT: ', 0
.msg_HLT  db ' HLT: ', 0
.msg_ND   db ' nd ', 0
.msg_EOT  db 'EOT: ', 0
.msg_LOCK db ' lock ', 0
.msg_D3   db 'd3 ', 0
.msg_D2   db 'd2 ', 0
.msg_D1   db 'd1 ', 0
.msg_D0   db 'd0 ', 0
.msg_GAP  db 'gap ', 0
.msg_WGATE db 'wgate', 0

.msg_EIS  db 'eis ', 0
.msg_EFIFO db 'efifo ', 0
.msg_POLL db 'poll ', 0
.msg_FIFOTHR db 'FIFOTHR: ', 0
.msg_PRETRK db ' PRETRK: ', 0

.msg_driver_status db 'driver status: ', 0
.msg_INT db 'int ', 0
.msg_COE db 'coe ', 0
.msg_SLR db 'slr ', 0
.msg_spr db 'spr', 0


.dumpreg_data times 10 db 0

; Function:   floppy_debug_string
; Purpose:    to print a string in ESI to EDI, ESI and EDI are updated accordingly.
;             (EFLAGS is modified, too)
; Parameters: ESI [IN] = source
;             EDI [IN] = destination
; returns:    ESI [OUT] = new location in source
;             EDI [OUT] = new location in destination
floppy_debug_string:
	push eax  ; save registers

	mov ah, 09h		; attrib: light blue on black

.loop:
	lodsb
	or al, al		; end of string?
	jz .end

	stosw
	jmp .loop

.end:
	pop eax  ; restore registers
	ret

; Function:   floppy_debug_case_string
; Purpose:    to printe a string with its case converted according the ZF.
;             ZF == 1 means the string is printed all lowercase, ZF == means
;             the string is printed all uppercase. Apart from that it works like
;             floppy_debug_string.
; Parameters: ESI [IN] = source
;             EDI [IN] = destination
;             ZF set: all lowercase, ZF not set: all uppercase
; returns:    ESI [OUT] = new location in source
;             EDI [OUT] = new location in destination
floppy_debug_case_string:
	push eax  ; save registers
	push ebx

	mov ebx, floppy_debug_upper_char  ; assume uppercase
	jnz .loop			  ; if it is uppercase, continue

	mov ebx, floppy_debug_lower_char  ; otherwise, it's lowercase

.loop:
	lodsb
	or al, al		; end of string?
	jz .end

	call ebx
	jmp .loop

.end:
	pop ebx  ; restore registers
	pop eax
	ret

; Function:   floppy_debug_lower_char
; Purpose:    to print a character in lowercase. If it is specified in uppercase,
;             it is converted to lowercase first. EDI is updated to the new
;             position in the destination buffer (after the character) (EFLAGS
;             is modified, too).
; Parameters: EDI [IN] = destination
;              AL [IN] = character to print
; Returns:    EDI [OUT] = new position in destination
floppy_debug_lower_char:
	push eax  ; save registers

	cmp al, 'A'		; >= 'A' ?
	jb .print_char		; if not, nothing to do

	cmp al, 'Z'		; <= 'Z' ?
	ja .print_char		; if not, nothing to do

	add al, 'a' - 'A'	; otherwise, convert to lowercase

.print_char:
	mov ah, 04h		; red on black
	stosw

	pop eax  ; restore registers
	ret

; Function:   floppy_debug_upper_char
; Purpose:    to print a character in uppercase. If it is specified in lowercase,
;             it is converted to uppercase first. EDI is updated to the new
;             position in the destination buffer (after the new character) (EFLAGS
;             is modified, too).
; Parameters: EDI [IN] = destination
;              AL [IN] = character to print
; Returns:    EDI [OUT] = new position in destination
floppy_debug_upper_char:
	push eax  ; save registers

	cmp al, 'a'		; >= 'a' ?
	jb .print_char

	cmp al, 'z'		; <= 'z' ?
	ja .print_char		; if not, nothing to do

	sub al, 'a' - 'A'	; otherwise, convret to uppercase

.print_char:
	mov ah, 02h		; green on black
	stosw

	pop eax  ; restore registers
	ret

; Function:   floppy_debug_case_char
; Purpose:    to print a character in lowercase or uppercase depending of the ZF.
;             If necessary, the character is converted accordingly.
;             EDI is updated to the new position in the destination buffer (after
;             the new character), EFLAGS might be modified.
; Parameter: EDI [IN] = destination
;             AL [IN] = character to print
;            ZF set: lowercase, ZF not set: uppercase
floppy_debug_case_char:
	jz .lower

	call floppy_debug_upper_char
	ret

.lower:
	call floppy_debug_lower_char
	ret

; Function:   floppy_debug_dword
; Purpose:    to print a 32 bit hex value, EDI is updated to the new position in
;             the destination (and EFLAGS might be modified).
; Parameters: EAX [IN] = number to print
;             EDI [IN] = destination
; Returns:    EDI [OUT] = new position in destination
; see:        http://wiki.osdev.org/Real_mode_assembly_II
floppy_debug_dword:
	push eax  ; save registers
	push ebx
	push ecx

	mov ebx, eax		; copy number to EBX

	mov ah, 0Fh		; white on black
	mov al, '0'		; '0x'
	stosw

	mov al, 'x'
	stosw

	mov cx, 8		; 8 digits
	rol ebx, 4		; start with most significant digit

.loop:
	mov al, bl		; copy digit
	and al, 0Fh		; mask digit

	cmp al,10
	sbb al,69h
	das
	stosw

	rol ebx, 4		; next digit
	loop .loop, cx		; loop

.end:
	pop ecx  ; restore registers
	pop ebx
	pop eax
	ret

; Function:   floppy_debug_byte
; Purpose:    to print a 8 bit hex value, EDI is updated to the new position in
;             the destination (and EFLAGS might be modified).
; Parameters: AL  [IN] = byte to print
;             EDI [IN] = destination
; Returns:    EDI [OUT] = new position in destination
; see:        http://wiki.osdev.org/Real_mode_assembly_II
floppy_debug_byte:
	push eax  ; save registers

	xor ah, ah		; this will mask the most significant digit
	ror eax, 4		; start with most significant digit

	cmp al, 10
	sbb al, 69h
	das

	mov ah, 0Fh		; attrib: white on black
	stosw

	rol eax, 4		; least significant digit
	and al, 0Fh		; mask digit

	cmp al, 10
	sbb al, 69h
	das

	mov ah, 0Fh		; attrib: white on black
	stosw

	mov al, 'h'
	stosw			; suffix 'h' for hex

	pop eax  ; restore registers
	ret



floppy_debug_location dd 0


; ---------------------------------------------------
; status word:
FD_WAIT_INTERRUPT equ 8 ; (INT):  this flag is used to wait for an IRQ 6
;     4h: Cut Off Enabled (COE):  if 0, the motor timers will be halted until it is set to 1
;     2h: Select Required (SLR):  the selected drive is invalid (e.g. after reset, initialization)
;     1h: Specify Required (SPR): the next select procedure must send a Specify command
floppy_status dw 0
floppy_reset_count dd 0		; count of performed controller resets
floppy_type db 0		; type of master floppy
floppy_motors times 4 dw 2000	; motor cut off timers for drives
floppy_error_count dd 0		; error counter
floppy_selected_drive db 0	; the currently selected drive
