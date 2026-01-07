; ####################################################################################################################################################################
; ####################################################################################################################################################################

; TODO 1: Locate the root system description pointer(RSDP)
; 	* Load the RSDP address from the known UEFI memory slot (0x400830)

; TODO 2: Validate the RSDP Structure
; 	* Verify the 8 byte signature matches 'RSD PTR'
; 	* Calculate the 8bit checksum of the first 20 bytes of the RSDP structure
; 	* Fail if the signature or checksum is invalid

; TODO 3: Determine ACPI version; read and collect all table pointers
; 	* Read the revision byte from the RSDP
; 	* If v10(revision 0), prepare to use the 32 bit root system description table(RSDT)
; 	* If V20+(revision 1+), retrieve the 64-bit extended system description table(XSDT) address
; 	* Set rsi to the start of the RSDT or XSDT structure
; 	* Verify the table signature ('RSDT' or 'XSDT')
; 	* Calculate the number of table entry pointers within the structure
; 	* Iterate through the pointers and push all 64 bit physical addresses onto the stack

; TODO 4: ACPI table identification
; 	* Loop through the collected table addresses popped from the stack
; 	* Read the 4 byte signature of each table
; 	* Dispatch execution based on the signature. eg 'apic' 'hpet' 'MCFG' 'facp')

; TODO 5: Parse MADT(multiple APIC description table)
; 	* find processor local apic and io apic structures
; 	* Store the apic id for each usable cpu
; 	* Store the io apic base address and interrupt source overrides

; TODO 6: Parse HPET (high precision event timer)
; 	* Extract the hpet base address
; 	* Save the main counter min value

; TODO 7: Parse MCFG (PCI express config table)
; 	* Read the base address and bus ranges for pcie configuration space
; 	* Store the records in a reserved memory area 

; TODO 8: Parse FADT (Fixed ACPI description table)
; 	* Retrieve general acpi config flags
; 	* Save the flags

; TODO 9: Disable cache and flush TLB
; 	* Stop using the cpus quick access memory to ensure fresh data
; 	* Flush any old memory location lookups from the translation lookaside buffer(tlb)

; TODO 10: Configure memory access rules (PAT/MTRR) note
; 	* Set up the page attribute table(pat) to define how different memory types behave
; 	* (Optional) Configure and enable memory type range registers (mtrr) for larger memory blocks. note

; TODO 11: Enable FPU and SIMD/vector unit
; 	* activate the coprocessor for floating point math
; 	* Enable powerful vector instruction sets(sse avx avx-512) for high speed processing
; 	* Set the xcr0 register to confirm os support for these extensions

; TODO 12: Configure local APIC (Interrupt controller)
; 	* Enable the local apic globally(via msr)
; 	* Set up the apic to manage local interrupts and inter processor communication (ipi)
; 	* Disable unwanted internal alerts (timer performance error)

; TODO 13: Signal core activation
; 	* Increment the global counter to let the system know this core is active
; 	* Record the core's unique APIC id in the active core list

; TODO 15: Set up exception gate and interrupt gate

; #################################################################################################################################################################
; #################################################################################################################################################################


; TODO 1: Locate the root system description pointer(RSDP)

init_acpi:
	mov rbx, 'RSD PTR '		; Load 8 byte ACPI RSDP(root system description pointer) signature for verification

; It's supposed to be somewhere in the first MiB of memory but some systems don't adhere to that
foundACPIfromUEFI:
	mov rsi, [0x400830]		; Load the 64 bit physical address of rsdp from the boot structure
	lodsq				; Load the 8 byte from rsi to rax - the signature
	cmp rax, rbx			; Verify the signature matches 'rsd ptr'
	jne noACPI			; If not then fail


; TODO 2: Validate the RSDP Structure

foundACPI:				
	push rsi			; Save the current RSDP location for later use
	push rbx			; Save 'RSD ptr'
	xor ebx, ebx			; ebx will be used to calculate the checksum total in bl
	mov ecx, 20			; Set loop counter to check the first 20 bytes of the structure
	sub esi, 8			; Rewind rsi to point to the absolute start
nextchecksum:
	lodsb				; Read one byte and advance the pointer
	add bl, al			; add the byte to the ongoing checksum total
	dec cl				; Decrement the counter
	jnz nextchecksum		; Loop until 20 bytes are checked
	mov al, bl			; Move the final checksum total to al
	pop rbx				; Restore the signature
	pop rsi				; Restore the rsi pointer
	cmp al, 0			; Check if the final checksum value is zero
	jne noACPI			; If the checksum isn't zero, then fail


