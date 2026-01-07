; ####################################################################################################################################################################
; ####################################################################################################################################################################

; TODO 1: Entry and Initial Setup
;   	* Define bootstrap processor entry point  and Application processor startup
; 	* Clear the screen

; TODO 2: GDT and Paging Structure Setup
;   	* Copy the 64bit GDT to its final location(0x1000)
;   	* Create the PML4 table entries (0x2000)
;   	* Check for 1 GiB page support
;   	* if 1 GB pages not supported -> 2 MiB path:
;      		 * Create low PDPTE entries(16 GiB coverage)
;      		 * Create Low PDE entries (8192 entries for 16 GiB identity mapping).
;   	* If supported;
;      		 * Overwrite PML4 entries
;                * Create Low PDPTE entries(8191 entries for identity mapping)
; 	Note: the page tables created here are later optimized for the framebuffer in TODO 9
;   	* Load GDT
;  	* Set all segment registers to a valid 64 bit data selector(0x10)
;   	* jump to 64-bit code segment (CS change).
;   	* Reload GDT

; TODO 3: Interrupt descriptor table setup
;   	* Build the IDT table starting at 0x0
;   	* Create entries for CPU exceptions and generic interrupts
;   	* Load IDT
;   	* Make a route for application processes

; TODO 4: Process mem map 
;   	* 1st:  Filter out only the usable memory
;   	* 2nd: Purge small entries(<3MIB) from the usable map
;   	* 3rd: Round up physical addr to the next 2 MiB boundary
;   	* Store total usable memory amount

; TODO 5: High half paging and APIC initialization
;   	* Build high PDPT or PDPTE entries based on total usable memory size
;   	* Create high PDE entries for all usable memory ranges (2 MiB pages)
;   	* Enable Local APIC
;   	* Check for x2APIC support

; TODO 6: Hardware/CPU configuration
;   * Call init_acpi - fiind and process ACPI tables
;   * Call init_cpu  - configure BSP CPU features
;   * Call init_hpet - configure the HPET timer
;   * Call init_smp  - Initialize symmetric multiprocessing

; TODO 7: Built Info Map
;   * Build the infomap(0x5000)

; TODO 8: Frame Buffer Write-Combining (LFB WC)
;   * Check if 1 GiB suppored. if so use write combining flag
;   * Force a full TLB reload and apply new caching flags

; TODO 9: Kernel Execution
;   * Copy the trailing kernel binary from (0x8000+bl_size) to its final execution address (0x100000)
;   * Clear all general purpose registers
;   * JUMP TO THE KERNEL ENTRY POINT (0x00100000)

; #############################################################################################################################################################################
; #############################################################################################################################################################################

; Just to make it a little bit clear, here is the structure for 'this file' on memory
;	Physical addr  Usage / Structure           
;	============================================
;	0x0000     	 IDT
;	0x1000      	 GDT 
;	0x2000      	 PML4 table      
;	0x3000      	 Low pdp table              
; 	0x4000      	 High pdg table            
;	0x5000      	 Info map block like acpi, cpu, FB data
;	>0x5040     	 CPU stacks                 
;	0x5F00      	 UEFI FB data                
;	0x8000      	 SSL(second loader) entry point            
;	0x10000      	 PD/PDE
;	0x200000      	 Cleaned memmap     
;	0x220000         UEFI raw/source memmap      
;	0x100000         KERNEL DESTINATION!    

bits 64					; Tells the assembler to generate a 64 bit machine code
org 0x00008000				; Instructions will be assembled as if the first byte sites as 0x8000
default abs				; Whenevery there is a lable, treat it as an absolute address 
bl_size equ 6144			; Pad the Second stage loader to a fixed size


; TODO 1: Entry and Initial Setup

start:
	jmp ssl_entry			; This is where the BSP(Bootstrap processor) jumps
	times 8 - ($ - $$) db 0

BITS 16					; when AP wake up they always start in 16-bits real mode
	cli				; Disable interrupts
	; Zeroing registers; Classic "clean slate" reset
	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov esp, 0x7000			; Set a temporary stack pointer for Application processes
	jmp 0x0000:init_smp_ap		; Far jump to AP initialization. cs = 0x0000

%include "src/multi/ap.asm"		; AP's will start execution as if the file source were here

; BSP code
BITS 64

ssl_entry:				; BSP long-mode entry point
	mov rsp, 0x8000			; Set a known memory address for the stack

	mov edi, 0x5000			
	xor eax, eax
	mov ecx, 960			; 960 * 4 = 3840 bytes, which is from 0x5000 upto 0x5EFF, so we don't overide UEFI data
	rep stosd			; Zero the current 4 byte of 0x5000 and move on to the next 4 byte. Do this 960 times


	; Clear screen
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	mov ax, [0x00005F10]		; Reads the X-resolution 
	mov cx, [0x00005F12]		; Reats the Y-resolution
	mul ecx				; ax(or to be specific dx:ax) = ax * cx.
	mov ecx, eax
	mov rdi, [0x00005F00]		; rdi gets pointer to framebuffer base
	mov eax, 0x00FFFFFF		; Color = gray
	rep stosd			


; TODO 2: GDT and Paging Structure Setup

	; That wipes memory from 0x00000000 up to 0x00005000 for IDT, GDT, PML4 and PDP)
	mov ecx, 5120
	xor eax, eax
	mov edi, eax
	rep stosd

	; This wipes memory from 0x10000 to 0x5FFFF, which uses to store all the page entries of PD
	mov edi, 0x00010000
	mov ecx, 81920
	rep stosd		

	; Copy the GDT to 0x1000
	mov esi, gdt64			; momory address of GDT
	mov edi, 0x00001000		; Where it's going to be stored
	mov ecx, (gdt64_end - gdt64)	; How many times(in byte). ecx = GDT's size in byte
	rep movsb			; Copy it to 0x1000. [edi] = [esi]; esi += 1 && edi += 1
	

	; Setup Paging
%include "src/loader/paging.asm" 

paging_setup_done:

; Load the GDT
%include "src/loader/gdt.asm"


; TODO 3: Interrupt descriptor table setup

	xor edi, edi 			; set edi to zero, so the IDT will be built starting at memory address 0x0000000000000000

%include "src/loader/idt.asm"

	mov edi, start			; Points to the first intruction of bootstrap code
	mov rax, qword 0x9090909090909090	; Prepair 8 NOP bytes(0x90)
	stosq				; Overwrite 8-byte with NOP, removing the jump the AP should not execute

; TODO 4: Process memory map
	jmp memmap
	; memmap.asm
	done_memmap:

; TODO 5: High half paging and APIC initialization

	; Build high PDPT (PDPTE entries)
	mov ecx, dword [p_mem_amount]	; Load the amount of usable memory(in MiB)
	shr ecx, 10			; Divide by 1024 - convert MiB into GiB
	add rcx, 1			; It make sure that we have atleast one PDPE even if the memory is tiny
	mov edi, 0x00004000		; Location of PDPT entries
	mov eax, 0x00020003		; Points to the first page directory 0x2000, bits 0 (present) and bit1 (read/write) set
pdpe_high_build:
	stosq				; edi = [rax] = 0x00020003
	add rax, 0x00001000		; add 4KiB for the next PD, since each PD 4KiB = 512 entries * 8 byte
	dec ecx
	cmp ecx, 0			; Repeat until all PDPE entries are created 
	jne pdpe_high_build

	mov esi, 0x00200000		; Point to the cleaned memory map created earlier
	mov edi, 0x00020000		; Where PDE entries will be stored
pde_range_next:
	lodsq				; Load the 8 byte from rsi into rax; rsi += 8 - Base address
	xchg rax, rcx
	lodsq				; Load the next 8 byte - Length (in MiB) 
	xchg rax, rcx			; Swap again, so rax = length & rcx = base
	cmp rax, 0			; End?
	je pde_end			
	cmp rax, 0x00200000		; Checks if the length is 2MiB
	ja skipfirst4mb			; If the length is above we're safe ti skip the first chunk
	add rax, 0x00200000		; Skip the base by 2MiB
	sub rcx, 2			; Reduce the leght by 2 MiB
