; make_bold
; Build a bold version of the ROM font in RAM.
; Each glyph byte is OR'd with itself shifted one pixel to the right,
; which thickens every vertical stroke by one pixel.
; Input:  HL = destination buffer (768 bytes: 96 glyphs x 8 bytes)
; Output: none
; Destroys: A, B, C, D, E, H, L
; Use it by pointing charset_ptr at (buffer - 256).
make_bold:
    LD   DE, $3D00         ; ROM glyph for code 32
    LD   BC, 768           ; 96 glyphs * 8 bytes
mb_loop:
    LD   A, (DE)
    LD   (HL), A           ; copy the original byte
    RRCA                   ; shift right one pixel (bit 0 wraps into bit 7)
    AND  %01111111         ; discard the wrapped bit
    OR   (HL)              ; merge with the original
    LD   (HL), A
    INC  DE
    INC  HL
    DEC  BC
    LD   A, B
    OR   C
    JR   NZ, mb_loop
    RET
