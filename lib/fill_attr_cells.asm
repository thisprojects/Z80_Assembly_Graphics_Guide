; fill_attr_cells
; Set a run of attribute cells on one character row to the same value.
; Input:  A = attribute byte
;         B = character row    (0–23)
;         C = first column     (0–31)
;         E = number of cells  (1–32; 0 does nothing)
; Output: none
; Destroys: A, B, D, E, H, L
fill_attr_cells:
    LD   D, A              ; park the attribute while we test the count
    LD   A, E
    OR   A
    RET  Z                 ; nothing to do (DJNZ with B=0 would loop 256 times)
    LD   A, D
    PUSH AF                ; keep the attribute across the address arithmetic
    LD   H, 0
    LD   L, B
    ADD  HL, HL            ; row * 2
    ADD  HL, HL            ; row * 4
    ADD  HL, HL            ; row * 8
    ADD  HL, HL            ; row * 16
    ADD  HL, HL            ; row * 32
    LD   B, E              ; B = cell count (the row number is no longer needed)
    LD   D, 0
    LD   E, C
    ADD  HL, DE            ; + column
    LD   DE, $5800
    ADD  HL, DE            ; HL = address of the first attribute cell
    POP  AF
fac_loop:
    LD   (HL), A
    INC  HL
    DJNZ fac_loop
    RET
