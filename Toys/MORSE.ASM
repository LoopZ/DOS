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

; Plays the Moris Code Version of a message.
; Speed and tone Frequency can be adjusted by changing the value near the end.
; Non-Morse code characters are skipped.

org 100h                                ; build in offset for a COM and the PSP
use16                                   ; 16-bit code, also requires a 286 or better
                                        ; for the delay code.

global  _start                          ; Comment this line if you want to use FASM

section .text                           ; Comment this line if you want to use FASM

_start:

    MOV  DI, 0081h                      ; Address of command line in PSP
    MOV  AL, [CS:DI]                    ; get first Command line Character
    CMP  AL, 0Dh                        ; if it's 0Dh, then no command line provided
    JNE  ReadCommandLine                ; otherwise, play that as the message

    MOV  DI, Message                    ; Load Offset of default Message into DI

ReadMessage:                            ; Read message loop
    MOV  AL, [CS:DI]                    ; get next message character
    INC  DI                             ; increment the offset for next time
    CMP  AL, 0                          ; check if we are at the end of the ASCIIZ message
    JE   AstaLaVista                    ; if so, we are done
    CALL NEAR FindCode                  ; go do stuff to with the character in AL
    JMP  ReadMessage                    ; Repeat the loop

ReadCommandLine:                        ; Read command line loop
    INC  DI                             ; increment, offset first char is always a space
    MOV  AL, [CS:DI]                    ; get first/next  character
    CMP  AL, 0dh                        ; check if we are at the end of the command line
    JE   AstaLaVista                    ; if so, we are done
    CALL NEAR FindCode                  ; go do stuff to with the character in AL
    JMP  ReadCommandLine                ; Repeat the loop
    
FindCode:                               
    MOV  BX, Skipper                    ; load offset of Ignored characters into BX
CheckLoop:
    MOV  AH, [CS:BX]                    ; get the first/next one and put it in AH
    CMP  AH, 0                          ; check that we aren't at the end of this ASCIIZ
    JE   FindThis                       ; If we are, then we didn't find a match.
    CMP  AL, AH                         ; check if the MSG char is an ignore char
    JE   FindError                      ; If so, treat it like an unfound letter. Sortof.
    INC  BX                             ; Increment are Skip check char offset
    JMP  CheckLoop                      ; repeat the skip checker

FindThis:                               ; Since, not a skip lets do some stuff
    CMP  AL, 'a'                        
    JB   FindSearch                 
    CMP  AL, 'z'
    JA   FindSearch
    SUB  AL, 20h                        ; convert it to uppercase
FindSearch:
    MOV  BX, Morse                      ; Done with old BX for now, so load MORSE code table
FindLoop:
    MOV  AH, [CS:BX]                    ; Get the first/last letter in the table
    CMP  AH, 0                          
    JE   FindDone                       ; if it is 0, we hit the end. thats bad...
    CMP  AL, AH                         ; check if its the character we are looking for
    JE   Found                          ; Yeah, we found it.
    INC  BX                             ; increment our search offset
    JMP  FindLoop                       ; repeat searching loop
Found:
    PUSH DI                             ; save DI, cause WriteChar will destroy it
    CALL NEAR WriteChar                 ; go do WriteChar
    POP  DI                             ; restore DI
    RETN                                ; go back to Call in ReadMessage
FindError:
    MOV   DL, AL                        ; Put Our char in DL, prepare to display it
    MOV   AH, 02h                       ; DOS function to display chars to stdout
    INT   21h                           ; DO the DOS thing
    JMP   LongSpacer                    ; Go and do a long wait.
FindDone:
    RETN                                ; Go back to ReadMessage
   
WriteChar:
    MOV  DL, [CS:BX]                    ; Take the first/next char in morse table
    INC  BX                             ; get bx ready for later
    CMP  DL, 20h                        ; if it is a space pulled from the table, then...
    JE   WriteDone                      ; it is the end of the letters morse code
    CMP  DL, '.'
    JE   Dot                            ; go do a dot
    CMP  DL, '_'
    JE   Dash                           ; go do a dash
    MOV  AH, 02h
    INT  21h                            ; show only the Letter from the table
    JMP  WriteChar                      ; repeat
WriteDone:
    
    ; after a letter fall through to a medium spacer
    
MediumSpacer:                           ; a 3x Delay, dashes and letter separator
    PUSH  BX
    MOV   AX, [CS:MilliSecs]
    MOV   BX, 03h
    MUL   BX
    CALL NEAR  Delay
    POP   BX
    RETN 

ShortSpacer:                            ; a 1x delay, dots
    PUSH  BX
    MOV   AX, [CS:MilliSecs]
    CALL NEAR  Delay
    POP   BX
    RETN 

LongSpacer:                             ; a 7x delay, between words. But since we already,
    PUSH  BX                            ; did a 3x at the end of the last letter
    MOV   AX, [CS:MilliSecs]            ; we only need 4 more. :)
    MOV   BX, 04h
    MUL   BX
    CALL NEAR  Delay
    POP   BX
    RETN 
        
Dot:                                    ; do a short sound
    PUSH BX
    CALL NEAR ShortTone
    POP  BX
    JMP  WriteChar
    
