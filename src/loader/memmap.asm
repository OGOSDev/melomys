; TODO 4
memmap:
	; Contain only usable memory
	xor r9, r9			; Used to check contigous memory block
	xor ebx, ebx			; Used as flag indicator to check if the current memory block is contiguous with the previous
	mov esi, 0x00220000 - 48	; Point to the start of UEFI memory map - 48 -> 48 bytes before the first record, then 'add esi, 48' moves esi to exactly the first record
	mov edi, 0x00200000		; Destination for usable memory map
memmap_next:
	add esi, 48			; Move to the next memory descriptor 
	mov rax, [rsi+24]		; Load the number of pages for this entry
	cmp rax, 0			; Check if we reach the end
	je raw_memmap_end
	mov rax, [rsi+8]		; Load physical address
	cmp rax, 0x100000		; Check memory map below 1MiB
	jb memmap_next		
	mov rax, [rsi]			; Load a type of memory
	cmp rax, 0			; Checks if the memory reserved or not
	je memmap_next
	cmp rax, 7			; Only use type 1-7 - usable memory
	jbe memmap_usable
	mov bl, 0			; Not usable
	jmp memmap_next
memmap_usable:
	cmp bl, 1
	je memmap_usable_contiguous	; If the previous contigous, then merge
	mov rax, [rsi+8]
	stosq				; Save physical address
	mov rax, [rsi+24]
	stosq				; Save numver of pages
memmap_check_contiguous:
	mov r9, rax
	shl r9, 12			; multiply pages by 4KiB
	add r9, [rsi+8]			; Compute the next physical address - pages * 4 KiB + current start
	mov bl, 0			; Assume not contiguous by default
	cmp r9, [rsi+56]		; Compare expected address with actual next block start
	jne memmap_next
	mov bl, 1			; Contiguous – mark as mergeable
	jmp memmap_next			; Move to the next block	
memmap_usable_contiguous:
	sub rdi, 8			; It's undoing the increment from the previous stosq to combine blocks
	mov rax, [rsi+24]
	add rax, [rdi]
	stosq				; Merge contigous block
	mov rax, [rsi+24]
	jmp memmap_check_contiguous
raw_memmap_end:
	xor eax, eax			
	stosq				; Blank physical addr
	stosq				; Blank number of pages

	; Remove any small entries(<3MiB)
	mov esi, 0x00200000		; Start at the beginning of the records
	mov edi, 0x00200000
purge:
	lodsq				; Load the physical address into rax
	cmp rax, 0
	je purge_end			; If rax = 0 -> end of a map
	stosq				; Keep physical address
	lodsq				; Load size into rax
	cmp rax, 0x300			; 0x300 pages * 4KiB = 3MiB
	jb purge_skip_entry		; skip entry if it's less than 3MiB
	stosq				; save the size
	jmp purge
purge_skip_entry:
	sub edi, 8			; Undo store for skipped entry 
	jmp purge
purge_end:
	xor eax, eax		
	stosq
	stosq

	; Align the physical address by 2MiB
	mov esi, 0x00200000 - 16	; Start 16 bytes before the first record. then the first line in the loop moves esi to excat record
	xor ecx, ecx			; Counter for total MiB
round_pages:
	add esi, 16
	mov rax, [rsi]			; Load the physical Address
	cmp rax, 0			
	je round_end			; End of list

	mov rbx, rax			; Copy Physical Address to RBX
	and rbx, 0x1FFFFF		; Check alignment to 2MiB
	cmp rbx, 0	
	jz convert_entry		; already alligned

	shr rax, 21
	shl rax, 21
	add rax, 0x200000		; Round up to the next 2 MiB
	mov [rsi], rax
	mov rax, [rsi+8]
	shr rax, 8			; Convert 4K page to MiB
	sub rax, 1			; Subtract 1MiB
	mov [rsi+8], rax
	add rcx, rax			; Add to MiB counter
	jmp round_pages

convert_entry:
	mov rax, [rsi+8]
	shr rax, 8			; Convert 4K page to MiB
	mov [rsi+8], rax
	add rcx, rax			; Add to MiB counter
	jmp round_pages

round_end:
	sub ecx, 2
	mov dword [p_mem_amount], ecx	; Total usable memory
	xor eax, eax			
	stosq
	stosq
	jmp done_memmap