; TODO 3: Determine ACPI version; read and collect all table pointers

	; Advance past
	lodsb				; the checksum field
	lodsd				; the first 4 bytes of oemid
	lodsw				; the last 2 bytes of oemid
	lodsb				; Read the ACPI revision byte: 0 for v10, 1 for v20+
	cmp al, 0
	je foundACPIv1			; If v10, jump to the 32-bit rsdt parser
	jmp foundACPIv2			; If not, jump to the 64 bit xsdt parser


foundACPIv1:				; Parse the 32 bit RSDT ntructure
	xor eax, eax			; Clear eax before loading the 32-bit address
	lodsd				; Read the 32 bit RSDT address
	mov rsi, rax			; Set rsi to point to the rsdt structure
	lodsd				; Read the rsdt signature
	cmp eax, 'RSDT'			; Verify the signature
	jne novalidacpi			; Fail if invalid
	sub rsi, 4			; Rewind rsi to point to rsdt base addr
	mov [p_ACPITableAddress], rsi	; save the rsdt base address
	add rsi, 4			; Restore rsi to where it were
	xor eax, eax			; Clear eax for table size
	lodsd				; Read the total length of the RSDT
	add rsi, 28			; Skip the rest of the header to the start of the pointer entries
	sub eax, 36			; Calculate the total byte size of the pointer list
	shr eax, 2			; Divide the byte size by 4 to get the count of 32-bit pointers
	mov rdx, rax			; Store the table count in rdx
	xor ecx, ecx			; Clear the entry counter
foundACPIv1_nextentry:
	lodsd				; Read a 32bit table pointer
	push rax			; SAve the pointer(zero extended)
	inc ecx				; Increment the number of entry we processed
	cmp ecx, edx			; check if we processed all tables
	je findACPITables		; If all tables are processed, jump to the finder loop
	jmp foundACPIv1_nextentry	; If not, loop for the next entry

foundACPIv2:				; Parse the 64bit XSDT structure
	lodsd				; Skip the 32bit rsdt address field
	lodsd				; Skip reserved/length field
	lodsq				; Read the 64 bit xsdt address - the preferred table
	mov rsi, rax			; Set rsi to point to the xsdt structure
	lodsd				; Read the XSDT signature
	cmp eax, 'XSDT'			; Verify the signature
	jne novalidacpi			; Fail if invalid
	sub rsi, 4			; Rewind rsi to point to xsdt base addr
	mov [p_ACPITableAddress], rsi	; Save the xsdt base address
	add rsi, 4			; Restore rsi to where it were
	xor eax, eax			; Clear eax for table size
	lodsd				; Read the total length of the xsdt
	add rsi, 28			; Skip the rest of the header to the start of the pointer entries
	sub eax, 36			; Calculate the total byte size of the pointer list
	shr eax, 3			; Divide the byte size by 8 to get the count of 64-bit pointers
	mov rdx, rax			; Store the table count in rdx
	xor ecx, ecx			; Clear the entry counter
foundACPIv2_nextentry:
	lodsq				; Read a 64 bit table pointer
	push rax			; Push the 64 bit pointer ontoo the stack
	inc ecx				; Increment the number of entry we processed
	cmp ecx, edx			; Check if we processed all tables
	jne foundACPIv2_nextentry	; If not, loop for the next entry


; TODO 4: ACPI table identification

findACPITables:
	xor ecx, ecx			; Will be used as a loop counter
nextACPITable:
	cmp ecx, edx			; Compare current table count to entry limit
	je init_smp_acpi_done		; If all entries are processed, exit
	pop rsi				; Restore what we push(from the stack)
	lodsd				; Read the tables 4 byte signature into eax
	inc ecx				; Increment the table counter
	mov ebx, 'APIC'			; Set ebx to the madt signature
	cmp eax, ebx
	je foundAPICTable		; If madt, jump to parse it
	mov ebx, 'HPET'			; Set ebx to the hpet signature
	cmp eax, ebx
	je foundHPETTable		; The same thing but for Hpet
	mov ebx, 'MCFG'	
	cmp eax, ebx
	je foundMCFGTable		; If mcfg
	mov ebx, 'FACP'			
	cmp eax, ebx
	je foundFADTTable		; If fadt
	jmp nextACPITable		; Skip - ignore this table and check the next one


; TODO 5: Parse MADT(multiple APIC description table)

	; Find and store
