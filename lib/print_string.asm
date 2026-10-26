; print_string
; Print a zero-terminated string, wrapping to the next row after column 31.
; Input:  HL = pointer to the string (bytes 32–127, ended by a 0 byte)
;         B  = starting character row    (0–23)
;         C  = starting character column (0–31)
; Output: none
; Destroys: A, B, C, D, E, H, L
; The caller must keep the text on the screen: rows beyond 23 are not checked.
; Requires print_char.asm and draw_glyph.asm.
print_string:
    LD   A, (HL)
    OR   A
    RET  Z                 ; zero byte: end of string
    INC  HL
    PUSH HL                ; print_char destroys HL
    PUSH BC                ; ... and B
    CALL print_char
    POP  BC
    POP  HL
    INC  C                 ; next column
    LD   A, C
    CP   32
    JR   C, print_string   ; still on this row
    LD   C, 0              ; wrap to the start of the next row
    INC  B
    JR   print_string
