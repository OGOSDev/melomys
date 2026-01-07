; TODO 7
infomap:
	mov di, 0x5000
	mov rax, [p_ACPITableAddress]	; ACPI table address(8 byte)
	stosq
	mov eax, [p_BSP]		; Bootstrap processor(4 byte)
	stosd

	mov di, 0x5010
	mov ax, [p_cpu_speed]
	stosw
	mov ax, [p_cpu_activated]
	stosw
	mov ax, [p_cpu_detected]
	stosw

	; Run CPUID leaf 0 to get max standard CPUID leaf and store it(4 bytes)
	mov di, 0x5018
	xor eax, eax
	cpuid
	stosd
	; 0x80000000 to get max extended CPUID leaf				
	mov eax, 0x80000000
	cpuid
	stosd			
	cmp eax, 0x80000008		; Checks if extended leaf 0x80000008 exists
	jb no_address_size
	mov eax, 0x80000008
	cpuid
	mov [0x5016], ax		; save virtual/physical address bits
no_address_size:

	mov di, 0x5020
	mov eax, [p_mem_amount]		; Read usable memory amount (MiB),
	and eax, 0xFFFFFFFE		; Clear low bit
	stosd				; Save it 

	; Store IOAPIC count and interrupt source count as bytes. It's needed to initialize IRQ routing
	mov di, 0x5030
	mov al, [p_IOAPICCount]
	stosb
	mov al, [p_IOAPICIntSourceC]
	stosb

	; Store HPET base addr, frequency, min counter and number of timer
	mov di, 0x5040
	mov rax, [p_HPET_Address]
	stosq
	mov eax, [p_HPET_Frequency]
	stosd
	mov ax, [p_HPET_CounterMin]
	stosw
	mov al, [p_HPET_Timers]
	stosb

	; Store local APIC physical address
	mov di, 0x5060
	mov rax, [p_LocalAPICAddress]
	stosq
	jmp done_infomap
