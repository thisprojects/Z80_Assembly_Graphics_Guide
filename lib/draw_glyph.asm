; draw_glyph
; Draw one 8x8 glyph into a character cell, replacing whatever was there.
; Input:  DE = pointer to 8 glyph bytes (top scan line first)
;         B  = character row    (0–23)
;         C  = character column (0–31)
; Output: none
; Destroys: A, B, D, E, H, L
draw_glyph:
    LD   A, B
    AND  %00011000         ; TT field of the row: 0, 8 or 16
    OR   %01000000         ; H = 010TT000  (scan line 0)
    LD   H, A
    LD   A, B
    AND  %00000111         ; RRR = row within its third
    RRCA                   ; }
    RRCA                   ; } rotate right 3 = shift left 5: A = RRR00000
    RRCA                   ; }
    OR   C                 ; add the column: A = RRRCCCCC
    LD   L, A
    LD   B, 8              ; eight scan lines per cell
dg_loop:
    LD   A, (DE)           ; next glyph byte
    LD   (HL), A           ; write it to the current scan line
    INC  DE
    INC  H                 ; next scan line (safe: stays inside one cell)
    DJNZ dg_loop
    RET
