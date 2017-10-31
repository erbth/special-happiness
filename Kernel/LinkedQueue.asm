; Implementation of a queue using a linked list
; The enqueue, dequeue and getSize operations are atomar in respect to
; interrupts.
;
; Assembly language wrapper functions to achieve interrupt aware atomicity

bits 32
section .text

global LinkedQueue_enqueue
LinkedQueue_enqueue:
	push ebp
	mov ebp, esp

	pushfd			; Preserve IF
	cli				; Disable interrupts

	sub esp, 12		; 4 pushs and a call -- maintain stack alignment

	push dword [ebp + 12]	; 2nd parameter
	push dword [ebp + 8]	; 1st parameter

	extern c_LinkedQueue_enqueue
	call c_LinkedQueue_enqueue

	add esp, 20		; Clean up stack

	popfd			; Restore IF state
	pop ebp
	ret

global LinkedQueue_dequeue
LinkedQueue_dequeue:
	push ebp
	mov ebp, esp

	pushfd			; Preserve IF state
	cli				; Disable interrupts

	; 3 pushs and a call -- Stack alignment should be fine.

	push dword [ebp + 8]

	extern c_LinkedQueue_dequeue
	call c_LinkedQueue_dequeue

	add esp, 4		; Clean stack

	popfd			; Restore IF state
	pop ebp
	ret

global LinkedQueue_getSize
LinkedQueue_getSize:
	push ebp
	mov ebp, esp

	pushfd			; Preserve IF state
	cli				; Disable interrupts

	; 3 pushs and a call -- Stack should be aligned.

	push dword [ebp + 8]

	extern c_LinkedQueue_getSize
	call c_LinkedQueue_getSize

	add esp, 4		; Clean stack

	popfd			; Restore IF state
	pop ebp
	ret
