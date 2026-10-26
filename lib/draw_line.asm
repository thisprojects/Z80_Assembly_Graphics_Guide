; draw_line
; Draw a line from (x1,y1) to (x2,y2) using Bresenham's algorithm.
; Input:  B = y1  (0–191)    C = x1  (0–255)
;         D = y2  (0–191)    E = x2  (0–255)
; The error term is 16-bit, so any line on the screen is handled.
; Output: none    Destroys: A, B, C, D, E, H, L
draw_line:
    LD   A, C
    LD   (dl_x),  A         ; x = x1
    LD   A, B
    LD   (dl_y),  A         ; y = y1
    LD   A, E
    LD   (dl_x2), A         ; target x2
    LD   A, D
    LD   (dl_y2), A         ; target y2

    ; dx = |x2-x1|,  sx = +1 or $FF (-1)
    ; Compare with CP so the full 0–255 range is handled without sign issues.
    LD   A, E
    SUB  C                  ; A = x2 - x1, carry set if x2 < x1
    JR   NC, .dx_pos
    NEG                     ; make positive for dx
    LD   (dl_dx), A
    LD   A, $FF
    LD   (dl_sx), A         ; sx = $FF (-1): moving left
    JR   .dy_calc
.dx_pos:
    LD   (dl_dx), A
    LD   A, 1
    LD   (dl_sx), A         ; sx = 1: moving right

.dy_calc:
    ; dy = |y2-y1|,  sy = +1 or $FF (-1)
    LD   A, D
    SUB  B                  ; A = y2 - y1, carry set if y2 < y1
    JR   NC, .dy_pos
    NEG
    LD   (dl_dy), A
    LD   A, $FF
    LD   (dl_sy), A         ; sy = $FF (-1): moving up
    JR   .err_calc
.dy_pos:
    LD   (dl_dy), A
    LD   A, 1
    LD   (dl_sy), A         ; sy = 1: moving down

.err_calc:
    ; err = dx - dy  (16-bit)
    LD   A, (dl_dx)
    LD   L, A
    LD   H, 0
    LD   A, (dl_dy)
    LD   E, A
    LD   D, 0
    OR   A                  ; clear carry for SBC
    SBC  HL, DE
    LD   (dl_err), HL

dl_loop:
    ; — Draw pixel at (x, y) —
    LD   A, (dl_y)
    LD   B, A
    LD   A, (dl_x)
    LD   C, A
    CALL set_pixel

    ; — Check if done: x==x2 and y==y2 —
    LD   A, (dl_x2)
    LD   B, A
    LD   A, (dl_x)
    CP   B
    JR   NZ, dl_not_done
    LD   A, (dl_y2)
    LD   B, A
    LD   A, (dl_y)
    CP   B
    RET  Z
dl_not_done:

    ; — e2 = 2 * err  (16-bit) —
    LD   HL, (dl_err)
    ADD  HL, HL
    PUSH HL                 ; keep e2 for the second test

    ; — if e2 + dy > 0 (i.e. e2 > -dy): err -= dy;  x += sx —
    LD   A, (dl_dy)
    LD   E, A
    LD   D, 0
    ADD  HL, DE             ; HL = e2 + dy
    BIT  7, H
    JR   NZ, dl_skip_x      ; negative: condition false
    LD   A, H
    OR   L
    JR   Z, dl_skip_x       ; zero: condition false
    LD   HL, (dl_err)
    OR   A
    SBC  HL, DE             ; err -= dy  (DE still holds dy)
    LD   (dl_err), HL
    LD   A, (dl_x)
    LD   C, A
    LD   A, (dl_sx)
    ADD  A, C               ; x += sx  ($FF + x = x - 1 in 8-bit arithmetic)
    LD   (dl_x), A
dl_skip_x:

    ; — if e2 - dx < 0 (i.e. e2 < dx): err += dx;  y += sy —
    POP  HL                 ; HL = e2
    LD   A, (dl_dx)
    LD   E, A
    LD   D, 0
    OR   A
    SBC  HL, DE             ; HL = e2 - dx
    BIT  7, H
    JR   Z, dl_loop         ; non-negative: condition false
    LD   HL, (dl_err)
    ADD  HL, DE             ; err += dx  (DE still holds dx)
    LD   (dl_err), HL
    LD   A, (dl_y)
    LD   C, A
    LD   A, (dl_sy)
    ADD  A, C               ; y += sy
    LD   (dl_y), A
    JR   dl_loop

dl_x:   DB 0   ; current x
dl_y:   DB 0   ; current y
dl_x2:  DB 0   ; target x
dl_y2:  DB 0   ; target y
dl_dx:  DB 0   ; |x2-x1|
dl_dy:  DB 0   ; |y2-y1|
dl_sx:  DB 0   ; x step: 1 or $FF
dl_sy:  DB 0   ; y step: 1 or $FF
dl_err: DW 0   ; Bresenham error accumulator (16-bit signed)