foundAPICTable:
	call parseAPICTable		; CPU and IO APIC info
	jmp nextACPITable


; TODO 6: Parse HPET (high precision event timer)

foundHPETTable:
	call parseHPETTable		; hpet timer info
	jmp nextACPITable


; TODO 7: Parse MCFG (PCI express config table)

foundMCFGTable:
	call parseMCFGTable		; PCIe base addr
	jmp nextACPITable


; TODO 8: Parse FADT (Fixed ACPI description table)
foundFADTTable:
	call parseFADTTable		; generic acpi flag
	jmp nextACPITable

init_smp_acpi_done:
	ret				; End of the ACPI initialization routine

noACPI:
novalidacpi:
	; Set screen to Teal
	mov rdi, [0x00005F00]		; Get the framebuffer address
	mov rcx, [0x00005F08]		; Get the framebuffer size
	shr rcx, 2			; Convert size from bytes to 32bit pixels
	mov eax, 0x0000FFFF		; Load the teal color
	rep stosd			; Fill the entire screen with teal
	jmp $				; Halt the cpu indefinitely


parseAPICTable:
	push rcx			; Save loop counter
	push rdx			; Save general data register

	lodsd				; Read the length of madt in bytes
	mov ecx, eax			; Store the madt length in ecx
	xor ebx, ebx			; ebx is the total length counter
	; Read
	lodsb				; Revision
	lodsb				; Checksum
	lodsd				; OEMID first 4 bytes
	lodsw				; OEMID last 2 bytes
	lodsq				; OEM table id
	lodsd				; oem revision
	lodsd				; Creator id
	lodsd				; Creator revision
	lodsd				; APIC address
	lodsd				; flags
	add ebx, 44			; Advance the total counter past the header
	mov rdi, 0x0000000000005100	; Set rdi to the memory location for storing valid cpu ids

readAPICstructures:
	cmp ebx, ecx			; Check if the total counter = the table length
	jae parseAPICTable_done		; If 'we have' processed all bytes, exit
	lodsb				; Read the APIC structure type
	cmp al, 0x00			; Check for processor local APIc
	je APICapic
	cmp al, 0x01			; Check for IO APIC
	je APICioapic
	cmp al, 0x02			; Check for interrupt source override
	je APICinterruptsourceoverride

	jmp APICignore			; If the type is unknown, skip it

APICapic:				; Process processor local APIC entry
	xor eax, eax			
	xor edx, edx			
	lodsb				; Read the length of this structure = 8
	add ebx, eax			; Add the structure length to the total counter
	lodsb				; Read ACPI processor id
	lodsb				; Read APIc id
	xchg eax, edx			; save the apic id to edx
	lodsd				; Read flags - bit 0 set if enabled/usaable
	bt eax, 0			; Test the enabled/usable flag
	jnc readAPICstructures		; If not usable,skip and read the next structure
	inc word [p_cpu_detected]	; Increment the count of usable cpus
	xchg eax, edx			; Restore the apic id back to eax
	stosb				; Store the 8 bit APIC id for later use
	jmp readAPICstructures		; Read the next structure

APICioapic:				; Process IO apic entry
	xor eax, eax			; Clear eax
	lodsb				; Read the length of this structure = 12
	add ebx, eax			; Add the structure length to the total counter
	push rdi			; Save rdi and rcx
	push rcx			
	mov rdi, IM_IOAPICAddress	; Set rdi to the base memory location for IO APIC data
	xor ecx, ecx		
	mov cl, [p_IOAPICCount]		; Load the current IO APIC count
	shl cx, 4			; Calculate the offset by multiplying the count by 16
	add rdi, rcx			; Move rdi to the storage spot for this specifc io apic
	pop rcx				; Restore rcx
	xor eax, eax	
	; Read ant store	
	lodsb				; IO APIC id
	stosd				
	lodsb				; Reserved byte
	lodsd				; IO APIc addr
	stosd				
	lodsd				; Global system interrupt base
	stosd				
	pop rdi				; Restore rdi
	inc byte [p_IOAPICCount]	; Increment the count of IO APICs found
	jmp readAPICstructures		; Read the next structure

