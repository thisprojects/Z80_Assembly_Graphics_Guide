; draw_sprite_masked
; Draw a masked, character-aligned sprite.
; For every byte position the display is updated as:
;
;   display_byte = (display_byte AND mask_byte) OR pixel_byte
;
; AND mask convention:
;   bit = 0  →  opaque:      this bit position belongs to the sprite
;   bit = 1  →  transparent: the existing background pixel is preserved
;
; OR pixel convention (applies only to opaque bit positions):
;   bit = 1  →  ink (pixel set)
;   bit = 0  →  paper (pixel cleared)
;
; Input:  B  = y          (pixel row,    0–191)
;         C  = x          (pixel column, must be a multiple of 8)
;         IX = pointer to masked sprite descriptor:
;                DB height       ; number of pixel rows
;                DB width_bytes  ; bytes per row
;                ; For every byte position, two bytes in order: AND then OR.
;                ; All byte pairs for row 0 come first, then row 1, and so on.
;                DB and_byte, or_byte [, and_byte, or_byte, ...]  ; row 0
;                DB ...                                            ; row 1 …
; Destroys: A, B, C, D, E, H, L, IX
draw_sprite_masked:
    LD   A, (IX+0)
    OR   A                 ; height = 0?
    RET  Z                 ; nothing to draw (else DEC would wrap to 255 rows)
    LD   (dm_rows),  A
    LD   A, (IX+1)
    LD   (dm_width), A
    INC  IX                ; skip height byte
    INC  IX                ; skip width byte — IX now → first AND byte of row 0

    CALL calc_pixel_addr   ; HL = display-file address of (y,x)

dm_row_loop:
    PUSH HL                ; save start-of-row display address

    LD   A, (dm_width)
    LD   B, A              ; B = byte counter for this row
dm_col_loop:
    LD   A, (IX+0)         ; AND mask byte
    AND  (HL)              ; punch a hole: clear the opaque sprite area in the display
    LD   D, A              ; preserve the masked result in D
    INC  IX                ; advance to the paired OR pixel byte
    LD   A, (IX+0)         ; OR pixel byte
    OR   D                 ; paint the sprite: fill the hole with sprite pixels
    LD   (HL), A           ; write the combined result back to the display
    INC  IX                ; advance to the AND byte of the next column
    INC  L                 ; next display column (INC L safe within a row)
    DJNZ dm_col_loop

    POP  HL                ; restore start-of-row address

    ; — Advance HL to the next pixel row (identical logic to draw_sprite) —
    LD   A, H
    AND  $07               ; isolate LLL (scan-line field)
    CP   $07
    JR   Z, dm_cross
    INC  H
    JR   dm_row_dec
dm_cross:
    LD   A, H
    AND  $F8               ; clear LLL
    LD   H, A
    LD   A, L
    ADD  A, $20            ; step RRR (character-row field)
    LD   L, A
    JR   NC, dm_row_dec
    LD   A, H
    ADD  A, $08            ; step TT (screen-third field)
    LD   H, A
dm_row_dec:
    LD   A, (dm_rows)
    DEC  A
    LD   (dm_rows), A
    JR   NZ, dm_row_loop
    RET

dm_rows:  DB 0             ; rows remaining
dm_width: DB 0             ; bytes per row
