; draw_sprite_clipped
; Draw a character-aligned sprite with bottom and right edge clipping.
; Rows that would fall below y=191 and byte-columns that would extend past
; column 31 are silently trimmed before drawing begins.
; If y >= 192 the sprite is entirely off-screen and is not drawn.
; Left and top edge clipping are not supported: x must be 0–248 (multiple of
; 8) and y must be 0–191 before calling.
;
; Input:  B  = y  (pixel row,    0–191)
;         C  = x  (pixel column, multiple of 8, 0–248)
;         IX = pointer to sprite descriptor (same format as draw_sprite)
; Destroys: A, B, C, D, E, H, L, IX
draw_sprite_clipped:
    ; — Return immediately if the sprite starts below the screen —
    LD   A, B
    CP   192
    RET  NC

    ; — Clip height: limit to rows that fit below y —
    LD   A, (IX+0)         ; full sprite height
    LD   D, A              ; D = full height
    LD   A, 192
    SUB  B                 ; available rows from y to the screen bottom (192 - y)
    CP   D                 ; available >= full height?
    JR   NC, dsc_h_ok
    LD   D, A              ; no: use only the available rows
dsc_h_ok:
    LD   A, D
    LD   (dsc_rows), A

    ; — Clip width: limit to byte-columns that fit to the right of x —
    LD   A, (IX+1)         ; full sprite width in bytes
    LD   E, A              ; E = full width (kept for skip-count calculation below)
    LD   A, C
    RRCA
    RRCA
    RRCA
    AND  $1F               ; start byte-column = x / 8  (0–31)
    LD   D, A
    LD   A, 32
    SUB  D                 ; byte-columns available to the right of start_col
    CP   E                 ; available >= full width?
    JR   NC, dsc_w_ok
    LD   (dsc_width), A    ; clip: store only the available column count
    LD   D, A              ; D = clipped width
    LD   A, E
    SUB  D                 ; skip = full_width - clipped_width (bytes per row to skip)
    LD   (dsc_skip), A
    JR   dsc_draw
dsc_w_ok:
    LD   A, E
    LD   (dsc_width), A
    XOR  A
    LD   (dsc_skip), A     ; no bytes to skip on the right

dsc_draw:
    LD   A, (dsc_rows)
    OR   A
    RET  Z                 ; zero rows after clipping: nothing to draw

    INC  IX                ; skip height byte in header
    INC  IX                ; skip width byte  in header — IX → first pixel byte
    CALL calc_pixel_addr   ; HL = display-file address of (y, x)

dsc_row_loop:
    PUSH HL                ; save start-of-row display address

    ; — Draw one row's visible bytes —
    LD   A, (dsc_width)
    LD   B, A
dsc_col_loop:
    LD   A, (IX+0)
    OR   (HL)
    LD   (HL), A
    INC  IX
    INC  L
    DJNZ dsc_col_loop

    ; — Advance IX past the right-clipped bytes so it reaches the next row —
    LD   A, (dsc_skip)
    OR   A
    JR   Z, dsc_row_adv    ; nothing clipped: no skip needed
    LD   B, A
dsc_skip_loop:
    INC  IX
    DJNZ dsc_skip_loop

dsc_row_adv:
    POP  HL                ; restore start-of-row address

    ; — Advance HL to the next pixel row —
    LD   A, H
    AND  $07               ; isolate LLL (scan-line field)
    CP   $07
    JR   Z, dsc_cross
    INC  H
    JR   dsc_row_dec
dsc_cross:
    LD   A, H
    AND  $F8               ; clear LLL
    LD   H, A
    LD   A, L
    ADD  A, $20            ; step RRR (character-row field)
    LD   L, A
    JR   NC, dsc_row_dec
    LD   A, H
    ADD  A, $08            ; step TT (screen-third field)
    LD   H, A
dsc_row_dec:
    LD   A, (dsc_rows)
    DEC  A
    LD   (dsc_rows), A
    JR   NZ, dsc_row_loop
    RET

dsc_rows:  DB 0            ; row count after bottom clipping
dsc_width: DB 0            ; byte-columns per row after right clipping
dsc_skip:  DB 0            ; bytes to advance IX past at end of each row