APICinterruptsourceoverride:		; Process interrupt source override entry
	xor eax, eax			
	lodsb				; Read the length of this structure = 10
	add ebx, eax			; Add the structure length to the total counter
	push rdi			
	push rcx	
	mov rdi, IM_IOAPICIntSource	; Set rdi to the base memory location for interrupt overrides
	xor ecx, ecx			
	mov cl, [p_IOAPICIntSourceC]	; Load the current override count
	shl cx, 3			; Calc the offset by multiplying the count by 8
	add rdi, rcx			; Move rdi to the storage spot for this specific override
	; Read and store
	lodsb				; bus source
	stosb			
	lodsb				; irq source
	stosb				
	lodsd				; global system interrupt
	stosd				
	lodsw				; Read flags - trigger and polarity
	stosw				
	pop rcx			
	pop rdi			
	inc byte [p_IOAPICIntSourceC]	; Increment the count of overrides found
	jmp readAPICstructures		; Read the next structure


APICignore:
	xor eax, eax		
	lodsb				; Read the structure length byte
	add ebx, eax			; Add the length to the total counter
	add rsi, rax			; Advance rsi by the length
	sub rsi, 2			; Correct rsi for the two bytes just read(type and length)
	jmp readAPICstructures		; Read the next structure

parseAPICTable_done:
	pop rdx				
	pop rcx				
	ret				; Return from parseapictable


parseHPETTable:
	; Read 
	lodsd				; The length of hpet table
	lodsb				; revision
	lodsb				; Checksum
	lodsd				; oemid first 4 bytes
	lodsw				; oemid last 2 bytes
	lodsq				; oem table id
	lodsd				; oem revision
	lodsd				; creator id
	lodsd				; creator revision

	lodsb				; hardware revision id
	lodsb				; properties
	lodsw				; pci vendor id
	lodsd				; generic address structure fields
	lodsq				; hpet base address value
	mov [p_HPET_Address], rax	; save the base address of the hpet
	lodsb				; read hpet number
	lodsw				; read main counter minimum
	mov [p_HPET_CounterMin], ax	; snave the main counter minimum
	lodsb				; read page protection and oem attribute
	ret				; ret from parsehpetable


parseMCFGTable:
	push rdi			
	push rcx		
	xor eax, eax			
	xor ecx, ecx			
	mov cx, [p_PCIECount]		; Load the current PCIe record count
	shl ecx, 4			; Calculate the offset for the next record
	mov rdi, IM_PCIE		; Set rdi to the base memory location for pcie records
	add rdi, rcx			; Move rdi to the storage spot for this record
	lodsd				; Read the length of mcfg table
	sub eax, 44			; Subtract the size of the table header
	shr eax, 4			; Divide by 16 to get the number of 16-byte records
	mov ecx, eax			; Store the number of records in ecx
	add word [p_PCIECount], cx	; Add the new record count to the total
	; Read
	lodsb				; revision
	lodsb				; checksum
	lodsd				; oemid first 4 bytes
	lodsw				; oemid last 2 bytes
	lodsq				; oem table id
	lodsd				; oem revision
	lodsd				; creator id
	lodsd				; creator revision
	lodsq				; reserved field

	
parseMCFGTable_next:
	; Read and store
	lodsq				; The base addrss of the enhanced config mechanism
	stosq				
	lodsw				; PCI segment group number
	stosw			
	lodsb				; Start PCI bus number
	stosb				
	lodsb				; End PCI bus number
	stosb				
	lodsd				; Reserved
	stosd			
	dec ecx				; decrement the record counter
	jnz parseMCFGTable_next		; Loop until all records are processed
	xor eax, eax		
	not rax				; Set rax to 0xffffffffffffffff
	stosq				; Mark the end of the table
	stosq				; The same thing	

	pop rcx				
	pop rdi	
	ret				; Return from parsemcfgtable


parseFADTTable:
	sub rsi, 4			; Set rsi back to the start of the fadt structure
	
	mov eax, [rsi+10]		; Check the start of oemid
	cmp eax, 0x48434F42		; Check if oemid is "boch"(virtual machine)
	je parseFADTTable_end		; If so, skip processing
	; Read and save
	mov ax, [rsi+109]		; The iapc boot arch flags
	mov [p_IAPC_BOOT_ARCH], ax


parseFADTTable_end:
	ret				; Return from parsefadttable






; TODO 9: Disable cache and flush TLB

init_cpu:

	mov rax, cr0			; Load the cr0 control register
	btr rax, 29			; Clear the no write thru flag(bit 29)
	bts rax, 30			; Set the cache disable flag (bit 30)
	mov cr0, rax			; Save the updated cr0 value

	wbinvd				; Invalidate and write back all cache entries

	mov rax, cr3			; Load the cr3 register (tlb base)
	mov cr3, rax			; Reloading cr3 flushes the tlb


