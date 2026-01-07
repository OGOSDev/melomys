; From baremetal os by Return Infinity

init_smp:
	; Check if we want the AP's to be enabled.. if not then skip to end
	cmp byte [cfg_smpinit], 1	; Compare the configuration flag for SMP initialization with 1 (enabled).
	jne noMP			; If the flag is not set (SMP is disabled), skip the entire initialization routine.

	; Start the AP's one by one
	xor eax, eax			; Clear EAX for general use.
	xor edx, edx			; Clear EDX for general use.
	mov rsi, [p_LocalAPICAddress]	; Load the base memory address of the Local APIC into RSI.
	mov eax, [rsi+0x20]		; Read the APIC ID Register (offset 0x20) value into EAX.
	shr rax, 24			; Shift EAX right by 24 bits to isolate the APIC ID (bits 31:24) into AL.
	mov dl, al			; Store the APIC ID of the Bootstrap Processor (BSP) in DL for comparison.

	mov esi, IM_DetectedCoreIDs	; Set ESI to point to the array containing the APIC IDs of all detected processor cores.
	xor eax, eax			; Clear EAX.
	xor ecx, ecx			; Clear ECX.
	mov cx, [p_cpu_detected]	; Load the total count of detected CPUs into CX (used as the loop counter).

smp_send_INIT:
	cmp cx, 0			; Check if the loop counter has reached zero.
	je smp_send_INIT_done		; If CX is zero, all detected cores have been processed; exit the loop.
	lodsb				; Load the next core's APIC ID from the memory address pointed to by ESI into AL, and increment ESI.

	cmp al, dl			; Compare the current core's APIC ID (AL) with the BSP's APIC ID (DL).
	je smp_send_INIT_skipcore	; If they are the same, skip sending IPIs to the BSP.

	; Send 'INIT' IPI to APIC ID in AL
	mov rdi, [p_LocalAPICAddress]	; Load the base Local APIC address into RDI.
	shl eax, 24			; Shift the target APIC ID (in AL) left by 24 bits to the destination field (bits 31:24).
	mov dword [rdi+0x310], eax	; Write the destination field (APIC ID) to the Interrupt Command Register (ICR) high D-word (offset 0x310).
	mov eax, 0x00004500		; Load the low D-word configuration: INIT Level De-assert (0x4500). Type is INIT (0x5), Level is De-assert (0x1).
	mov dword [rdi+0x300], eax	; Write the command to the ICR low D-word (offset 0x300) to send the INIT IPI.
smp_send_INIT_verify:
	mov eax, [rdi+0x300]		; Read the ICR low D-word to check the command status.
	bt eax, 12			; Test bit 12 (Delivery Status/Send Pending flag).
	jc smp_send_INIT_verify		; If the bit is set (Carry Flag is set), the IPI is still being sent; loop and wait.

smp_send_INIT_skipcore:
	dec cl				; Decrement the core counter.
	jmp smp_send_INIT		; Jump back to the beginning of the loop to process the next core ID.

smp_send_INIT_done:

	; Wait 500 microseconds (APIC specifications require a 10ms delay, but this code uses 500us)
	mov eax, 500			; Set the delay time to 500 microseconds.
	call os_hpet_delay		; Execute the HPET-based delay function.

	mov esi, IM_DetectedCoreIDs	; Reset ESI to point to the start of the detected core IDs list again.
	xor ecx, ecx			; Clear ECX.
	mov cx, [p_cpu_detected]	; Reload the total count of detected CPUs into CX for the next loop.
smp_send_SIPI:
	cmp cx, 0			; Check if the loop counter has reached zero.
	je smp_send_SIPI_done		; If CX is zero, all detected cores have been processed; exit the loop.
	lodsb				; Load the next core's APIC ID into AL, and advance ESI.

	cmp al, dl			; Compare the current core's APIC ID (AL) with the BSP's APIC ID (DL).
	je smp_send_SIPI_skipcore	; If they are the same, skip sending the SIPI to the BSP.

	; Send 'Startup' IPI to destination using vector 0x08 to specify entry-point is at the memory-address 0x00008000
	mov rdi, [p_LocalAPICAddress]	; Load the base Local APIC address into RDI.
	shl eax, 24			; Shift the target APIC ID (in AL) left by 24 bits to the destination field.
	mov dword [rdi+0x310], eax	; Write the destination APIC ID to the ICR high D-word (0x310).
	mov eax, 0x00004608		; Load the low D-word configuration: Startup (0x6), Vector is 0x08. This vector points to the AP's real-mode entry point (0x08 * 0x1000 = 0x8000).
	mov dword [rdi+0x300], eax	; Write the command to the ICR low D-word (0x300) to send the SIPI.
smp_send_SIPI_verify:
	mov eax, [rdi+0x300]		; Read the ICR low D-word to check the command status.
	bt eax, 12			; Test bit 12 (Delivery Status/Send Pending flag).
	jc smp_send_SIPI_verify		; If the IPI is still in transit, loop and wait.

smp_send_SIPI_skipcore:
	dec cl				; Decrement the core counter.
	jmp smp_send_SIPI		; Jump back to process the next core ID.

smp_send_SIPI_done:

	; Wait 10000 microseconds for the AP's to finish
	mov eax, 10000			; Set the delay time to 10 milliseconds (10,000 microseconds) to allow the APs to boot up.
	call os_hpet_delay		; Execute the HPET-based delay.

noMP:
	; Gather and store the APIC ID of the BSP
	xor eax, eax			; Clear EAX.
	mov rsi, [p_LocalAPICAddress]	; Load the Local APIC base address into RSI.
	add rsi, 0x20			; Add the offset for the APIC ID Register (0x20).
	lodsd				; Read the 32-bit APIC ID register value from [RSI] into EAX.
	shr rax, 24			; Shift EAX right by 24 bits to isolate the 8-bit APIC ID into AL.
	mov [p_BSP], eax		; Store the identified BSP APIC ID into the designated variable.

	; Calculate base speed of CPU
	cpuid				; Execute CPUID instruction (used as a serializing instruction before RDTSC).
	xor edx, edx			; Clear EDX.
	xor eax, eax			; Clear EAX.
	rdtsc				; Read the Time Stamp Counter into EDX:EAX (high 32-bits in EDX, low 32-bits in EAX).
	push rax			; Save the low 32 bits of the initial TSC reading onto the stack.
	mov rax, 1024			; Set a delay time of 1024 microseconds (used for measuring the clock rate).
	call os_hpet_delay		; Wait for the specified time using the HPET.
	rdtsc				; Read the Time Stamp Counter again into EDX:EAX.
	pop rdx				; Restore the initial low 32 bits of the TSC reading into RDX.
	sub rax, rdx			; Calculate the difference (number of TSC cycles that elapsed during the delay).
	xor edx, edx			; Clear EDX for the division.
	mov rcx, 1024			; Load the delay time (1024 microseconds) into RCX.
	div rcx				; Divide the cycle count (RAX) by the microsecond count (RCX). The result in AX is the average cycles per microsecond (MHz).
	mov [p_cpu_speed], ax		; Store the calculated CPU speed (in MHz) into the designated variable.

	ret				; Return from the SMP initialization routine.


; =============================================================================
; EOF
