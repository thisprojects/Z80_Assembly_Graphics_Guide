; buffer_demo — Chapter 9 example.
; A masked saucer bounces across a checkerboard background.  Everything is
; composed in an off-screen buffer at $A000; one character row is copied to
; the screen straight after the frame interrupt, so the beam never sees a
; half-drawn sprite.
; Build from the project root:  pasmo --tapbas examples/buffer_demo.asm buffer_demo.tap
    ORG  $8000

main:
    LD   A, %00000111
    CALL fill_screen_attr
    CALL init_bg            ; checkerboard into the buffer
    LD   B, 0               ; copy the whole buffer to the screen once
    LD   C, 0
    LD   D, 24
    LD   E, 32
    CALL copy_cells
    EI

frame:
    CALL restore_row        ; wipe last frame's saucer out of the buffer
    LD   A, (sx)
    LD   C, A
    LD   B, 96              ; y = 96: character row 12
    LD   IX, saucer
    CALL draw_sprite_masked_buf
    HALT                    ; wait for the start of the next frame
    LD   B, 12              ; copy character row 12 while the beam is
    LD   C, 0               ; still above the picture
    LD   D, 1
    LD   E, 32
    CALL copy_cells

    LD   A, (delay)         ; move the saucer once every 3 frames
    DEC  A
    LD   (delay), A
    JR   NZ, frame
    LD   A, 3
    LD   (delay), A
    LD   A, (sx)
    LD   B, A
    LD   A, (sdir)
    ADD  A, B
    LD   (sx), A
    CP   240                ; right-hand limit (16-pixel sprite)
    JR   Z, reverse
    OR   A                  ; left-hand limit
    JR   Z, reverse
    JR   frame
reverse:
    LD   A, (sdir)
    NEG
    LD   (sdir), A
    JR   frame

; init_bg — fill the buffer with a checkerboard: $AA on even scan lines,
; $55 on odd ones (scan line parity is bit 0 of the high byte).
init_bg:
    LD   A, (draw_offset)
    ADD  A, $40
    LD   H, A
    LD   L, 0
    LD   B, 24              ; 24 high-byte values * 256 = 6144 bytes
ib_page:
    LD   A, H
    AND  1
    LD   A, $AA
    JR   Z, ib_even
    LD   A, $55
ib_even:
    PUSH BC
    LD   B, 0               ; 256 bytes
ib_byte:
    LD   (HL), A
    INC  L
    DJNZ ib_byte
    POP  BC
    INC  H
    DJNZ ib_page
    RET

; restore_row — redraw the checkerboard on character row 12 in the buffer.
; Row 12 is row 4 of the second third: high byte base + $08, L = $80..$9F.
restore_row:
    LD   A, (draw_offset)
    ADD  A, $48
    LD   H, A
    LD   C, 8               ; eight scan lines
rr_line:
    LD   L, $80
    LD   A, H
    AND  1
    LD   A, $AA
    JR   Z, rr_even
    LD   A, $55
rr_even:
    LD   B, 32
rr_byte:
    LD   (HL), A
    INC  L
    DJNZ rr_byte
    INC  H
    DEC  C
    JR   NZ, rr_line
    RET

sx:     DB 0
sdir:   DB 8
delay:  DB 3

; 16x8 masked saucer: each row is AND-hi, OR-hi, AND-lo, OR-lo
saucer:
    DB  8, 2
    DB  $F8, $04, $1F, $20
    DB  $E0, $1B, $07, $D8
    DB  $C0, $3F, $03, $FC
    DB  $00, $FF, $00, $FF
    DB  $00, $6D, $00, $B6
    DB  $C0, $1F, $03, $F8
    DB  $E6, $19, $67, $98
    DB  $DF, $20, $FB, $04

    INCLUDE "lib/calc_pixel_addr.asm"
    INCLUDE "lib/fill_screen_attr.asm"
    INCLUDE "lib/draw_sprite_masked_buf.asm"
    INCLUDE "lib/copy_cells.asm"

    END  $8000
