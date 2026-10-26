; copy_cells
; Copy a rectangle of character cells from the off-screen buffer to the screen.
; Input:  B = first character row     (0–23)
;         C = first character column  (0–31)
;         D = height in character rows (1–24)
;         E = width in cells           (1–32)
; Output: none
; Destroys: A, B, C, D, E, H, L
; Requires draw_sprite_masked_buf.asm (for draw_offset).
copy_cells:
    LD   A, E
    LD   (cc_width), A
    LD   A, D
    LD   (cc_rows), A

    LD   A, B              ; HL = screen address of the first cell, scan line 0
    AND  %00011000
    OR   %01000000
    LD   H, A
    LD   A, B
    AND  %00000111
    RRCA
    RRCA
    RRCA
    OR   C
    LD   L, A

cc_row:
    LD   B, 8              ; eight scan lines per character row
cc_scan:
    PUSH BC
    PUSH HL                ; remember this scan line's screen address
    LD   D, H
    LD   E, L              ; DE = destination (screen)
    LD   A, (draw_offset)
    ADD  A, H
    LD   H, A              ; HL = source (buffer)
    LD   A, (cc_width)
    LD   C, A
    LD   B, 0
    LDIR                   ; copy one scan line of the rectangle
    POP  HL
    POP  BC
    INC  H                 ; next scan line of this character row
    DJNZ cc_scan

    LD   A, H              ; eight INC H have moved us to the next 8-block:
    SUB  8                 ; step back to scan line 0 of this character row
    LD   H, A
    LD   A, L
    ADD  A, $20            ; next character row
    LD   L, A
    JR   NC, cc_same_third
    LD   A, H
    ADD  A, 8              ; crossed into the next third
    LD   H, A
cc_same_third:
    LD   A, (cc_rows)
    DEC  A
    LD   (cc_rows), A
    JR   NZ, cc_row
    RET

cc_width: DB 0
cc_rows:  DB 0
