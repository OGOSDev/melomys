; =============================================================================
; Pure64 -- a 64-bit OS/software loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; INIT SMP AP
; =============================================================================


BITS 16

init_smp_ap:

	; Check boot method of BSP
	; Enable the A20 gate
skip_a20_ap:

	; At this point we are done with real mode and BIOS interrupts. Jump to 32-bit mode.
	lgdt [cs:GDTR32]		; Load the 32-bit Global Descriptor Table (GDT) register to prepare for protected mode.

	mov eax, cr0 			; Read the Machine Control Register (CR0) into EAX.
	or al, 1			; Set the Protection Enable (PE) bit (bit 0) to enter 32-bit protected mode.
	mov cr0, eax			; Write the modified value back to CR0 to activate protected mode.

	jmp 8:startap32			; Jump to the 32-bit code segment (selector 8) and begin execution at the startap32 label.

align 16


; =============================================================================
; 32-bit mode
BITS 32

startap32:
	mov eax, 16			; Load the selector for the 4 GB data descriptor (0x10) into EAX.
	mov ds, ax			; Set the Data Segment (DS) register.
	mov es, ax			; Set the Extra Segment (ES) register.
	mov fs, ax			; Set the F Segment (FS) register.
	mov gs, ax			; Set the G Segment (GS) register.
	mov ss, ax			; Set the Stack Segment (SS) register to use the new data segment.
	xor eax, eax			; Clear EAX.
	xor ebx, ebx			; Clear EBX.
	xor ecx, ecx			; Clear ECX.
	xor edx, edx			; Clear EDX.
	xor esi, esi			; Clear ESI.
	xor edi, edi			; Clear EDI.
	xor ebp, ebp			; Clear EBP (Base Pointer).
	mov esp, 0x7000			; Set a temporary stack pointer at a known safe memory location (0x7000) for shared use by all APs during this phase.

	; Load the GDT
	lgdt [GDTR64]			; Load the 64-bit Global Descriptor Table Register, which is required for 64-bit mode.

	; Enable extended properties
	mov eax, cr4			; Read the Control Register 4 (CR4) into EAX.
	or eax, 0x0000000B0		; Set PGE (Paging Global Enable, Bit 7), PAE (Physical Address Extension, Bit 5), and PSE (Page Size Extension, Bit 4). PAE is critical for long mode.
	mov cr4, eax			; Write the modified value back to CR4.

	; Point cr3 at PML4
	mov eax, 0x00002008		; Load the address of the Page Map Level 4 (PML4) table, with the Write-Through bit (Bit 3) set.
	mov cr3, eax			; Write the PML4 address into CR3 (Page-Level Base Register).

	; Enable long mode and SYSCALL/SYSRET
	mov ecx, 0xC0000080		; Load the Extended Feature Enable Register (EFER) MSR number into ECX.
	rdmsr				; Read the Model Specific Register (MSR) specified by ECX into EDX:EAX.
	or eax, 0x00000101 		; Set the LME (Long Mode Enable, Bit 8) and SCE (SYSCALL/SYSRET Enable, Bit 0) bits.
	wrmsr				; Write the modified value from EDX:EAX back to the EFER MSR.

	; Enable paging to activate long mode
	mov eax, cr0			; Read the Machine Control Register (CR0) into EAX.
	or eax, 0x80000000		; Set the Paging Enable (PG) bit (Bit 31) to activate paging.
	mov cr0, eax			; Write the modified value back to CR0, completing the transition to 64-bit long mode.

	; Make the jump directly from 16-bit real mode to 64-bit long mode
	jmp SYS64_CODE_SEL:startap64	; Far jump to the 64-bit code segment (SYS64_CODE_SEL) and begin execution at the startap64 label.

align 16


; =============================================================================
; 64-bit mode
BITS 64

startap64:
	xor eax, eax			; Clear EAX (and RAX) (r0 is often used for arguments).
	xor ebx, ebx			; Clear EBX (and RBX) (r3 is often used for arguments).
	xor ecx, ecx			; Clear ECX (and RCX) (r1 is often used for arguments).
	xor edx, edx			; Clear EDX (and RDX) (r2 is often used for arguments).
	xor esi, esi			; Clear ESI (and RSI) (r6 is often used for arguments).
	xor edi, edi			; Clear EDI (and RDI) (r7 is often used for arguments).
	xor ebp, ebp			; Clear EBP (and RBP) (r5 is often used for arguments).
	xor esp, esp			; Clear ESP (and RSP) to a known zero state before setting the proper stack.

	xor r8, r8			; Clear R8.
	xor r9, r9			; Clear R9.
	xor r10, r10			; Clear R10.
	xor r11, r11			; Clear R11.
	xor r12, r12			; Clear R12.
	xor r13, r13			; Clear R13.
	xor r14, r14			; Clear R14.
	xor r15, r15			; Clear R15.

	mov ax, 0x10			; Load the data segment selector (0x10).

	;
	; Todo: Determine if this clear operation is necessary in 64-bit long mode for legacy registers.
	;
	mov ds, ax			; Set the Data Segment (DS) register.
	mov es, ax			; Set the Extra Segment (ES) register.
	mov ss, ax			; Set the Stack Segment (SS) register.
	mov fs, ax			; Set the F Segment (FS) register.
	mov gs, ax			; Set the G Segment (GS) register.

	; Reset the stack. Each CPU gets a 1024-byte unique stack location
	mov rsi, [p_LocalAPICAddress]	; Retrieve the Local APIC base address into RSI.
	add rsi, 0x20			; Add the offset for the APIC ID Register (0x20).
	lodsd				; Load the 32-bit APIC ID register value into EAX.
	shr rax, 24			; Shift EAX right by 24 bits to isolate the 8-bit APIC ID into AL.
	shl rax, 10			; Multiply the APIC ID by 1024 (2^10) to calculate the unique stack offset.
	add rax, 0x0000000000090000	; Add the base address of the dedicated stack memory region (0x90000) to the offset.
	mov rsp, rax			; Set the Stack Pointer (RSP) to the top of the CPU's unique, dedicated 1KB stack space.

	lgdt [GDTR64]			; Load the 64-bit Global Descriptor Table Register (GDT) once more in 64-bit mode.
	lidt [IDTR64]			; Load the 64-bit Interrupt Descriptor Table Register (IDT) for interrupt handling.

	call init_cpu			; Call the routine to perform remaining CPU-specific initialization tasks (e.g., Local APIC setup).

	sti				; Set the Interrupt Flag (IF) to activate external hardware interrupts for the AP.
	jmp ap_sleep			; Jump into the main sleeping loop for the Application Processor.

align 16

ap_sleep:
	hlt				; Halt the CPU: Suspend execution until an external interrupt (or NMI/reset) is received.
	jmp ap_sleep			; Jump back to the halt instruction, ensuring the processor remains in a waiting state even after an NMI.


; =============================================================================
; EOF
