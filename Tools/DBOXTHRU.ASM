; Jerome Shidel, 2018 Public Domain

; NASM for DOS

; Simple file based Standard I/O passthrough program to test command line
; I/O redirection. (Works in DOSBox)

use16
cpu 8086
org 0x100

    mov     cx, 2048    ; Maximum number of characters to process

StdUpperCase:
    push    cx

    mov     ah, 0x0b    ; DOS Check Standard Input Status
    int     0x21
    cmp     al, 0x00    ; 0x00 = no character available, 0xff = present.
    je      NoInput
    mov     ah, 0x3f
    mov     bx, 0x0000
    mov     cx, 0x0001
    mov     dx, Buffer
    int     0x21
    jc      NoInput
    cmp     ax, 0x0001   ; Bytes read
    jne     NoInput


    mov     dl, [Buffer]
    cmp     dl, 0x7a    ; if dl > 'z' Don't case shift
    jg      NoUpCase
    cmp     dl, 0x60    ; if dl < 'a' Don't case shift
    jng     NoUpCase
    sub     dl, 0x20
NoUpCase:

    mov     ah, 0x02    ; DOS Write DL character to STDOUT.
    int     0x21

    pop     cx          ; Check if Maximum character count reached.
    loop    StdUpperCase
    jmp     Done

NoInput:
    pop     cx

Done:
    mov     ax, 0x4c00  ; DOS Terminate, no error code
    int     0x21

Buffer:
    db      0
