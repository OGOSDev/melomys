; TODO 2
; Load the GDT
	lgdt [GDTR64]			; Loads the segmentation table

	; give CR3 the physical address of the PML4 (0x2000), with write through caching enabled (bit 3). It’s picking where paging tables live
	mov rax, 0x00002008		; Write-thru enabled (Bit 3)
	mov cr3, rax

	; Zeroing every registers
	xor eax, eax			
	xor ebx, ebx		
	xor ecx, ecx	
	xor edx, edx		
	xor esi, esi	
	xor edi, edi			
	xor ebp, ebp		
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15
	mov esp, 0x8000			; now stack pointer points to 0x8000

	; In long-mode it mostly ignores segmentation except cs and ss, but we're zeroing all just incase
	mov ax, 0x10		
	mov ds, ax
	mov es, ax
	mov ss, ax			
	mov fs, ax
	mov gs, ax


	; change CS to the 64bit code segment by doing a far return
	push SYS64_CODE_SEL
	push clearcs
	retfq				; Far return in 64-bit mode
clearcs:

	lgdt [GDTR64]			; now since cs is changed, we have to reload the GDT again
