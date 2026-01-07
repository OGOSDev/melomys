BITS 64
ORG 0x0000000000100000
DEFAULT REL

%define COM1 0x3F8

global kernel_start

section .text

; No comment needed, b/c I already done it
kernel_start:
	mov rsp, 0x0000000000200000	; temporary stack 128 KiB above the load addr
	call serial_init
	lea rsi, [rel done_msg]
	call serial_write

.hang:
	hlt
	jmp .hang

serial_init:
	mov dx, COM1 + 1
	xor al, al
	out dx, al

	mov dx, COM1 + 3
	mov al, 0x80
	out dx, al

	mov dx, COM1 + 0
	mov al, 0x01
	out dx, al

	mov dx, COM1 + 1
	xor al, al
	out dx, al

	mov dx, COM1 + 3
	mov al, 0x03
	out dx, al

	mov dx, COM1 + 2
	mov al, 0xC7
	out dx, al

	mov dx, COM1 + 4
	mov al, 0x0B
	out dx, al
	ret

serial_write:
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
	ret

section .rodata

done_msg	db 13, 10, "[+] DONE: reached the kernel.", 13, 10, 0

