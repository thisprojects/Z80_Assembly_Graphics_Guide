; scroll_right_pixel
; Shifts the entire display one pixel to the right.
; Pixels flow across byte boundaries via the carry flag.
; A zero pixel is injected at column 0 of each row.
; Destroys: A, B, D, H, L.
scroll_right_pixel:
    LD   HL, $4000         ; start of display
    LD   D, 192            ; 192 pixel rows
srp_row:
    PUSH HL                ; save row start for the advance step below
    OR   A                 ; clear carry: inject 0 pixel at left edge
    LD   B, 32             ; 32 bytes per row
srp_byte:
    RR   (HL)              ; CF -> bit 7 (left), old bit 0 -> CF
    INC  L
    DJNZ srp_byte
    POP  HL                ; restore row start
    ; Advance HL to the next pixel row
    LD   A, H
    AND  $07
    CP   $07
    JR   Z, srp_cross
    INC  H
    JR   srp_dec
srp_cross:
    LD   A, H
    AND  $F8
    LD   H, A
    LD   A, L
    ADD  A, $20
    LD   L, A
    JR   NC, srp_dec
    LD   A, H
    ADD  A, $08
    LD   H, A
srp_dec:
    DEC  D
    JR   NZ, srp_row
    RET
