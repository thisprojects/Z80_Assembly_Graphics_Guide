; draw_circle
; Draw a circle using the midpoint algorithm.
; Input:  B = cy  (centre y, 0-191)
;         C = cx  (centre x, 0-255)
;         D = radius  (must keep centre +/- radius within screen bounds)
; Destroys: A, B, C, D, E, H, L
; The decision variable is 16-bit, so any radius up to 255 is handled.
draw_circle:
    LD   A, B
    LD   (dc_cy), A        ; save centre y
    LD   A, C
    LD   (dc_cx), A        ; save centre x
    LD   A, D              ; radius
    LD   (dc_y),  A        ; y offset starts at radius
    XOR  A
    LD   (dc_x),  A        ; x offset starts at 0

    ; d = 1 - radius  (16-bit signed)
    LD   E, D
    LD   D, 0
    LD   HL, 1
    OR   A
    SBC  HL, DE
    LD   (dc_d),  HL

dc_loop:
    ; while x <= y
    LD   A, (dc_x)
    LD   B, A
    LD   A, (dc_y)
    CP   B                 ; y - x: if x > y, done
    JR   C, dc_done        ; carry set means y < x

    ; plot 8 symmetric pixels
    CALL dc_plot8

    ; x += 1
    LD   A, (dc_x)
    INC  A
    LD   (dc_x), A

    ; if d < 0: d += 2*x + 1
    LD   HL, (dc_d)
    BIT  7, H
    JR   NZ, dc_d_neg

    ; d >= 0: y -= 1,  d += 2*(x-y) + 1
    LD   A, (dc_y)
    DEC  A
    LD   (dc_y), A         ; y -= 1
    LD   E, A
    LD   D, 0              ; DE = new y
    LD   A, (dc_x)
    LD   L, A
    LD   H, 0              ; HL = new x
    OR   A
    SBC  HL, DE            ; HL = x - y  (16-bit signed)
    ADD  HL, HL            ; 2*(x - y)
    INC  HL                ; 2*(x - y) + 1
    LD   DE, (dc_d)
    ADD  HL, DE            ; d += 2*(x-y) + 1
    LD   (dc_d), HL
    JR   dc_loop

dc_d_neg:
    ; HL = d;  d += 2*x + 1
    LD   A, (dc_x)
    LD   E, A
    LD   D, 0
    ADD  HL, DE
    ADD  HL, DE            ; + 2*x
    INC  HL                ; + 1
    LD   (dc_d), HL
    JR   dc_loop

dc_done:
    RET

; dc_plot8 -- plot the 8 symmetric pixels for current (x, y) offsets
; set_pixel destroys all registers, so dc_x and dc_y are reloaded from
; memory before every pixel. D = x offset, E = y offset throughout.
dc_plot8:
    ; (cx+x, cy+y)
    LD   A, (dc_x)
    LD   D, A
    LD   A, (dc_y)
    LD   E, A
    LD   A, (dc_cy)
    ADD  A, E
    LD   B, A
    LD   A, (dc_cx)
    ADD  A, D
    LD   C, A
    CALL set_pixel

    ; (cx-x, cy+y)
    LD   A, (dc_x)
    LD   D, A
    LD   A, (dc_y)
    LD   E, A
    LD   A, (dc_cy)
    ADD  A, E
    LD   B, A
    LD   A, (dc_cx)
    SUB  D
    LD   C, A
    CALL set_pixel

    ; (cx+x, cy-y)
    LD   A, (dc_x)
    LD   D, A
    LD   A, (dc_y)
    LD   E, A
    LD   A, (dc_cy)
    SUB  E
    LD   B, A
    LD   A, (dc_cx)
    ADD  A, D
    LD   C, A
    CALL set_pixel

    ; (cx-x, cy-y)
    LD   A, (dc_x)
    LD   D, A
    LD   A, (dc_y)
    LD   E, A
    LD   A, (dc_cy)
    SUB  E
    LD   B, A
    LD   A, (dc_cx)
    SUB  D
    LD   C, A
    CALL set_pixel

    ; (cx+y, cy+x)  -- x and y roles swap
    LD   A, (dc_x)
    LD   D, A
    LD   A, (dc_y)
    LD   E, A
    LD   A, (dc_cy)
    ADD  A, D
    LD   B, A
    LD   A, (dc_cx)
    ADD  A, E
    LD   C, A
    CALL set_pixel

    ; (cx-y, cy+x)
    LD   A, (dc_x)
    LD   D, A
    LD   A, (dc_y)
    LD   E, A
    LD   A, (dc_cy)
    ADD  A, D
    LD   B, A
    LD   A, (dc_cx)
    SUB  E
    LD   C, A
    CALL set_pixel

    ; (cx+y, cy-x)
    LD   A, (dc_x)
    LD   D, A
    LD   A, (dc_y)
    LD   E, A
    LD   A, (dc_cy)
    SUB  D
    LD   B, A
    LD   A, (dc_cx)
    ADD  A, E
    LD   C, A
    CALL set_pixel

    ; (cx-y, cy-x)
    LD   A, (dc_x)
    LD   D, A
    LD   A, (dc_y)
    LD   E, A
    LD   A, (dc_cy)
    SUB  D
    LD   B, A
    LD   A, (dc_cx)
    SUB  E
    LD   C, A
    CALL set_pixel

    RET

dc_cx: DB 0   ; centre x
dc_cy: DB 0   ; centre y
dc_x:  DB 0   ; current x offset (0 -> radius)
dc_y:  DB 0   ; current y offset (radius -> 0)
dc_d:  DW 0   ; decision variable (16-bit signed)