; TODO 10: Configure memory access rules (PAT/MTRR)

	mov edx, 0x00000105		; Set memory types for pat entries 4 thru 7
	mov eax, 0x00070406		; Set memory types for pat entries 0 thru 3
	mov ecx, IA32_PAT		; Load the pat msr address
	wrmsr				; Write the new pat configuration


	mov rax, cr3			; Load the cr3 register
	mov cr3, rax			; Reloading cr3 flushes the tlb

	wbinvd				; Invalidate and write back all cache entries

	mov rax, cr0			; Load the cr0 register
	btr rax, 29			; Clear the no write thru flag (bit 29)
	btr rax, 30			; Clear the cache disable flag (bit 30)
	mov cr0, rax			; Save the updated cr0 value


; TODO 11: Enable FPU and SIMD/Vector units

	mov rax, cr0			; Load the cr0 register
	bts rax, 1			; Set the monitor co-processor flag (bit 1)
	btr rax, 2			; Clear the emulation flag (bit 2)
	mov cr0, rax			; Save the updated cr0 value

	mov rax, cr4			; Load the cr4 register
	bts rax, 9			; Enable os support for fxsave and fxstor (bit 9)
	bts rax, 10			; Enable os support for simd exceptions (bit 10)
	mov cr4, rax			; Save the updated cr4 value

	finit				; Initialize the floating point unit

	mov eax, 1			; Prepare to get cpuid feature info 1
	cpuid				; Get cpu features
	bt ecx, 28			; Check if avx-1 is supported (bit 28 in ecx)
	jnc avx_not_supported		; Skip avx activation if not supported
avx_supported:
	mov rax, cr4			; Load cr4
	bts rax, 18			; Enable osxsave (bit 18 for xsave support)
	mov cr4, rax			; Save cr4
	xor ecx, ecx			; Prepare to load xcr0
	xgetbv				; Load xcr0 register into edx:eax
	bts rax, 0			; Set x87 enable (bit 0)
	bts rax, 1			; Set sse enable (bit 1)
	bts rax, 2			; Set avx enable (bit 2)
	xsetbv				; Save the updated xcr0 register
avx_not_supported:

	mov eax, 7			; Prepare to get cpuid extended features 7
	xor ecx, ecx			; Set extended features leaf 0
	cpuid				; Get extended cpu features
	bt ebx, 16			; Check if avx-512 is supported (bit 16 in ebx)
	jnc avx512_not_supported
avx512_supported:
	xor ecx, ecx			; Prepare to load xcr0
	xgetbv				; Load xcr0 register
	bts rax, 5			; Set opmask (bit 5)
	bts rax, 6			; Set zmm_hi256 (bit 6)
	bts rax, 7			; Set hi16_zmm (bit 7)
	xsetbv				; Save the updated xcr0 register
avx512_not_supported:


; TODO 12: Configure local APIC (Interrupt Controller)
	mov ecx, APIC_TPR		; Task priority register
	mov eax, 0x00000020
	call apic_write			; Disable softint delivery
	mov ecx, APIC_LVT_TMR		; Timer lvt
	mov eax, 0x00010000
	call apic_write			; Disable timer interrupts
	mov ecx, APIC_LVT_PERF		; Performance counter lvt
	mov eax, 0x00010000
	call apic_write			; Disable performance counter interrupts
	mov ecx, APIC_LDR		; Logical destination register
	xor eax, eax
	call apic_write			; Set logical destination register
	mov ecx, APIC_DFR		; Destination format register
	not eax				; Set eax to 0xffffffff for flat mode
	call apic_write			; Set destination format register
	mov ecx, APIC_LVT_LINT0		; External interrupt 0 lvt
	mov eax, 0x00008700
	call apic_write			; Enable normal external interrupts
	mov ecx, APIC_LVT_LINT1		; External interrupt 1 lvt
	mov eax, 0x00000400
	call apic_write			; Enable normal nmi processing
	mov ecx, APIC_LVT_ERR		; Error lvt
	mov eax, 0x00010000
	call apic_write			; Disable error interrupts
	mov ecx, APIC_SPURIOUS		; Spurious interrupt vector register
	mov eax, 0x000001FF
	call apic_write			; Enable the apic (bit 8) and set spurious vector

; TODO 13: Signal core activation
	lock inc word [p_cpu_activated]	; Atomically increment the total active cpu count
	mov ecx, APIC_ID			; Apic id register
	call apic_read			; Read the cpu's apic id
	shr eax, 24			; Shift the apic id to the al register
	mov rdi, IM_ActivedCoreIDs	; Target memory location for core activation flags
	add rdi, rax			; Rdi points to the correct spot for this apic id
	mov al, 1			; Load the active status flag
	stosb				; Store a 1 as the core is activated

	ret

