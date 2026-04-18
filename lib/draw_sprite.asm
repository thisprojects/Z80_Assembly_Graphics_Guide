; draw_sprite
; Draw an unmasked, character-aligned sprite.
; Sprite pixels are OR'd into the display file — existing set pixels are
; preserved where the sprite byte has a 0 bit; existing clear pixels are
; forced on where the sprite byte has a 1 bit.
;
; Input:  B  = y          (pixel row,    0–191)
;         C  = x          (pixel column, must be a multiple of 8)
;         IX = pointer to sprite descriptor:
;                DB height       ; number of pixel rows    (1–191)
;                DB width_bytes  ; bytes per row            (1–32)
;                DB ...          ; pixel data, row-major,
;                                ;   MSB (bit 7) = left-most pixel in byte
; Destroys: A, B, C, D, E, H, L, IX
draw_sprite:
    LD   A, (IX+0)         ; read height from sprite header
    LD   (ds_rows), A      ; store as row-down counter
    LD   A, (IX+1)         ; read byte-width from sprite header
    LD   (ds_width), A
    INC  IX                ; advance past height byte
    INC  IX                ; advance past width byte — IX now → first pixel byte

    CALL calc_pixel_addr   ; HL = display-file address of (y,x)
                           ; A  = bitmask for pixel x (unused: x is byte-aligned)

ds_row_loop:
    PUSH HL                ; save start-of-row display address

    ; — Copy one row of sprite bytes, OR-ing into the display file —
    LD   A, (ds_width)
    LD   B, A              ; B = byte counter for this row
ds_col_loop:
    LD   A, (IX+0)         ; fetch next sprite pixel byte
    OR   (HL)              ; set sprite pixels, leave untouched background pixels
    LD   (HL), A
    INC  IX                ; advance sprite-data pointer to next byte
    INC  L                 ; next display byte on same row
                           ; (INC L is safe: all bytes on one row share the same H)
    DJNZ ds_col_loop

    POP  HL                ; restore start-of-row address (L = original column)

    ; — Advance HL to the next pixel row using the ZX Spectrum row-step logic —
    LD   A, H
    AND  $07               ; isolate LLL (scan-line field, H bits 2:0)
    CP   $07               ; are we at the last scan line of this character row?
    JR   Z, ds_cross
    INC  H                 ; not last: increment scan-line field
    JR   ds_row_dec

ds_cross:
    ; LLL was 7 — wrap scan line to 0 and step character-row field RRR in L
    LD   A, H
    AND  $F8               ; clear LLL → scan line returns to 0 within the row
    LD   H, A
    LD   A, L
    ADD  A, $20            ; step RRR field (L bits 7:5 = character row within third)
    LD   L, A
    JR   NC, ds_row_dec    ; no carry: still within the same third of the screen
    LD   A, H
    ADD  A, $08            ; carry: step TT field (H bits 4:3) — next screen third
    LD   H, A

ds_row_dec:
    LD   A, (ds_rows)
    DEC  A
    LD   (ds_rows), A
    JR   NZ, ds_row_loop
    RET

ds_rows:  DB 0             ; rows remaining (decremented each iteration)
ds_width: DB 0             ; bytes per row (constant for the duration of the call)
