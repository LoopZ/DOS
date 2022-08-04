; Copyright 2015 Jerome Shidel
;
;   Licensed under the Apache License, Version 2.0 (the "License");
;   you may not use this file except in compliance with the License.
;   You may obtain a copy of the License at
;
;       http://www.apache.org/licenses/LICENSE-2.0
;
;   Unless required by applicable law or agreed to in writing, software
;   distributed under the License is distributed on an "AS IS" BASIS,
;   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;   See the License for the specific language governing permissions and
;   limitations under the License.

; NASM for DOS

; A little more secure way of validating a user password.

; This is only a demonstration of several security techniques for password
; verification. it should not be used as-is in a real world environment.
; Several things this program does are extremely bad ideas for a secure
; system. That includes, but is not limited to, providing the program with
; the username and password at runtime from the command-line. No actual
; password hashing. Just to mention a few things. However, it does do
; several things that would be required for a secure password system.
; Things like, fixed execution loop processing to prevent side-channel
; attacks. Wiping user data to prevent leakage when program exits.
; Delayed prompting and maximum number attempts. etc.

use16       ; 16-bit 286 assembly code

; some macros

; Push multiple registers (ex. pushy AX, BX, CX)
%imacro  pushy 1-*
  %rep  %0
        push    %1
  %rotate 1
  %endrep
%endmacro

; Pop multiple registers (ex. poppy CX, BX, AX)
%imacro  poppy 1-*
  %rep  %0
        pop    %1
  %rotate 1
  %endrep
%endmacro

; return if zero flag set
%imacro retz 0
        jnz %%notzero
        ret
    %%notzero:
%endmacro

; beginning of program
org 100h

global  _start

section .code

_start:

; start by parsing command line parameters
    cld
    xor     BX, BX
    mov     SI, 0081h
    mov     CX, 00FFh - 0081h
parse:
    lodsb
    cmp     al, 0dh
    je      parse_done
    cmp     al, 20h
    je      parse_option_done
    cmp     BX, 0
    je      parse_error
    cmp     DX, 0
    je      way_too_big
    dec     DX
    stosb
    loop  parse

parse_done:
    ; wipe command line parameters
    cld
    mov     DI, 0081h
    mov     CX, 00FFh - 0081h
    xor     AX, AX
parse_cleanup_loop:
    stosb
    loop    parse_cleanup_loop

    ; check BX for count of params. username & password. must be 2.
    cmp     BX, 2
    jne     parse_error
    jmp     welcome

parse_option_done:
    inc     BX
    ; Load DX with max length allowed for parameter. At present all are
    ; the same at 64 bytes (plus a required null terminator)
    mov     DX, pswdinputend - pswdinput - 1
    mov     DI, username
    cmp     BX, 1
    je      parse
    mov     DI, pswdhash
    cmp     BX, 2
    je      parse

parse_error:
    mov     SI, msg_error_parse
    call    write
    jmp     exit_error

way_too_big:
    cmp     bx, 1
    jg      way_too_big_pswd
    mov     SI, msg_error_too_big_user
    call    write
    jmp     exit_error

way_too_big_pswd:
    mov     SI, msg_error_too_big_pswd
    call    write
    jmp     exit_error


; print welcome message and prompt for password
welcome:
    mov     SI, greetings
    call    write
    mov     SI, username
    call    write
    mov     SI, prompt_first
    call    write

    mov     AL, [max_tries]

; Main password query loop
input_loop:
    push    AX
    call    read
    mov     AL, [pswdinput]
    cmp     AL, 0
    je      password_timeout
    call    hash
    call    compare
    cmp     AX, 0
    je      input_valid
    call    wait_a_little
    pop     AX
    dec     AL
    cmp     AL, 0
    je      password_failure
    push    AX
    mov     SI, prompt_retry
    call    write
    pop     AX
    jmp     input_loop

; received matching password, need to pop ax
input_valid:
    pop     AX
    jmp     password_success

; a timeout occurred. too long between keypresses
password_timeout:
    mov     SI, msg_error_timeout
    call    write
    jmp     exit_error

; wrong password provided
password_failure:
    mov     SI, msg_error_failed
    call    write
    jmp     exit_error

; print good password message
password_success:
    mov     SI, msg_success
    call    write
    jmp     exit_good

; write an ASCIIZ string to dos console
write:
    cld
    mov     ah, 06h
write_loop:
    lodsb
    test    al, al
    retz
    mov     dl, al
    int     21h
    jmp     write_loop

; get input from user, with keystroke timeout measured by system timer
; ticks.
read:
    cld
    mov     DI, pswdinput
    mov     CX, pswdinputend - pswdinput
    xor     AL, AL
    push    DI