skipfirst4mb:
	shr ecx, 1			; The number of PDE entries needed
	add rax, 0x00000083		; Bits 0 - Present, bit 1 - Read/Write and bit 7 size set
pde_high_gen:				
	stosq				; Write PDE
	add rax, 0x00200000		; Move to the next 2MiB chunk
	cmp ecx, 0			; No more pages?
	je pde_range_next
	dec ecx
	cmp ecx, 0
	jne pde_high_gen
	jmp pde_range_next
pde_end:

	mov ecx, IA32_APIC_BASE		; Load MSR number
	rdmsr				; Read APIC base MSR - result in edx:eax
	bts eax, 11			; Set bit 11 - APIC global enable
	wrmsr				; Write back
	and eax, 0xFFFFF000		; Zero out the lower 12 bits, since APIC is 4k aligned
	shl rdx, 32			; Move high half into upper 32-bits
	add rax, rdx			; Combine to full 64 bit address
	mov [p_LocalAPICAddress], rax	; Save APIC address

	mov eax, 1			; CPUID leaf 1 has feature bits
	cpuid				; Run cpuid with eax =1, bit 21 of ecx = x2APIC support
	shr ecx, 21			; Move bit 21 (x2APIC feature bit) down to the low bit position (just to make it is that's al)
	and cl, 1			; Isolate the x2APIC bit as a single 0/1 value
	mov byte [p_x2APIC], cl		; Save that bit


; TODO 6: Hardware/CPU configuration

	call init_acpi			; Find and process the ACPI tables
	call init_cpu			; Configure the BSP CPU
	call init_hpet			; Configure the HPET
	call init_smp			; Init of SMP, deactivate interrupts

	mov rsi, [p_LocalAPICAddress]	; Load the local APIC base address
	add rsi, 0x20			; Points to APIC ID
	lodsd				; Load the CPU APIC ID into rax
	shr rax, 24			; al now holds the CPU APIC ID
	shl rax, 10			; Compute APIC ID * 1024 — reserve a 1KB stack slot per CPU
	add rax, 0x0000000000050400	; Place each CPU’s stack in the reserved high area
	mov rsp, rax			; give the CPU a safe and unique stack to use


; TODO 7: Built Info Map

; Build the infomap (at linear address 0x5000)
	jmp infomap
	; infomap.asm
	done_infomap:



; TODO 8: Frame Buffer Write-Combining (LFB WC)

	; Store linear frame buffer base, resolution etc..
	mov di, 0x5080
	mov rax, [0x00005F00]		
	stosq
	mov eax, [0x00005F00 + 0x10]	
	stosd
	mov eax, [0x00005F00 + 0x14]	
	stosw
	mov ax, 32
	stosw

	; Store PCIe device count and IAPC boot architecture flags
	mov di, 0x5090
	mov ax, [p_PCIECount]
	stosw
	mov ax, [p_IAPC_BOOT_ARCH]
	stosw

	; Store one byte flags indicating whether 1GiB pages are used and whether x2APIC is available
	mov di, 0x50E0
	mov al, [p_1GPages]
	stosb
	mov al, [p_x2APIC]
	stosb


; Set the Linear Frame Buffer to use write-combining
	mov eax, 0x80000001		; CPU extended feature
	cpuid
	bt edx, 26			; test if bit 26 is set
	jnc lfb_wc_2MB			; If not then 1GIB page isn't supported

; Set the 1GB page the frame buffer is in to WC - PAT = 1, PCD = 0, PWT = 1
	jmp lfb_wc_1GB
	paging_fully_done:


; TODO 9: Kernel Execution

; Clear all register to start clean
clear_regs:
	xor eax, eax		
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	jmp 0x00100000			; JUMP TO KERNEL

%include "src/loader/memmap.asm"
%include "src/loader/infomap.asm"
%include "src/hw/platform.asm"
%include "src/multi/smp.asm"
%include "src/loader/data.asm"



; End of file marker
EOF:
	db 0xDE, 0xAD, 0xC0, 0xDE

times bl_size-($-$$) db 0x90


