; draw_sprite_masked_buf
; Draw a masked, character-aligned sprite into an off-screen display buffer.
; Identical to draw_sprite_masked except that the address is moved into the
; buffer by adding draw_offset to the high byte of the display address.
;
;   draw_offset = $00  draw straight to the screen at $4000
;   draw_offset = $60  draw to a buffer at $A000   (48K double buffering)
;   draw_offset = $80  draw to bank 7 at $C000     (128K page flipping)
;
; Input:  B  = y (0–191)   C = x (multiple of 8)
;         IX = masked sprite descriptor (see draw_sprite_masked)
; Destroys: A, B, C, D, E, H, L, IX
draw_sprite_masked_buf:
    LD   A, (IX+0)
    OR   A                 ; height = 0?
    RET  Z                 ; nothing to draw
    LD   (dmb_rows), A
    LD   A, (IX+1)
    LD   (dmb_width), A
    INC  IX                ; skip height byte
    INC  IX                ; skip width byte

    CALL calc_pixel_addr   ; HL = screen address of (y, x)
    LD   A, (draw_offset)
    ADD  A, H              ; move the address into the buffer
    LD   H, A

dmb_row_loop:
    PUSH HL                ; save start-of-row address
    LD   A, (dmb_width)
    LD   B, A
dmb_col_loop:
    LD   A, (IX+0)         ; AND mask byte
    AND  (HL)              ; punch a hole in the background
    LD   D, A
    INC  IX
    LD   A, (IX+0)         ; OR pixel byte
    OR   D                 ; fill the hole with sprite pixels
    LD   (HL), A
    INC  IX
    INC  L
    DJNZ dmb_col_loop
    POP  HL

    LD   A, H              ; step down one pixel row (same logic as draw_sprite)
    AND  $07
    CP   $07
    JR   Z, dmb_cross
    INC  H
    JR   dmb_row_dec
dmb_cross:
    LD   A, H
    AND  $F8               ; back to scan line 0
    LD   H, A
    LD   A, L
    ADD  A, $20            ; next character row within the third
    LD   L, A
    JR   NC, dmb_row_dec
    LD   A, H
    ADD  A, $08            ; next third
    LD   H, A
dmb_row_dec:
    LD   A, (dmb_rows)
    DEC  A
    LD   (dmb_rows), A
    JR   NZ, dmb_row_loop
    RET

draw_offset: DB $60        ; added to H: where the "screen" being drawn to lives
dmb_rows:    DB 0
dmb_width:   DB 0