read_clear:
    stosb
    loop    read_clear
    pop     DI

    pushy   ES, SI
    les     BX, [timer]

read_char:
    mov     CX, [timeout]
    xor     AX, AX
read_char_loop:
    mov     DX, [ES:BX]
    cmp     AX, DX
    je      read_char_get
    dec     CX
    cmp     CX, 0
    je      read_char_timout
    mov     AX, DX
read_char_get:
    pushy   AX, DX
    mov     AH, 06h
    mov     DL, 0FFh
    int     21h
    jz      read_char_none
    cmp     AL, 00h
    jne     read_char_simple
    int     21h
    jmp     read_char_none

read_char_simple:
    cmp     AL, 0dh
    je      read_done
    cmp     DI, pswdinputend - 1
    jge     read_char_ignore
    mov     [DI], AL
    INC     DI

read_char_ignore:
    ; if the next two instructions are uncommented password will
    ; be echoed to console. REALLY BAD IDEA!
    ; mov   DL, AL
    ; int   21h

    poppy   DX, AX
    jmp     read_char

read_char_none:
    poppy   DX, AX
    jmp     read_char_loop

read_char_timout:
    poppy   SI, ES
    mov     SI, crlf
    call    write
    mov     DI, pswdinput
    xor     AL, AL
    mov     [DI], AL
    ret

read_done:
    cmp     DI, pswdinput
    jne     read_done_skip
    mov     AL, 0dh
    mov     [DI], AL
read_done_skip:
    poppy   DX, AX, SI, ES
    mov     SI, crlf
    call    write
    ret

; if this was meant to be secure, it would hash the input here.
hash:
    ret

; Fixed time compare. There may be a better way of doing this.
; But, to prevent side channel timing attacks, this must always
; take the exact same amount of time to process.
compare:
	mov		SI, pswdhash
	mov		DI, pswdinput
	mov		CX, pswdinputend - pswdinput
	xor		AX, AX
compare_loop:
	mov		DL, [SI]
	mov		DH, [DI]
	not 	DL
	xor		DH, DL
	not		DH
	or		AL, DH
	inc		SI
	inc		DI
	loop	compare_loop
	; any bit not zero results in AX being non-zero on return
	ret

; basically, it waits for system timer tick to change a given number
; of times.
wait_a_little:
    mov     CX, [delayticks]        ; number of ticks to delay
    pushy   ES, SI
    les     BX, [timer]             ; load pointer to tick count into ES:BX
wait_a_little_read:
    mov     AX, [ES:BX]             ; get current ticks into AX
wait_a_little_wait:
    mov     DX, [ES:BX]             ; get current ticks into DX
    cmp     AX, DX
    je      wait_a_little_wait      ; if AX = DX get DX again
    loop    wait_a_little_read      ; dec CX, then get AX & DX again
    poppy   SI, ES
    ret

; Exit to dos, with error code
exit_error:
    mov     AL, 1
    jmp     exit_cleanup

; Exit to dos, with no error code
exit_good:
    mov     AL, 0

; perform data cleanup and exit to dos
exit_cleanup:
    push    AX
    cld
    ; wipe user data
    mov     DI, startofdata
    mov     CX, endofdata - startofdata
    xor     AX, AX
exit_cleanup_loop:
    stosb
    loop    exit_cleanup_loop
    pop     AX
    mov     AH, 4Ch
    int     21h

section .data

; number of times to ask for password before failure
max_tries:
    DB 3

; number of 55ms ticks to wait when password is wrong
delayticks:
    DW 36   ; about 2 seconds

; number of 55ms timer ticks to wait between keystrokes before timing out.
timeout:
    DW 91   ; about 5 seconds

; pointer to system timer tick count
timer:
    DW  006Ch,0040h

; error messages and other asciiz strings
msg_error_parse:
    DB "Invalid number of command line parameters.",13,10
    DB "Please enter ASKPSWD username password",13,10
    DB "(spaces are not permitted)",13,10,0

msg_error_too_big_user:
    DB "Sorry, but that username is too long.",13,10,0

msg_error_too_big_pswd:
    DB "Sorry, but that password is too large.",13,10,0

msg_error_timeout:
    DB  "Sorry, but you session has timed out.",13,10,0

msg_error_failed:
    DB  "Sorry, but you failed to enter the correct password.",13,10,0

msg_success:
    DB  "Congratulations, you have entered the correct password.",13,10,0

crlf:
    DB  13,10,0
greetings:
    DB "Greetings ",0
prompt_first:
    DB ", please enter your password? ",0
prompt_retry:
    DB  "Incorrect. Please try again? ", 0

; user data
startofdata:
username:
    TIMES 65 DB 0
pswdhash:
    TIMES 65 DB 0
pswdinput:
    TIMES 65 DB 0
pswdinputend:
endofdata:
