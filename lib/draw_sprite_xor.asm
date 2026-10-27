; XOR-erase variant of draw_sprite
; Call once to draw; call again at the same position to erase.
; Input/destroys: same as draw_sprite
; Requires draw_sprite.asm (shares its ds_rows / ds_width variables).
draw_sprite_xor:
    LD   A, (IX+0)
    OR   A
    RET  Z                 ; height = 0: nothing to draw
    LD   (ds_rows), A
    LD   A, (IX+1)
    LD   (ds_width), A
    INC  IX
    INC  IX
    CALL calc_pixel_addr
dsx_row_loop:
    PUSH HL
    LD   A, (ds_width)
    LD   B, A
dsx_col_loop:
    LD   A, (IX+0)
    XOR  (HL)              ; toggle instead of set — call twice to restore
    LD   (HL), A
    INC  IX
    INC  L
    DJNZ dsx_col_loop
    POP  HL

    ; Advance HL to the next pixel row (same logic as draw_sprite)
    LD   A, H
    AND  $07
    CP   $07
    JR   Z, dsx_cross
    INC  H
    JR   dsx_row_dec

dsx_cross:
    LD   A, H
    AND  $F8
    LD   H, A
    LD   A, L
    ADD  A, $20
    LD   L, A
    JR   NC, dsx_row_dec
    LD   A, H
    ADD  A, $08
    LD   H, A

dsx_row_dec:
    LD   A, (ds_rows)
    DEC  A
    LD   (ds_rows), A
    JR   NZ, dsx_row_loop
    RET
