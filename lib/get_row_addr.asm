; get_row_addr
; Look up the display-file address of the start of pixel row y.
; Input:  B  = y (0–191)
; Output: HL = address of the first byte of that row
; Destroys: DE
; Requires the table built by build_row_table.
get_row_addr:
    LD   H, 0
    LD   L, B
    ADD  HL, HL            ; y * 2: each entry is a word
    LD   DE, row_table
    ADD  HL, DE            ; HL = address of the table entry
    LD   E, (HL)
    INC  HL
    LD   D, (HL)
    EX   DE, HL            ; HL = row address
    RET
