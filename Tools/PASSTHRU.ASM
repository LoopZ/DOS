; Jerome Shidel, 2018 Public Domain

; NASM for DOS

; Simple Standard I/O passthrough program to test command line I/O redirection.
; Does not work properly under DOSBox

use16
cpu 8086
org 0x100

StdPassThru:
	mov		ah, 0x0b
	int		0x21
	cmp		al, 0x00
	je 		NoInput
	mov		ah, 0x08
	int		0x21
	mov		ah, 0x02
	mov     dl, al
	int		0x21
	jmp		StdPassThru
NoInput:
    mov     ax, 0x4c00
    int     0x21