apic_read:
	mov rax, [p_LocalAPICAddress]	; Get the base physical address of the local apic
	mov eax, [rax + rcx]		; Read the 32-bit register value
	ret				; Return the value in eax

apic_write:
	push rcx			; Save the rcx register
	add rcx, [p_LocalAPICAddress]	; Calculate the target memory address
	mov [rcx], eax			; Write the value from eax to the apic register
	pop rcx				; Restore the rcx register
	ret				; Return


APIC_ID		equ 0x020
APIC_VER	equ 0x030

APIC_TPR	equ 0x080
APIC_APR	equ 0x090
APIC_PPR	equ 0x0A0
APIC_EOI	equ 0x0B0
APIC_RRD	equ 0x0C0
APIC_LDR	equ 0x0D0
APIC_DFR	equ 0x0E0
APIC_SPURIOUS	equ 0x0F0
APIC_ISR	equ 0x100
APIC_TMR	equ 0x180
APIC_IRR	equ 0x200
APIC_ESR	equ 0x280

APIC_ICRL	equ 0x300
APIC_ICRH	equ 0x310
APIC_LVT_TMR	equ 0x320
APIC_LVT_TSR	equ 0x330
APIC_LVT_PERF	equ 0x340
APIC_LVT_LINT0	equ 0x350
APIC_LVT_LINT1	equ 0x360
APIC_LVT_ERR	equ 0x370
APIC_TMRINITCNT	equ 0x380
APIC_TMRCURRCNT	equ 0x390

APIC_TMRDIV	equ 0x3E0


IA32_APIC_BASE		equ 0x01B
IA32_MTRRCAP		equ 0x0FE
IA32_MISC_ENABLE	equ 0x1A0
IA32_MTRR_PHYSBASE0	equ 0x200
IA32_MTRR_PHYSMASK0	equ 0x201
IA32_MTRR_PHYSBASE1	equ 0x202
IA32_MTRR_PHYSMASK1	equ 0x203
IA32_PAT		equ 0x277
IA32_MTRR_DEF_TYPE	equ 0x2FF




init_hpet:
	; Verify there is a valid HPET address
	mov rax, [p_HPET_Address]	; Retrieve the memory mapped address of the hpet registers into rax
	cmp rax, 0			; check to indicat an invalid or missing hpet
	jz os_hpet_init_error		; If the addr is invalid, jump to the error handling

	; Verify the capabilities of hpet
	mov ecx, HPET_GEN_CAP		; Set ECX to the offset of the general capabilities and id register
	call os_hpet_read		; read the 64 bit value from the hpet register specified by ecx into rcx
	mov rbx, rax			; Copy the entire capabilities register vaaule for processing
	shr ebx, 8			; move the NUM_TIM_CAP field to the lowest bits
	and ebx, 11111b			; Mask rbx to isolate the lower 5 bits which contain the number of exposed timers-1
	inc bl				; Increment the resulting num to get the actual total count of available hpet timers
	mov [p_HPET_Timers], bl		; Store the calculated total number of hpet timers
	shr rax, 32			; Shift rax right by 32 bits to move the COUNTER_CLK_PERIOD field into eax

	; Verify the counter clock period is valid
	cmp eax, 0x05F5E100		; Check if the clock period is greater than the max allowed value(100,000,000fs)
	ja os_hpet_init_error		; If the period is too large => the timer frequency is too low so jump to error
	cmp eax, 0			; check if the clock period is 0
	je os_hpet_init_error		; A zero period = infinite frequency, which is invalid

	; Calculate the HPET frequency
	mov rbx, rax			; Copy the HPET clock period for the division operation
	xor rdx, rdx			; For the 64 bit division
	mov rax, 1000000000000000	; Load 10^15 which is the number of femtoseconds in one second
	div rbx				; Divide 10^15 by rbx. result = HPET frequency in Hz
	mov [p_HPET_Frequency], eax	; save the calculated HPET frequency(hz) into the designated memory location

	; Disable interrupts on all timers
	xor ebx, ebx			; For using it as a counter
	mov bl, [p_HPET_Timers]		; used for the loop count
	mov ecx, 0xE0			; Initialize ecx with an offset that is 0x20 bytes *before* the first timer's configuration register(0x100)
