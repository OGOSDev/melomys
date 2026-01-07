; ####################################################################################################################################################################
; ####################################################################################################################################################################

; TODO 1: PE/COFF header setup
;  	* Define DOS header stub (only “MZ” and minimal fields).
;  	* Define PE signature “PE\0\0”.
;	* Fill COFF header:
;	* Fill optional header (PE32+):
;	* Define section table:

; TODO 2: Create the actual code section
; 	* UEFI calls code section with rcx, rdx and rsp

; TODO 3: Parse System Table
;	* Read BootServices, RuntimeServices, Console I/O and Config table pointer
;	* Locate graphics output protocol(GOP) and advanced config and power interface(ACPI) if needed.

; TODO 4: Set video mode and confirm current mode in GOP
;	* Read GOP mode.
;	* Get framebuffer base, framebuffer size, resolution and pixel per scanline.

; TODO 5: Retrieve UEFI memory map
;	* Call GetMemoryMap()
;	* MemoryMapSize pointer, MemoryMap buffer (memmap), MapKey, DescriptorSize and DescriptorVersion

; TODO 6: Exit Boot Services
;	* Call ExitBootServices(ImageHandle, MapKey).

; TODO 7: Load the Second Stage loader into memory
;	* Copy first 32K from `ssl` to 0x8000

; TODO 8: Store UEFI info in a known memory for Second Stage Loader to use
;	* Write framebuffer infos, and memory map infos to 0x5F00 
;	* Write memory map base, size, key, descriptor info

; TODO 9: Reset registers and setup stack
; 	* Set `rsp = 0x8000`.

; TODO 10: Jump to Second Stage Loader
;	* `jmp 0x8000`

; #####################################################################################################################################################################
; #####################################################################################################################################################################




bits 64				; Assemble instruction using 64 mode encoding
org 0x400000			; This line is for assembler to help it calculate labels and offset. This does NOT mean the code will be loaded in 0x400000
COM1 equ 0x3F8			; COM1 base port
default abs			; Default to absolute addressing mode and not relative

start:				; $$ - just a label


; TODO 1: PE/COFF header setup

header_start:			; An other one - just to make it more human readable but you can use start if you want

db 'MZ', 0x00, 0x00		; This is DOS signature every PE file must have this even if it's not used(in our case)
times 0x3c-($-header_start) db 0; Pad it to 0x3c. why? -> more on the documentation
dd pe_sig - start		; It stores the relative location of PE signature
times 64 db 0			; UEFI doesn't care if we fill the rest DOS stub or not, it's more of windows thing

; https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#coff-file-header-object-and-image
pe_sig:				; PE header starts
db 'PE', 0x00, 0x00		; UEFI require this to know that this is a valid PE image

; https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#machine-types
dw 0x8664			; For x86_64(64-bit) machine
dw 2				; Number of section our PE have. In our case it's two .text and .data
dd 1759708800			; Timestamp - linkers normaly fill this
dd 0				; Pointer to symbol table. Must be zero for PE files on modern systems
dd 0				; Number of symbol - useless for UEFI nowadays
dw opt_header_end - opt_header_start		; Size of the optional header

; https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#characteristics
dw 0x222E			; File charactertics


;https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#optional-header-image-only
opt_header_start:		; The starting point of optional header data	
dw 0x020B			; Magic value for PE32+(PE64)
db 0				; Major
db 0				; Minor linker version
dd code_sec_end - code_sec_start		; The size of the code section
dd data_sec_end - data_sec_start		; The size of initialized data section
dd 0x00				; The size of uninitialized data section. zero, cause we're not using one
dd code_sec_start - start	; It's the relative vertual address of code section from image base
dd code_sec_start - start	; It's the same thing, we have to cause that's what it says on PE spec

