; scroll_up_pixel
; Scrolls the entire display up by one pixel row (one scan line).
; Pixel row 0 is lost; the new bottom row (y=191) is filled with zeros.
; Destroys: A, B, C, D, E, H, L.
scroll_up_pixel:
    LD   DE, $4000         ; dest: pixel row 0  (TT=0, LLL=0, RRR=0)
    LD   HL, $4100         ; src:  pixel row 1  (TT=0, LLL=1, RRR=0)
    LD   B, 191            ; 191 copies: rows 1..191 -> rows 0..190
sup_loop:
    PUSH BC                ; save row counter -- LDIR overwrites BC
    PUSH HL                ; save source start -- LDIR advances HL
    LD   BC, 32
    LDIR                   ; copy 32 bytes: source row -> dest row
    POP  HL                ; restore source start address
    LD   D, H
    LD   E, L              ; old source becomes next iteration's dest
    ; Advance HL to the next pixel row using the ZX Spectrum row-step logic
    LD   A, H
    AND  $07               ; isolate LLL (scan-line offset field)
    CP   $07
    JR   Z, sup_cross
    INC  H                 ; LLL < 7: step scan-line field in H
    JR   sup_dec
sup_cross:
    LD   A, H
    AND  $F8               ; LLL = 7: clear scan-line field (-> LLL=0)
    LD   H, A
    LD   A, L
    ADD  A, $20            ; step RRR (character-row field in L)
    LD   L, A
    JR   NC, sup_dec
    LD   A, H
    ADD  A, $08            ; carry: step TT (screen-third field in H)
    LD   H, A
sup_dec:
    POP  BC
    DJNZ sup_loop

    ; After the loop DE points to the start of pixel row 191.
    LD   H, D
    LD   L, E
    LD   B, 32
    XOR  A
sup_clr:
    LD   (HL), A
    INC  L
    DJNZ sup_clr
    RET