os_hpet_init_disable_int:
	add ecx, 0x20			; Advance ecx to the next timers config register offset => timer 'N' is at 0x100 + N*0x20, 'yeahh, I'm not in the mood(rm)'
	call os_hpet_read		; Read the current 64 bit configuration value for the current timer into rax
	btc ax, 2			; Toggle (clear) bit 2 (INT_ENB_CNF), ensuring interrupts for the timer are disabled
	btc ax, 3			; Toggle (clear) bit 3 (TYPE_CNF), ensuring the timer is configured for one shot mode
	call os_hpet_write		; write the modified configuration value back to the HPET timer register to apply the disable
	dec bl				; decrement the timer counter
	jnz os_hpet_init_disable_int	; Loop back to process the next timer, if BL is not zero

	; clear the main counter before it is enabled
	mov ecx, HPET_MAIN_COUNTER	; Set ecx to the offset of the main 64bit counter register(0x0F0)
	xor eax, eax			
	call os_hpet_write		; Write zero to the main counter, resetting it before activatioon

	; Enable hpet main counter 
	mov eax, 1			; Which sets the ENABLE_CNF bit or bit 0 to activate the HPET
	mov ecx, HPET_GEN_CONF		; Set ecx to the offset of the general config registear(0x010)
	call os_hpet_write		; Write the Value to the configuration register, starting the main counter

os_hpet_init_error:
	ret				


os_hpet_read:
	mov rax, [p_HPET_Address]	; Load the base physical mem addr of the HPET registers into rax
	mov rax, [rax + rcx]		; Read the 64bit value from the calculated physical address = (base + register offset)
	ret				; Return to the calling function


os_hpet_write:
	push rcx			; Save it
	add rcx, [p_HPET_Address]	; Calculate the final physical addr: base address + register offset = rcx
	mov [rcx], rax			; Write the 64 bit value to the computed HPET physical memmapped register addr
	pop rcx				; Restore the original register offset value into rcx from the stack
	ret				; Return to the calling function


os_hpet_delay:
	; Save all in stack
	push rdx			; in os_hpet_read
	push rcx			; In os_hpet_read and div operations
	push rbx			; Target time/cycles
	push rax			; The input delay time in microseconds

	mov rbx, rax			; Copy the requested delay time in microseconds
	xor edx, edx			
	xor ecx, ecx			

	call os_hpet_read		; Read the HPET general capabilities and id register
					; rax now holds the capabilities register value
	shr rax, 32			; To isolate the counter clock period into the lower 32 bits
	mov rcx, rax			


	mov rax, 1000000000		; Load 10^9, note: ???
	div rcx				; 10^9/period, which is equivalent to ticks per microsecond

	mul rbx				; Multiply ticks per microsecond by target delay in microseconds
					; Its the total number of HPET cycles to wait
	mov rbx, rax			; Move the required total cycle count into rbx

	mov ecx, HPET_MAIN_COUNTER	; Set ecx to the offset of the main 64 bit counter reg
	call os_hpet_read		; Read the current value of the hpet main counter into RAX.

	add rbx, rax			; cycles to wait + current counter value
os_hpet_delay_loop:			; Start of the busy wait loop
	mov ecx, HPET_MAIN_COUNTER	; Set ecx again to the main counter offset
	call os_hpet_read		
	cmp rax, rbx			
	jae os_hpet_delay_end		; If current counter >= the target, the delay is finished
	jmp os_hpet_delay_loop		; If the counter hasnt reached the target continue looping and checking
os_hpet_delay_end:

	; Restore the next 4 reg from the stack
	pop rax				
	pop rbx				
	pop rcx				
	pop rdx			
	ret		


; Reg list
HPET_GEN_CAP		equ 0x000 ; Contains the Counter Clock Period, legacy replacement capabiliities and the num of timers
; 0x008 - 0x00F are reserved
HPET_GEN_CONF		equ 0x010 ; Contains the 'main' hpet enable bit and legacy replacement rroute enable
; 0x018 - 0x01F are reserved
HPET_GEN_INT_STATUS	equ 0x020 ; Shows which timers have asserted an interrupt
; 0x028 - 0x0EF are reserved
HPET_MAIN_COUNTER	equ 0x0F0 ; A counter that ticks at the HPET frequency
; 0x0F8 - 0x0FF are res
HPET_TIMER_0_CONF	equ 0x100 ; Used to set the mode, interrupt capabilities etc.
HPET_TIMER_0_COMP	equ 0x108 ; Used to set the value that triggers an event when the main counter equals it
HPET_TIMER_0_INT	equ 0x110 ; Used to configure the interrupt delivery method
; 0x118 - 0x11F are res
HPET_TIMER_1_CONF	equ 0x120
HPET_TIMER_1_COMP	equ 0x128
HPET_TIMER_1_INT	equ 0x130
; 0x138 -0x13F are res
HPET_TIMER_2_CONF	equ 0x140
HPET_TIMER_2_COMP	equ 0x148
HPET_TIMER_2_INT	equ 0x150
; 0x158 - 0x15F are res
; 0x160 - 0x3FF are res


