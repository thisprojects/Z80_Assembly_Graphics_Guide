; build_row_table
; Fill a 192-entry table of display-file row addresses.
; Entry y (two bytes, low byte first) is the address of the first byte of
; pixel row y.  Needs 384 bytes at row_table, which the program must define
; with EQU (or allocate itself) before including this file.
; Input:  none      Output: none
; Destroys: A, B, C, D, E, H, L
; Requires calc_pixel_addr.asm.
build_row_table:
    LD   DE, row_table     ; DE = where the next entry goes
    XOR  A
    LD   (brt_y), A
brt_loop:
    LD   A, (brt_y)
    LD   B, A              ; B = y
    LD   C, 0              ; C = x = 0
    PUSH DE
    CALL calc_pixel_addr   ; HL = address of the start of row y
    POP  DE
    EX   DE, HL            ; HL = table pointer, DE = row address
    LD   (HL), E           ; low byte
    INC  HL
    LD   (HL), D           ; high byte
    INC  HL
    EX   DE, HL            ; DE = table pointer again
    LD   A, (brt_y)
    INC  A
    LD   (brt_y), A
    CP   192
    JR   NZ, brt_loop
    RET
brt_y: DB 0