; https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#optional-header-windows-specific-fields-image-only
dq 0x400000			; Our prefered address for UEFI do load our image, but UEFI ignores it most of the time and loades some where with free memory
dd 0x1000			; In memory the section must start at the multiple of 4kb memory address
dd 0x1000			; Same but for files on disk
; The next 6 lines are image version, OS version and subsystem version. I don't know their uses and I'm sure you don't have too
dw 0
dw 0
dw 0
dw 0
dw 0
dw 0
dd 0				; must be 0
dd end - start			; Full image size in memory
dd header_end - header_start	; Size of all the headers
dd 0				; Checksum, Must be 0
dw 10				; The subsystem = EFI app and not some windows GUI/cli app
dw 0				; Dll charactestictr, UEFI doesn't enforce these anyway
dq 0x200000			; Reserve 2MB for the stack
dq 0x1000			; Commit 4kb of that give at the start
dq 0x200000			; It's the same but for heap
dq 0x1000			
dd 0x00				; Must be zero
dd 0x00				; No data directory(eg. import/export table)
opt_header_end:			; The end of optional header
align 4

; https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-image_section_header
db ".text", 0x00, 0x00, 0x00		; PE names are 8 byte
dd code_sec_end - code_sec_start	; The size of this section in memory once it's loaded
dd code_sec_start - start		; Offset of this section relative to the image base
dd code_sec_end - code_sec_start	; The size of this section inside the PE file
dd code_sec_start - start		; offset of the actual section byte inside the file
; the next 4 lines are not used, since doesn't do COFF reloc table
dd 0
dd 0
dw 0
dw 0
dd 0x70000020			; charactersticts of this section: executable + readable

; Everything is the same as the code section but for data
db ".data", 0x00, 0x00, 0x00
dd data_sec_end - data_sec_start
dd data_sec_start - start
dd data_sec_end - data_sec_start
dd data_sec_start - start
dd 0
dd 0
dw 0
dw 0
dd 0xD0000040			; Char. of this section: readable + writable

header_end:			; The end of the header 


; TODO 2: Create the actual code section

align 16
code_sec_start:			; The start of code section

	


; Structure		Offset		Function name
; =================================================================================================

; EFI System Table	0x00		Table header

;			0x18 - 0x38 	(Unused)

;			0x40 		ConOut

;						|->	Offset	Purpose

;							0x00	'reset'
;							0x08	Prints text
;							0x10	Check if chars are supported
;							0x18	Get supported text resolutions
;							0x20	Change text resolution
;							0x28	Text colors
;							0x30	'Clean' the screen
;							0x38	Move the txt cursor
;							0x40	show or hide cursor
;							0x48	pointer to current mode data

; 			0x48 - 0x50 	(Unused)

;  			0x58 		runtime services table

;			0x60		Boot services table

;						|->	Offset
;							0x18 - 0x28 	(Unused)
;							0x38		GetMemoryMap
;							0x40 - 0x98	(Unused)
;							0x140		LocateProtocol
;							0xC8 - 0xD0	(unused)
;							0xE8		ExitBootServices
;							0xF8		-

;			0x68		Number of configuration table entries

;			0x70		Config table pointer







	; UEFI provides the following
	mov [img_handle], rcx			; rcx = ImageHandle
	mov [sys_table], rdx			; rdx = EFI_SYSTEM_TABLE *
	mov [efi_ret], rsp			; UEFI stack return
	sub rsp, 56				; Padding - UEFI expects 16 byte alignment


; TODO 3: Parse System Table

;https://uefi.org/specs/UEFI/2.10/07_Services_Boot_Services.html#image-services

	; Save the pointer address
	mov rax, [sys_table]
	mov rax, [rax + 0x40]			; Loades the memory address pointer of ConsoleIO into [console_io]
	mov [console_io], rax
	mov rax, [sys_table]
	mov rax, [rax + 0x58]			; [[EFI_SYSTEM_TABLE]+88] into [run_time_services]
	mov [run_time_services], rax
	mov rax, [sys_table]
	mov rax, [rax + 0x60]			; [[EFI_SYSTEM_TABLE]+96] into [boot_services]
	mov [boot_services], rax
	mov rax, [sys_table]
	mov rax, [rax + 0x68]			; [[EFI_SYSTEM_TABLE]+104] into [config_entry_num]
	mov [config_entry_num], rax
	mov rax, [sys_table]
	mov rax, [rax + 0x70]			; [[EFI_SYSTEM_TABLE]+112] into [config_table]
	mov [config_table], rax

	; Char/Colour drawing
	mov rcx, [console_io]					; "this" pointer - the text output protocl
	mov rdx, 0x07						; light gray on black
	call [rcx + 0x28]					; [console_io] + 40 => SetAttribute()

	mov rcx, [console_io]					; Just to not see stuffs like 'BdsDxe:....'
	call [rcx + 0x30]					; [console_io] + 48 => ClearScreen()

	lea rsi, [boot_msg]
	call write_string
	

	mov rax, [sys_table]			; Loads the pointer address to UEFI system table
	mov rcx, [rax + 0x68]			; holds the number of entries in the configuration table
	mov rsi, [config_table]			; loads the pointer address of configuration table 
        test rcx, rcx			; checks if there are no entries to search
        jz err				; if then jump to 'err'
loop:
        mov rax, [ATG]			; Loads the first 8 byte of ACPI GUID into rax
        xor rax, [rsi]			; Compare the first 8-byte of table entry with rax
	; it's the same thing, but for the second 8-byte table entry
        mov 	rbx, [ATG + 8]
        xor     rbx, [rsi + 8]
        or      rax, rbx			; OR gate of both value: it's zero if and only if both are zero
        jz      found				; jumps to found, if zero flag is set. which means full 16 byte GUID matches

        sub     rcx, 1				; Decrement entry counter by one
        jz      err				; If there are no entry left to check, then jump to 'err'

        add     rsi, 24				; now rsi points to the next entry, since one entry is 16 byte(GUID) + 8 byte(pointer) = 24 byte
        jmp     loop				; repeat the search for the next entry
found:
        mov     rax, [rsi + 16]			; now rax have the ACPI pointer address
        mov     [ACPI], rax			; Save it

edid_here:
	mov rcx, EAPG				; rcx = points to EFI_EDID_DISCOVERED_PROTOCOL GUID
	mov rdx, 0				; Must be zero - *Registration OPTIONAL
	mov r8, EDID				; r8 is 3rd argumend - after the call, EDID = the pointer to the protocol that matched with the GUID			
	mov rax, [boot_services]
	mov rax, [rax + 0x140]			; [boot_services] + 320 = BootServices->LocateProtocol 
	call rax				; Call LocateProtocol(EAPG, NULL, &EDID)
	test rax, 0x0				; Checks if it found a potocol that matches EAPG, 0 = success
	je get_edid				; If the zero flag it set(then rax = 0: success) then it jumps straight to 'get_edid'

	; It's the same thing, but for EDPG 
	mov rcx, EDPG		
	mov rdx, 0						
	mov r8, EDID			
	mov rax, [boot_services]
	mov rax, [rax + 0x140]
	call rax
	test rax, 0x0
	je get_edid						
	jmp use_gop				; If it's not found then it uses GOP

get_edid:
	mov rax, [EDID]						; Load the EDID pointer into rax
	mov ebx, [rax]						; ebx = EDID pointer
	cmp ebx, 128						; ebx first 4-byte(EDID legth) must be at least 128 bytes to be valid 
	jb use_gop						; If it's less then fallback into using GOP
	mov rbx, [rax+8]					; the second 4-byte is for padding
	mov rax, [rbx]						; now rax have the EDID header
	mov rcx, 0x00FFFFFFFFFFFF00				; EDID headers should alway be 0x00FFFFFFFFFFFF00
	cmp rax, rcx						; Checks if the 8-byte is same as 0x00FFFFFFFFFFFF00
	jne use_gop						; If it's not, then it fallback into using GOP
	xor eax, eax					
	xor ecx, ecx						
	mov al, [rbx+0x38]					; Load the low 8-bits horizontal resolution into al
	mov cl, [rbx+0x3A]					; Load the high 4-bits horizontal resolution into cl
	and cl, 0xF0						; abcdefgh AND GATE Opt With 11110000 = abcd0000 - Makes cl only the apper part remains and rest become zero
	shl ecx, 4						; 0000abcd0000 - shift ecx left by 4-bits 
	or eax, ecx						; combine both high 4 with low 8 bit for a full 12 horizontal pixel count
	mov [horizontal_res], eax				; Saves it
	; It's the same thing but for vertical resolution
	xor eax, eax
	xor ecx, ecx
	mov al, [rbx+0x3B]
	mov cl, [rbx+0x3D]
	and cl, 0xF0						
	shl ecx, 4
	or eax, ecx
	mov [vertical_res], eax

