; scroll_left_pixel
; Shifts the entire display one pixel to the left.
; Pixels flow across byte boundaries via the carry flag.
; A zero pixel is injected at column 255 of each row.
; Destroys: A, B, D, H, L.
scroll_left_pixel:
    LD   HL, $4000         ; start of display
    LD   D, 192            ; 192 pixel rows
slp_row:
    PUSH HL                ; save row start for the advance step below
    LD   A, L
    ADD  A, 31             ; point to the last byte of this row
    LD   L, A
    OR   A                 ; clear carry: inject 0 pixel at right edge
    LD   B, 32             ; 32 bytes per row
slp_byte:
    RL   (HL)              ; CF -> bit 0 (right), old bit 7 -> CF
    DEC  L
    DJNZ slp_byte
    POP  HL                ; restore row start
    ; Advance HL to the next pixel row
    LD   A, H
    AND  $07
    CP   $07
    JR   Z, slp_cross
    INC  H
    JR   slp_dec
slp_cross:
    LD   A, H
    AND  $F8
    LD   H, A
    LD   A, L
    ADD  A, $20
    LD   L, A
    JR   NC, slp_dec
    LD   A, H
    ADD  A, $08
    LD   H, A
slp_dec:
    DEC  D
    JR   NZ, slp_row
    RET