Dash:                                   ; do a long sound
    PUSH BX
    CALL NEAR LongTone
    POP  BX
    JMP  WriteChar
    
LongTone:                               ; this is the Dash code
    MOV   AX, [CS:Frequency]
    CALL NEAR  Sound
    CALL NEAR  MediumSpacer
    CALL NEAR  NoSound
    CALL NEAR  MediumSpacer
    RETN
    
ShortTone:                              ; this is the Dot code
    MOV   AX, [CS:Frequency]
    CALL NEAR  Sound
    CALL NEAR  ShortSpacer
    CALL NEAR  NoSound
    CALL NEAR  MediumSpacer
    RETN

Sound:                                  ; { AX is Frequency in Hz }
    MOV  CX, AX                         ; We are going to use AX, so save it in CX
    MOV  DX, 0012h                      ; Set DX:AX to 001234DCh
    MOV  AX, 34DCh
    CMP  CX, 0                          ; Check no Frequency, prevent DIV/Zero
    JE   Sound1
    DIV  CX                             ; AX =  DX:AX / CX
    JMP  Sound2
Sound1:
    XOR  AX, AX                         ; No Freq, Clear AX
Sound2:
    PUSH AX                             ; Save AX, we will need it after preparing speaker
    MOV  AL, 10110110b                  ; Code to prepare PC Speaker
    MOV  DX, 043h                       ; Port to initialize
    OUT  DX, AL                         ; Prepare the speaker
    MOV  DX, 042h                       ; Load freq port number
    POP  AX                             ; restore our frequency
    OUT  DX, AL                         ; send first part of freq out the port
    MOV  AL, AH                         
    OUT  DX, AL                         ; send second part of freq, (8-bt port)
    MOV  DX, 061h                       ; Port for not on/off
    IN   AL, DX                         ; Turn on note
    MOV  AL, 03h                        
    OUT  DX, AL
    RETN                                ; all done here, move along
    
NoSound:                                ; { Turn off PC Speaker }
    MOV  DX, 061h                       ; very similar to Sound function
    IN   AL, DX                         ; I've seen this done sever different ways
    MOV  AL, 00000001b                  ; but, I think this is the most reliable way
    OUT  DX, AL                         ; to kill all sounds from the pc speaker.
    MOV  AL, 10110110b                  ; not just turning of notes and such.
    MOV  DX, 043h
    OUT  DX, AL
    MOV  DX, 042h
    MOV  AL, 0h
    OUT  DX, AL
    RETN
    
Delay:                                  ; Event based wait AX Milliseconds.
    MOV  DX, AX                         ; put MilliSecs in DX where it belongs.
    MOV  AX, 8301h                      ; Cancel Event Wait function code
    INT  15h
    MOV  AX, 8300h                      ; Program Event Wait function
    MOV  [CS:DelayFlag], AL             ; Set address for the Flag
    MOV  CX, DX                         ; CX:DX is a "LongInteger" in microseconds.
    SHL  DX, 0Ah                        ; So, do some bit shifting to make it into 
    SHR  CX, 06h                        ; Milliseconds.
    PUSH CS ; { MOV  ES, CS }
    POP  ES ; { MOV  ES, CS }
    MOV  BX, DelayFlag                  ; ES:BX is pointer to location of DelayFlag
    INT  15h
DelayLoop:
    ; Can do stuff here while waiting, 
    ; Maybe test keyboard for an abort.
    ; Do dishes, wash laundry or whatever.
    MOV  AL, [CS:DelayFlag]             ; move the event flag into AL
    TEST AL, 80h                        ; Check it
    JZ   DelayLoop                      ; If still waiting, jump back to DelayLoop
    RETN                                ; I'm done waiting! Go back to whence thous came!

AstaLaVista:
    MOV  AX, 4C00h                      ;  AL = Exit Code 
    INT  21h                            ; Tell DOS to shutdown this program
    
DelayFlag:                          ; Flag used by interrupt driven event wait
    DB  0
    
Frequency:                          ; Frequency to use for PC speaker tones
    DW 750
    
MilliSecs:                          ; millisec time of the shortest interval (a dot)
    DW 75                           ; 50 is pretty quick, 75 is kinda slow, it gets
                                    ; exponentially slower, since all durations are
                                    ; based on multiples of this value.
                                    
Skipper:                            ; ASCIIZ of characters to not lookup.
    DB '_.',20h,0Dh,0Ah,0
    
Morse:                              ; the Moris Code table
    DB 'A._ B_... C_._. D_.. E. F.._. G__. H.... I.. J.___ '
    DB 'K_._ L._.. M__ N_. O___ P.__. Q__._ R._. S... T_ U.._ '
    DB 'V..._ W.__ X_.._ Y_.__ Z__.. '
    DB '1.____ 2..___ 3...__ 4...._ 5..... 6_.... '
    DB '7__... 8___.. 9____. 0_____ ',0

URL:                                ; URL about Morse Code, not used.
    DB 'http://en.wikipedia.org/wiki/Morse_code',0
    
Message:                            ; Message to do Moris Code on if nothing is provided
                                    ; at the command line.
    DB  'This is a very simple COM program.',13,10
    DB  'Really.',13,10,0

