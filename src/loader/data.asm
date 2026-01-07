; =============================================================================
; Pure64 -- a 64-bit OS/software loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; System Variables
; =============================================================================


;CONFIG
cfg_smpinit:		db 1		; a simple boolean flag: 1 means Symmetric Multiprocessing is on, 0 means its off.

; Memory locations
InfoMap:		equ 0x0000000000005000 ; the starting address of the main information map structure
IM_DetectedCoreIDs:	equ 0x0000000000005100		; list of 1-byte APIC IDs discovered during initial bootup
IM_PCIE:		equ 0x0000000000005400		; starting location for storing PCI Express configuration entries (16 bytes each)
IM_IOAPICAddress:	equ 0x0000000000005600		; memory-mapped addresses for all found IO APIC units
IM_IOAPICIntSource:	equ 0x0000000000005700		; redirection mapping entries from the IO APIC
SystemVariables:	equ 0x0000000000005800	; this is the base address for all core kernel variables
IM_ActivedCoreIDs:	equ 0x0000000000005E00		; a list to track which APIC IDs have successfully initialized and are active
VBEModeInfoBlock:	equ 0x0000000000005F00		; location for the 256-byte VESA BIOS Extension (VBE) structure

; DQ - Starting at offset 0, increments by 0x8 (64-bit/8-byte values)
p_ACPITableAddress:	equ SystemVariables + 0x00	; memory address of the main ACPI tables (RSDP)
p_LocalAPICAddress:	equ SystemVariables + 0x10	; the memory-mapped address of the main Local APIC (interrupt controller)
p_Counter_Timer:	equ SystemVariables + 0x18	; reserved slot for a generic counter timer address
p_Counter_RTC:		equ SystemVariables + 0x20	; reserved slot for the Real Time Clock address
p_HPET_Address:		equ SystemVariables + 0x28	; the physical memory address of the High Precision Event Timer

; DD - Starting at offset 0x80, increments by 4 (32-bit/4-byte values)
p_BSP:			equ SystemVariables + 0x80	; stores the APIC ID of the Bootstrap Processor
p_mem_amount:		equ SystemVariables + 0x84	; total system memory, writen in mebibytes (MiB)
p_HPET_Frequency:	equ SystemVariables + 0x88	; the calculated clock rate of the HPET in Hz

; DW - Starting at offset 0x100, increments by 2 (16-bit/2-byte values)
p_cpu_speed:		equ SystemVariables + 0x100	; the detected cpu clock speed in MHz
p_cpu_activated:	equ SystemVariables + 0x102	; the current count of processors that have successfully booted
p_cpu_detected:		equ SystemVariables + 0x104	; the total number of cpus detected on the system
p_PCIECount:		equ SystemVariables + 0x106	; the total count of PCI Express structures found
p_HPET_CounterMin:	equ SystemVariables + 0x108	; minimum number of ticks for the HPET counter (used for validation)
p_IAPC_BOOT_ARCH:	equ SystemVariables + 0x10A	; value describing the I/O APIC boot architecture

; DB - Starting at offset 0x180, increments by 1 (8-bit/1-byte values)
p_IOAPICCount:		equ SystemVariables + 0x180	; the total number of I/O APIC controllers found
p_BootMode:		equ SystemVariables + 0x181	; stores 'U' for UEFI boot or something else for BIOS boot
p_IOAPICIntSourceC:	equ SystemVariables + 0x182	; count of all IO APIC Interrupt Source Overrides found
p_x2APIC:		equ SystemVariables + 0x183	; flag: 1 if x2APIC mode is supported/enabled
p_HPET_Timers:		equ SystemVariables + 0x184	; the number of comparators available in the HPET
p_BootDisk:		equ SystemVariables + 0x185	; identifier for the disk used to boot the OS, 'F' for floppy disk
p_1GPages:		equ SystemVariables + 0x186	; flag: 1 if 1 Gigabyte (1G) pages are supported by the CPU

align 16
GDTR32:					; Global Descriptors Table Register for 32-bit mode
dw gdt32_end - gdt32 - 1		; the size of the GDT structure minus one
dq gdt32				; the linear address where the 32-bit GDT begins

align 16
gdt32:
SYS32_NULL_SEL equ $-gdt32		; the mandatory null segment descriptor
dq 0x0000000000000000
SYS32_CODE_SEL equ $-gdt32		; the selector for the 32-bit code segment (executable)
dq 0x00CF9A000000FFFF			; descriptor flags defining a 4GB, 32-bit, executable/readable code segment
SYS32_DATA_SEL equ $-gdt32		; the selector for the 32-bit data segment (writable)
dq 0x00CF92000000FFFF			; descriptor flags defining a 4GB, 32-bit, writable data segment
gdt32_end:

align 16
tGDTR64:				; a temporary Global Descriptors Table Register (used internally for copying)
dw gdt64_end - gdt64 - 1		; the limit (size) of the 64-bit GDT
dq gdt64				; the address of the 64-bit GDT definition

align 16
GDTR64:					; the final Global Descriptors Table Register for 64-bit mode
dw gdt64_end - gdt64 - 1		; the limit (size) of the GDT
dq 0x0000000000001000			; the fixed memory address where the 64-bit GDT will reside

gdt64:					; This structure is copied to 0x0000000000001000
SYS64_NULL_SEL equ $-gdt64		; the mandatory null segment descriptor
dq 0x0000000000000000
SYS64_CODE_SEL equ $-gdt64		; the selector for the 64-bit code segment (long mode executable)
dq 0x00209A0000000000			; flags enabling long mode, present, code segment
SYS64_DATA_SEL equ $-gdt64		; the selector for the 64-bit data segment (writable)
dq 0x0000920000000000			; flags making it a present, writable data segment
gdt64_end:

IDTR64:					; Interrupt Descriptor Table Register for 64-bit mode
dw 256*16-1				; the limit (size) of the IDT (256 entries * 16 bytes/entry = 4096 bytes)
dq 0x0000000000000000			; the linear address where the IDT will be located in memory (set during kernel init)


; =============================================================================
; EOF