use_gop:
	mov rcx, GOPG						; Loads the addr of GOP GUID(GOPG) into rcx
	mov rdx, 0						; Must be zero. (used for register notification, and we don't care about that)
	mov r8, gop						; Will hold a ponter to the protocol interface returned by LocateProtoc. gop(after call) = point to the matched protocol
	mov rax, [boot_services]				
	mov rax, [rax + 0x140]					; [boot_services] + 320 = BootServices->LocateProtocol 
	call rax						; Call LocateProtocol(GOPG, NULL, &gop)
	cmp rax, 0x0						; 0 = success
	jne err							; If rax != 0, then jump to 'err' - Can't find GOP 
	mov rax, [gop]
	add rcx, 0x18
	mov rcx, [rcx]						; rcx holds the address of the mode
	mov eax, [rcx]						; eax holds the first 32-bit of mode - MaxMode
	mov [max_vid_modes], rax				
	jmp use_gop_query_mode

try_next_mode:
	mov rax, [mode_index]					; Load the current mode number into rax
	add rax, 1						; Increment the mode number
	mov [mode_index], rax					; Saves the new mode number which is 1 + old mode number
	mov rdx, [max_vid_modes]				; Load the total number of available GOP modes into rdx
	cmp rax, rdx						; Checks if we finished all modes
	je load_fb_info						; If we have reached the max, then jump to 'load_fb_info'


; TODO 4: Set video mode and confirm current mode in GOP

use_gop_query_mode:
	mov rcx, [gop]						; Loads GOP protocol interface pointer into rcx
	mov rdx, [mode_index]					
	lea r8, [gop_size]					; Argument 3 - pointer where UEFI will write the size of the mode info struct
	lea r9, [gop_info]					; Argument 4 - address of pointer that will recieve the address of the mode info struct
	call [rcx]						; GOP->QueryMode

	mov rsi, [gop_info]					; gop_info - holds the pointer that UEFI filled in
	lodsd							; eax = rsi(32-bit); rsi += 4
	lodsd							; Loads the horizontal resolution and compare it to what we want
	cmp eax, [horizontal_res]				; If it's not what we want then go to next mode 
	jne try_next_mode
	; It's the same thing with the horizontal one, but for vertical
	lodsd							
	cmp eax, [vertical_res]
	jne try_next_mode
	lodsd							; Loads the pixel format into eax
	bt eax, 0						; checks if it's 32-bit colour mode - bit 0 must be 1 which will set a Carry Flag 
	jnc try_next_mode					; If it's not 32-bit colour mode then, go to the next mode

	mov rcx, [gop]					
	mov rdx, [mode_index]				
	call [rcx + 0x08]					; GOP->SetMode
	cmp rax, 0x0						; 0x0 = Success 
	jne try_next_mode
load_fb_info:
	mov rcx, [gop]
	add rcx, 0x18
	mov rcx, [rcx]						; GOP->Mode - rcx holds the address of the Mode
	mov rax, [rcx+24]					; Framebuffer base
	mov [fb_base], rax						 
	mov rax, [rcx+32]					; Framebuffer size
	mov [fb_size], rax					
	mov rcx, [rcx+8]				
	mov eax, [rcx+4]					; Horizontal Resolution
	mov [XR], rax						
	mov eax, [rcx+8]					; Vertical Resolution
	mov [YR], rax						
	mov eax, [rcx+32]					; PixelsPerScanLine
	mov [pps], rax					




; TODO 5: Retrieve UEFI memory map

get_memmap:
	; Get memory map from UEFI and save it [memmap]
	lea rcx, [memmapsize]					; Parameter 1 - pointer to a variable that holds the size of memory map buffer
	mov rdx, [memmap]					; Parameter 2 - pointer to memory map buffer where UEFI will write entries
	lea r8, [mmapkey]					; Parameter 3 - UEFI writes the 'key' value here, and it's used to exit boot services
	lea r9, [descriptor_size]				; Parameter 4 - UEFI writes the size of each memory entry
	lea r10, [descriptor_version]				; Parameter 5 - descriptor version; must go on the stack [rsp+32]
	mov [rsp+32], r10
	mov rax, [boot_services]
	call [rax + 0x38]					; BootServicer->GetMemoryMap()
	cmp al, 0x05						; EFI_BUFFER_TO_SMALL = 0x05 - the memory size wasn't big enough
	je get_memmap						; 0x0 = Success
	cmp rax, 0x0
	jne err


; TODO 6: Exit Boot Services

	; UEFI isn't needed anymore
	mov rcx, [img_handle]					; EFI_HANDLE
	mov rdx, [mmapkey]					; UEFI requires the correct memory map 'key' to exit boot services
	mov rax, [boot_services]
	call [rax + 0xe8]					; ExitBootServices()
	cmp rax, 0x0
	jne get_memmap						; If it failed, get the right memory map

	

;  TODO 7: Load the Second Stage loader into memory
	cli
	call init_serial					; For debug
	; Copy Pure64 to the correct memory address
	mov rsi, ssl						; ssl - is were the Second Stage Loader was placed on memory by UEFI
	mov rdi, 0x8000						; A memory address that the payload will get loaded into
	mov rcx, 32768						; Copy 32 kib into physical address 0x8000
	rep movsb						; Copy rsi into rsd, rcx times and increment both by one byte

; TODO 8: Store UEFI info in a known memory for Second Stage Loader to use

	; Save UEFI values to the area of memory where Pure64 expects them
	mov rdi, 0x00005F00					; Destination for boot info
	mov r15, rdi						; Just for debug message, nothing much
	mov rax, [fb_base]
	stosq							; Frame buffer base
	mov rax, [fb_size]
	stosq							; Frame buffer size in bytes
	mov rax, [XR]
	stosw							; Horizontal Resolution
	mov rax, [YR]
	stosw							; Vertical Resolution
	mov rax, [pps]
	stosw							; Pixels Per ScanLine
	mov rax, 32					
	stosw							; Bits Per Pixel
	mov rax, [memmap]
	mov rdx, rax						; Save memory map base address to rdx
	stosq							; Memory map base
	mov rax, [memmapsize]
	add rdx, rax						; Now rdx points to the end of the memory map
	stosq							; Size of Memory Map in bytes
	mov rax, [mmapkey]
	stosq							; The key that got used to Exit Boot Services
	mov rax, [descriptor_size]
	stosq							; The size of each descriptor
	mov rax, [descriptor_version]
	stosq							; Desctiptor version
	mov rax, [ACPI]
	stosq							; ACPI table address
	mov rax, [EDID]
	stosq							; EDID Data - which are address and size
	
	; blank entries to mark the end of the UEFI memory map
	mov rdi, rdx						; since rdx holds address to end of memory map
	xor eax, eax
	mov ecx, 8
	rep stosq

	lea rsi, [value_msg]
	call write_string
	
	mov rbx, r15
	call write_hex
	call write_nl						; New line

	mov rdi, [fb_base]
	mov eax, 0x00000000					; ARGB - black
	mov rcx, [fb_size]
	shr rcx, 2						; shr rcx, 2 = rcx/2^2 - which divide rcx by 4 to converst byte into pixel
	rep stosd


; TODO 9: Reset registers and setup stack


	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	xor ebx, ebx
	mov rsp, 0x8000						; setting up stack pointer for the second stage loader
	xor ebp, ebp
	xor esi, esi
	xor edi, edi
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15


;  TODO 10: Jump to Second Stage Loader
	lea rsi, [load_msg]
	call write_string	
	jmp 0x8000



; Initialize serial port for debugging
init_serial:
   	mov dx, COM1 + 1
    	xor al, al
    	out dx, al          ; Disable interrupts
    	mov dx, COM1 + 3
    	mov al, 0x80        ; Enable DLAB (set baud rate divisor)
    	out dx, al
    	mov dx, COM1 + 0
    	mov al, 0x01        ; Divisor 1 = 115200 baud (Most standard)
    	out dx, al
    	mov dx, COM1 + 1
    	xor al, al
    	out dx, al
    	mov dx, COM1 + 3
    	mov al, 0x03        ; 8 bits, no parity, one stop bit
   	out dx, al
	
        mov dx, COM1 + 2
        mov al, 0xC7
        out dx, al

        mov dx, COM1 + 4
        mov al, 0x0B
        out dx, al

    	ret

; send one char in al
serial_putc:
    	push rdx
    	push rax
    	mov dx, COM1 + 5
.wait:
    	in al, dx
    	test al, 0x20       ; Wait until Transmit Holding Register is empty
    	jz .wait
    	pop rax
   	mov dx, COM1
    	out dx, al          ; Send the character
    	pop rdx
    	ret

; Usage: lea rsi, [label]

write_string:
	push rdx
	push rax
.next_char:
        lodsb
        test al, al
        jz .done

.wait:
        mov dx, COM1 + 5
        in al, dx
        test al, 0x20
        jz .wait

        mov dx, COM1
        mov al, byte [rsi-1]
        out dx, al
        jmp .next_char

.done:
	pop rax
	pop rdx
        ret


; Print 64 bit hex to serial
; rbx = value to print
; Usage: mov rbx, addr
write_hex:
 	push rax
    	push rbx
    	push rcx
    
    	; Print '0x' prefix
    	mov al, '0'
    	call serial_putc
    	mov al, 'x'
    	call serial_putc

    	mov rcx, 16         ; 16 hex digits
.loop:
    	rol rbx, 4          ; Get the top 4 bits
    	mov al, bl
    	and al, 0x0F        ; Mask them
    	add al, '0'         ; Convert to ascii
   	cmp al, '9'
    	jbe .send		
    	add al, 7           ; Adjust for >10 or (A-F)
.send:
    	call serial_putc
    	loop .loop

    	pop rcx
    	pop rbx
    	pop rax
    	ret

global write_nl
write_nl:
	push rax
	mov al, 10
    	call serial_putc
	pop rax
	ret

	
err:
	lea rsi, [err_msg]
	call write_string
.fever:
	hlt
	jmp .fever


times 2048-$+$$ db 0

code_sec_end:




data_sec_start:

img_handle:		dq 0					
sys_table:		dq 0					
efi_ret:		dq 0					
boot_services:		dq 0				
run_time_services:	dq 0					
config_table:		dq 0					
ACPI:			dq 0			
console_io:		dq 0					
gop:			dq 0				
config_entry_num:	dq 0
EDID:			dq 0
fb_base:		dq 0		
fb_size:		dq 0		
XR:			dq 0				
YR:			dq 0				
pps:			dq 0				
BPP:			dq 0			
memmap:			dq 0x220000				; It's where memory map is stored
memmapsize:		dq 32768				; Max size in byte
mmapkey:		dq 0
descriptor_size:	dq 0
descriptor_version:	dq 0
vid_orig:		dq 0
mode_index:		dq 0
max_vid_modes:		dq 0
gop_size:		dq 0
gop_info:		dq 0
horizontal_res:		dd 2560					; Default GOP Horizontal Resolution 
vertical_res:		dd 1440					; Default GOP Vertical Resolution


; The following are UEFI Protocol Identifiers
; https://github.com/jethrogb/uefireverse/blob/master/guiddb/efi_guid.c

GOPG:
dd 0x9042a9de
dw 0x23dc, 0x4a38
db 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a

ATG:
dd 0xeb9d2d30
dw 0x2d88, 0x11d3
db 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d

EAPG:
dd 0xbd8c1056
dw 0x9f36, 0x44ec
db 0x92, 0xa8, 0xa6, 0x33, 0x7f, 0x81, 0x79, 0x86

EDPG:
dd 0x1c0c34f6
dw 0xd380, 0x41fa
db 0xa0, 0x49, 0x8a, 0xd0, 0x6c, 0x1a, 0x66, 0xaa


; UEFI proc-debug messages
boot_msg		db "[+] Booting...",13, 10, 0
err_msg			db "[+] ERROR!",13, 10, 0
value_msg		db "[+] Done: saving all UEFI values to ", 0
load_msg		db "[+] Done: second stage loader loaded and starting...", 0



align 4096							; Align the Second Stage Loader to a 4 kib boundary
ssl:

align 65536							; Align to 64KiB for Second Stage Loader for memory mapping, paging etc.
ramdisk:

times 65536 + 0x1000 - $ + $$ db 0  				 ; 64 KiB payload + 4 KiB safety
data_sec_end:

end:
