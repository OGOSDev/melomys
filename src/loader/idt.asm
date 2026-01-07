; TODO 3
       mov rcx, 32			; This whole loop builds IDT entries 0-31
make_exception_gates: 			; make gates for exception handlers
	mov rax, exception_gate		; Each entry will be pointing to the same stub(exception_gate)
	push rax			; Save the hadler address
	stosw				; Write the low 16-bit handler address into IDT entry
	mov ax, SYS64_CODE_SEL		; Use the kernel code segment selectior
	stosw				; Write the segment selector into IDT entry
	mov ax, 0x8E00			; An attribution for 64-bit interrupt gate(present, ring 0)
	stosw				; Write the flag for IDT entry
	pop rax				; restore the full header address - rax = exception_gate
	shr rax, 16
	stosw				; Write the middle 16-bit of handler address
	shr rax, 16
	stosd				; Write the upper 32-bit of hadler address
	xor rax, rax
	stosd				; Write the final reserved 4-byte(must be zero)
	dec rcx
	jnz make_exception_gates

	mov rcx, 256-32			; Now build the remaining 224 entries
make_interrupt_gates: 	
	; Everything is the same, but for Generic
	mov rax, interrupt_gate		; Generic interrupt gate (not exception gate)
	push rax			
	stosw			
	mov ax, SYS64_CODE_SEL
	stosw				
	mov ax, 0x8F00			; Interrupt gate using IST1(the lowest bit set) - so the interrupt can run on clean known stack
	stosw				
	pop rax			
	shr rax, 16
	stosw			
	shr rax, 16
	stosd			
	xor eax, eax
	stosd		
	dec rcx
	jnz make_interrupt_gates

	; Overwrite the low 16 bits of the handler address for a specific exception, so those exceptions call their real handler instead of the generic one
	%macro EG 2
    		mov word [%1*16], exception_gate_%2
	%endmacro
	
	EG 0, 00
	EG 1, 01
	EG 2, 02
	EG 3, 03
	EG 4, 04
	EG 5, 05
	EG 6, 06
	EG 7, 07
	EG 8, 08
	EG 9, 09
	EG 10, 10
	EG 11, 11
	EG 12, 12
	EG 13, 13
	EG 14, 14
	EG 15, 15
	EG 16, 16
	EG 17, 17
	EG 18, 18
	EG 19, 19
	EG 20, 20
	EG 21, 21



	lidt [IDTR64]			; Load the new IDT we just built
