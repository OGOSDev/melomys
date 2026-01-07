; TODO 2
paging_start:
	mov edi, 0x00002000		; Create a PML4 entry - Entry #1
	mov eax, 0x00003003		; Bits 0 and 1 set -> Present + Writable, The rest (0x3000) -> addresses of the low-PDP table
	stosq				; eax -> rdx = 0x0000000000003003. Store rax at [rdi], then increment rdi by 8
	mov edi, 0x00002800		; Create a PML4 entry for higher half - Entry #2
	mov eax, 0x00004003		; Same thing, except this entry points at the high PDP
	stosq

	mov eax, 0x80000001		; Loads the CPUID leaf that exposes extended CPU feature flags
	cpuid				; After this eax, ebx, ecx, edx contain feature bits
	bt edx, 26			; This checks if bit 26 is set(1) or not. If it's set, so will carry flag
	jc setup_1gb_paging		; If doesn't support 1 GiB paging, then it will use regular 2 MiB or 4 KiB pages

	mov ecx, 16			; 16 entries -> 16 GiB total identity mapped
	mov edi, 0x00003000		; set a destination pointer rdi to 0x3000 - That's where the low PDP entry live
	mov eax, 0x00010003		; 0x3 set -> Present + Writable/Readable, 0x3000 -> addresses of the low-PDP table

gen_pdpte_4k_blocks:
	stosq
	add rax, 0x00001000		; Increment rax by 4 KiB. because each PD is a 4 Kib table, so the next PDPTE should point at the next PD table (0x11000, 0x12000...)
	dec ecx
	jnz gen_pdpte_4k_blocks		; Loop until 16 entries are created

	mov edi, 0x00010000		; memory address of first PDE
	mov eax, 0x00000083		; Bits 0 (base), 1 (readable/writable), and bit 7 (page size)
	mov ecx, 8192			; Create 8192 PDE. each PDE maps 2MiB -> 8192 * 2 = 16GiB
gen_pde_2mb_pages:			; Create a 2MiB page
	stosq
	add rax, 0x00200000		; Increment rax by 2MiB, so the next PDE maps the next 2MiB physical range 
	dec ecx
	jnz gen_pde_2mb_pages		; Loop until all PDEs are created
	jmp paging_setup_done		

setup_1gb_paging:
	mov byte [p_1GPages], 1 	; markes p_1GPages = 1, so later kernel knows big pages are in use

	mov ecx, 16			; Create 16 PML4 entries
	mov edi, 0x00002000		; the PML4 table begins at physical memory address 0x2000
	mov eax, 0x00010003		; Bits 0 (base addr), 1 (readable/writable), location of low PDP
gen_pml4_slots_1gb:
	stosq				; loop stosq stores that rax into PML4 slots and increments rax by 0x1000 to point to subsequent PDP tables
	add rax, 0x00001000		; 4KiB later (next PDP)
	dec ecx
	jnz gen_pml4_slots_1gb

	mov ecx, 8191			; Creates 8191 PDPTEs
	mov edi, 0x00010000		; It's where the low PDPE lives
	mov eax, 0x00000083
gen_pdpte_1gb_pages:			; Create a 1GiB page
	; writes that entry; then add rax, 0x40000000 increases the base by 1 GiB for the next entry
	stosq			
	add rax, 0x40000000		
	dec ecx
	jnz gen_pdpte_1gb_pages

	jmp paging_setup_done


;



; TODO 8
lfb_wc_1GB:
	mov rax, [0x00005F00]		; Loads the physical address of the framebuffer
	mov rbx, 0x100000000		; 4GiB
	cmp rax, rbx			; If framebuffer is below 4GB, we don’t try to remap using a 1GiB PDE
	jbe lfb_wc_end			

	; Split the framebuffer address into high bits(aligned 1GiB page base) and low bits(offset inside that 1GiB region)
	mov rbx, rax
	mov rcx, 0xFFFFFFFFC0000000
	and rax, rcx
	mov rcx, 0x000000003FFFFFFF
	and rbx, rcx
	; Writes a PDPTE with customized caching flags
	mov ax, 0x108B			; present = 1, read/write = 1, page size = 1, page cache disable = 0(allowed), page write through = 1 and page attribute index bit = 1
	mov rdi, 0x1FFF8
	mov [rdi], rax			; Write updated PDPTE

	mov rax, 0x000007FFC0000000
	add rax, rbx			
	mov [0x00005080], rax		; Final vertual address for framebuffer

	jmp lfb_wc_end

lfb_wc_2MB:
	mov ecx, 4			; 4 pages
	mov edi, 0x00010000		; edi now points to PDE
	mov rax, [0x00005F00]		; Load framebuffer’s physical base addr
	shr rax, 18			; Divide by 2MiB - PDE maps one 2 MiB region
	add rdi, rax			; Jump ahead in the PDE array to the entry that covers the framebuffer
lfb_wc_2MB_nextpage:
	mov eax, [edi]			; Load PDE entry(8 byte)
	or ax, 0x1008			; Set bit 3 = PWT (write-through) and bit 12 = PAT (PAT index bit)
	and ax, 0xFFEF			; Clear bit 4 = PCD (Page Cache Disable)
	mov [edi], eax			; Store the updated PDE back to memory
	add edi, 8			; Move to the next PDE, since one PDE entry is 8-byte
	sub ecx, 1			; Track PDE
	jnz lfb_wc_2MB_nextpage		; If there is still PDE 
lfb_wc_end:
	mov rax, cr3			; Load cr3 so we can relode it
	mov cr3, rax			; Force a full TLB flush - make the CPU reread page table entries so the new PDE/PDPTE caching flags are used
	wbinvd				; Write back and invalidate caches - important for framebuffer

	mov esi, 0x8000+bl_size		; Point to the start of the trailing payload to copy
	mov edi, 0x100000		; An address where the kernel must live
	mov ecx, ((32768 - bl_size) / 8)	; 32768(32KiB) is the kernel size(the size that comes after pure64) and dividing it with 8 give us the iterations
	rep movsq			; Copy the entiry in 8 byte chunks
	
	jmp paging_fully_done
