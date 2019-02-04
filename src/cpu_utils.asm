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

; Function:   rdmsr64
; Purpose:    to read a 64 bit model specific register. If a 32 bit one is
;             read, the upper 32 bit are undefined, like all unimplemented
;             bits of MSRs.
; Parameters: uint32_t register address
; CC:         cdecl
	global rdmsr64
rdmsr64:
	; EAX, ECX, EDX are caller saved.
	mov ecx, [esp + 4]
	rdmsr
	ret

; Function:   rdmsr32
; Purpose:    to read a 32 bit wide MSR
; Parameters: uint32_t register address
; CC:         cdecl
	global rdmsr32
rdmsr32:
	mov ecx, [esp + 4]
	rdmsr
	ret

; Function:   wrmsr64
; Purpose:    to write a MSR
; Parameters: uint32_t register index, uint64_t value
; CC:         cdecl
	global wrmsr64
wrmsr64:
	mov ecx, [esp + 4]
	mov eax, [esp + 8]
	mov edx, [esp + 12]
	wrmsr
	ret


; Function:   read_tsc
; Purpose:    to read the TSC using rdtsc
; Parameters: None
; CC:         cdecl
	global read_tsc
read_tsc:
	rdtsc
	ret
