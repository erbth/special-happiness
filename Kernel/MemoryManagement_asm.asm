; Assembly wrappers for disabling interrupts (atomicity)

bits 32
section .text

global MemoryManagement_allocate
MemoryManagement_allocate:
	push ebp
	mov ebp, esp

	; Push EFLAGS and disable interrupts
	pushfd
	cli

	mov eax, [ebp + 8]
	push eax

	; Stack alignment should be fine: 3 push and call
	extern c_MemoryManagement_allocate
	call c_MemoryManagement_allocate

	; Clean stack
	add esp, 4

	; Restore EFLAGS
	popfd

	pop ebp
	ret

global MemoryManagement_free
MemoryManagement_free:
	push ebp
	mov ebp, esp

	; Push EFLAGS and disable interrupts
	pushfd
	cli

	mov eax, [ebp + 8]
	push eax

	; Stack alignment should be fine: 3 push and call
	extern c_MemoryManagement_free
	call c_MemoryManagement_free

	; Clean stack
	add esp, 4

	; Restore EFLAGS
	popfd

	pop ebp
	ret

global MemoryManagement_addRegion
MemoryManagement_addRegion:
	push ebp
	mov ebp, esp

	; Push EFLAGS and disable interrupts
	pushfd
	cli

	; Stack alignment: 4 push and call, 12 bytes missing
	sub esp, 12

	mov eax, [ebp + 12]
	push eax

	mov eax, [ebp + 8]
	push eax

	extern c_MemoryManagement_addRegion
	call c_MemoryManagement_addRegion

	; Clean stack
	add esp, 20

	; Restore EFLAGS
	popfd

	pop ebp
	ret

global MemoryManagement_print
MemoryManagement_print:
	push ebp
	mov ebp, esp

	; Push EFLAGS and disable interrupts
	pushfd
	cli

	; Stack alignment: 2 push and call, 4 bytes missing
	sub esp, 4

	extern c_MemoryManagement_print
	call c_MemoryManagement_print

	; Clean stack
	add esp, 4

	; Restore EFLAGS
	popfd

	pop ebp
	ret
