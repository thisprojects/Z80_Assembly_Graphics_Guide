; fill_screen_attr_fast
; Same job as fill_screen_attr, with the inner loop unrolled eight times.
; Input:  A = attribute byte
; Output: none
; Destroys: B, HL
fill_screen_attr_fast:
    LD   HL, $5800        ; start of attribute file
    LD   B, 96            ; 96 passes of 8 bytes = 768 bytes
fsaf_loop:
    REPT 8
    LD   (HL), A
    INC  HL
    ENDM
    DJNZ fsaf_loop
    RET
