; text_demo — Chapter 8 example.
; Build from the project root:  pasmo --tapbas examples/text_demo.asm text_demo.tap
    ORG  $8000

FONT_BUF EQU $9000          ; 768 bytes for the generated bold font

main:
    ; Clear the pixels, then white ink on black paper everywhere
    LD   HL, $4000
    LD   DE, $4001
    LD   BC, 6143
    LD   (HL), 0
    LDIR
    LD   A, %00000111
    CALL fill_screen_attr

    ; 1. ROM font, bright yellow
    LD   HL, msg_rom
    LD   B, 2
    LD   C, 8
    CALL print_string
    LD   A, %01000110       ; bright, paper 0 (black), ink 6 (yellow)
    LD   B, 2
    LD   C, 8
    LD   E, 15              ; "HELLO, SPECTRUM" is 15 characters
    CALL fill_attr_cells

    ; 2. Bold font generated from the ROM font, bright cyan
    LD   HL, FONT_BUF
    CALL make_bold
    LD   HL, FONT_BUF - 256 ; "code 0" address = buffer - 32*8
    LD   (charset_ptr), HL
    LD   HL, msg_bold
    LD   B, 5
    LD   C, 11
    CALL print_string
    LD   A, %01000101       ; bright cyan ink
    LD   B, 5
    LD   C, 11
    LD   E, 9               ; "BOLD TEXT"
    CALL fill_attr_cells
    LD   HL, $3C00          ; back to the ROM font
    LD   (charset_ptr), HL

    ; 3. Three UDGs in a row, each in its own colour
    LD   DE, udg_heart
    LD   B, 9
    LD   C, 12
    CALL draw_glyph
    LD   A, %01000010       ; bright red
    LD   B, 9
    LD   C, 12
    LD   E, 1
    CALL fill_attr_cells

    LD   DE, udg_smile
    LD   B, 9
    LD   C, 14
    CALL draw_glyph
    LD   A, %01000110       ; bright yellow
    LD   B, 9
    LD   C, 14
    LD   E, 1
    CALL fill_attr_cells

    LD   DE, udg_alien
    LD   B, 9
    LD   C, 16
    CALL draw_glyph
    LD   A, %01000100       ; bright green
    LD   B, 9
    LD   C, 16
    LD   E, 1
    CALL fill_attr_cells

    EI
done:
    HALT
    JR   done

msg_rom:  DB "HELLO, SPECTRUM", 0
msg_bold: DB "BOLD TEXT", 0

udg_heart:
    DB %00000000
    DB %01100110
    DB %11111111
    DB %11111111
    DB %11111111
    DB %01111110
    DB %00111100
    DB %00011000
udg_smile:
    DB %00111100
    DB %01000010
    DB %10100101
    DB %10000001
    DB %10100101
    DB %10011001
    DB %01000010
    DB %00111100
udg_alien:
    DB %00011000
    DB %00111100
    DB %01111110
    DB %11011011
    DB %11111111
    DB %00100100
    DB %01011010
    DB %10100101

    INCLUDE "lib/fill_screen_attr.asm"
    INCLUDE "lib/draw_glyph.asm"
    INCLUDE "lib/print_char.asm"
    INCLUDE "lib/print_string.asm"
    INCLUDE "lib/fill_attr_cells.asm"
    INCLUDE "lib/make_bold.asm"

    END  $8000
