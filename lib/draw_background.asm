; draw_background
; Fills the display with horizontal stripes: even character rows all $FF
; (all pixels = ink colour), odd rows all $00 (all pixels = paper colour).
draw_background:
    LD   B, 0              ; B = character row index (0..23)
db_next_row:
    LD   A, B
    AND  1
    JR   NZ, db_is_odd
    LD   A, $FF
    JR   db_have_val
db_is_odd:
    XOR  A
db_have_val:
    LD   (db_val), A

    ; H_base = $40 | (TT<<3).  B AND $18 gives TT<<3 for B in 0..23.
    LD   A, B
    AND  $18               ; bits 4:3 of B = TT<<3  (0, 8, or 16)
    OR   $40
    LD   (db_hbase), A

    ; L_start = (B AND 7) << 5 = RRR * 32
    LD   A, B
    AND  $07
    ADD  A, A
    ADD  A, A
    ADD  A, A
    ADD  A, A
    ADD  A, A               ; five doublings: A = RRR << 5
    LD   (db_lstart), A

    LD   C, 0              ; C = LLL (0..7), reset for each new character row
db_scan:
    LD   A, (db_hbase)
    ADD  A, C              ; H = H_base + LLL
    LD   H, A
    LD   A, (db_lstart)
    LD   L, A
    LD   A, (db_val)
    PUSH BC                ; DJNZ overwrites B; save B=char-row and C=LLL
    LD   B, 32
db_fill:
    LD   (HL), A
    INC  L
    DJNZ db_fill
    POP  BC                ; restore B=char-row, C=LLL
    INC  C
    LD   A, C
    CP   8
    JR   NZ, db_scan

    INC  B
    LD   A, B
    CP   24
    JR   NZ, db_next_row
    RET

db_val:    DB 0
db_hbase:  DB 0
db_lstart: DB 0