; TODO 14: Set up exception-gate and interrupt gate

; Defualt exception hadler
exception_gate:
exception_gate_halt:
	cli				
	hlt				; Put the cpu into a halted state
	jmp exception_gate_halt		; If an NMI wakes us, just halt again


; Default interrupt handler
interrupt_gate:				; this is the basic handler for all non-exception interrupts
	iretq				; Return from the interrupt, restoring the execution context


; Spurious interrupt
align 16
spurious:				; Handler for spurious interrupts
	iretq				


; CPU Exception Gates

exception_gate_00:
	mov al, 0x00			; Load the interrupt number for divide by zero error
	jmp exception_gate_main		; Proceed to the generic error handler

exception_gate_01:
	mov al, 0x01			; load interrupt number for debug exception
	jmp exception_gate_main

exception_gate_02:
	mov al, 0x02			; Load interrupt number for non-maskable interrupt
	jmp exception_gate_main

exception_gate_03:
	mov al, 0x03			; For breakpoint
	jmp exception_gate_main

exception_gate_04:
	mov al, 0x04			; For overflow
	jmp exception_gate_main

exception_gate_05:
	mov al, 0x05			; for bound range exceeded
	jmp exception_gate_main

exception_gate_06:
	mov al, 0x06			; for invalid opcode
	jmp exception_gate_main

exception_gate_07:
	mov al, 0x07			; for device not available(or math error)
	jmp exception_gate_main

exception_gate_08:
	mov al, 0x08			; double fault
	jmp exception_gate_main

exception_gate_09:
	mov al, 0x09			; coprocessor segment overrun
	jmp exception_gate_main

exception_gate_10:
	mov al, 0x0A			; invalid TSS
	jmp exception_gate_main

exception_gate_11:
	mov al, 0x0B			; Segment not present
	jmp exception_gate_main

exception_gate_12:
	mov al, 0x0C			; stack segment fault
	jmp exception_gate_main

exception_gate_13:
	mov al, 0x0D			; general protection fault
	jmp exception_gate_main

exception_gate_14:
	mov al, 0x0E			; Page fault
	jmp exception_gate_main

exception_gate_15:
	mov al, 0x0F			; Reserved slot
	jmp exception_gate_main

exception_gate_16:
	mov al, 0x10			; Floating point exception
	jmp exception_gate_main

exception_gate_17:
	mov al, 0x11			; Alignment check
	jmp exception_gate_main

exception_gate_18:
	mov al, 0x12			; machine check exception
	jmp exception_gate_main

exception_gate_19:
	mov al, 0x13			; SIMD floating point exception
	jmp exception_gate_main

exception_gate_20:
	mov al, 0x14			; virtualization exception
	jmp exception_gate_main

exception_gate_21:
	mov al, 0x15			; control protection exception
	jmp exception_gate_main

exception_gate_main:
	; Set screen to Red
	mov rdi, [0x00005F00]		; Get the physical base addr of the frame buffer
	mov rcx, [0x00005F08]		; Read the total screen size in bytes
	shr rcx, 2			; Divide by 2^2 to get the number of dwords(pixels)
	mov eax, 0x00FF0000		; load the color red (0x00RRGGBB format)
	rep stosd			; fill the entire screen buffer with the red color
exception_gate_main_hang:
	hlt				
	jmp exception_gate_main_hang	; User must reset machine atp


create_gate:
	; Save both gate number and handler addr in the stack
	push rdi		
	push rax			

	shl rdi, 4			; Multiply the gate number by 4^2 to find its offset in the IDT table
	stosw				; Store the low word of the handler address
	shr rax, 16			; Shift the next 16 bits of the address into the low word
	add rdi, 4			; Move past the gate marker field
	stosw				; store the middle word
	shr rax, 16			; Prepare the final 32 bits
	stosd				; Store the high dword to complete the gate address registration
	
	; Restore
	pop rax				
	pop rdi				
	ret				; ret to caller
