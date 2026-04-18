; scroll_up_char
; Scrolls the entire ZX Spectrum display up by one character row (8 pixels).
; Character row 0 is lost; the new bottom row (char row 23) is filled with
; zeros.  Attributes at $5800-$5AFF are not touched.
; Destroys: A, B, C, D, E, H, L.
scroll_up_char:
    XOR  A
    LD   (suc_lll), A      ; LLL = 0  (scan-line offset counter)
suc_lll_loop:
    ; -- TT=0: copy char rows 1-7 -> rows 0-6 (224 bytes) --------------------
    ; Within H = $40 | LLL, all 8 char rows of the first third sit at
    ; L = 0, 32, 64 ... 224.  Copying from L=$20 (row 1) to L=$00 (row 0)
    ; for 224 bytes shifts rows 1-7 into rows 0-6 in one LDIR.
    LD   A, (suc_lll)
    OR   $40               ; H = $40 | LLL  (TT=0, this scan-line offset)
    LD   H, A
    LD   L, $20            ; source: char row 1 (RRR=1, L = 1x32 = $20)
    LD   D, H              ; dest same third and LLL
    LD   E, $00            ; dest: char row 0 (RRR=0, L=$00)
    LD   BC, 224           ; 7 rows x 32 bytes per row
    LDIR

    ; -- Cross TT=0->1: char row 8 -> char row 7 ------------------------------
    ; Row 8 is the first row of TT=1 (H = $48|LLL, L=$00).
    ; Row 7 is the last row of TT=0  (H = $40|LLL, L = 7x32 = $E0).
    LD   A, (suc_lll)
    OR   $48               ; source H: TT=1, this LLL
    LD   H, A
    LD   L, $00            ; first byte of TT=1 (RRR=0)
    LD   A, (suc_lll)
    OR   $40               ; dest H: TT=0, this LLL
    LD   D, A
    LD   E, $E0            ; dest: char row 7 (RRR=7, L = $E0)
    LD   BC, 32
    LDIR

    ; -- TT=1: copy char rows 9-15 -> rows 8-14 (224 bytes) ------------------
    LD   A, (suc_lll)
    OR   $48               ; H = $48 | LLL  (TT=1)
    LD   H, A
    LD   L, $20            ; source: char row 9 (RRR=1 within TT=1)
    LD   D, H
    LD   E, $00            ; dest: char row 8
    LD   BC, 224
    LDIR

    ; -- Cross TT=1->2: char row 16 -> char row 15 ----------------------------
    LD   A, (suc_lll)
    OR   $50               ; source H: TT=2, this LLL
    LD   H, A
    LD   L, $00
    LD   A, (suc_lll)
    OR   $48               ; dest H: TT=1, this LLL
    LD   D, A
    LD   E, $E0            ; dest: char row 15 (last row of TT=1)
    LD   BC, 32
    LDIR

    ; -- TT=2: copy char rows 17-23 -> rows 16-22 (224 bytes) ----------------
    LD   A, (suc_lll)
    OR   $50               ; H = $50 | LLL  (TT=2)
    LD   H, A
    LD   L, $20
    LD   D, H
    LD   E, $00
    LD   BC, 224
    LDIR

    ; -- Clear char row 23 (TT=2, RRR=7) for this LLL ------------------------
    LD   A, (suc_lll)
    OR   $50
    LD   H, A
    LD   L, $E0            ; RRR=7, L = 7x32 = $E0
    LD   B, 32
    XOR  A
suc_clr:
    LD   (HL), A
    INC  L
    DJNZ suc_clr

    ; -- Advance to next scan-line offset ------------------------------------
    LD   A, (suc_lll)
    INC  A
    LD   (suc_lll), A
    CP   8
    JR   NZ, suc_lll_loop
    RET

suc_lll: DB 0              ; current scan-line offset (0-7)
