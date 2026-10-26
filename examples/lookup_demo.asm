; lookup_demo — Chapter 10 example.
; Draws a full-width line on every sixth pixel row, finding each row's
; address with the lookup table instead of calc_pixel_addr.
; Build from the project root:  pasmo --tapbas examples/lookup_demo.asm lookup_demo.tap
    ORG  $8000

row_table EQU $9000         ; 192 entries * 2 bytes = 384 bytes

main:
    CALL build_row_table
    CALL clear_screen_fast
    XOR  A
    LD   (ly), A
ld_next:
    LD   A, (ly)
    LD   B, A
    CALL get_row_addr       ; HL = start of pixel row y
    LD   B, 32              ; 32 bytes across the row
ld_fill:
    LD   (HL), $FF
    INC  L                  ; safe: a row never crosses a 256-byte boundary
    DJNZ ld_fill
    LD   A, (ly)
    ADD  A, 6
    LD   (ly), A
    CP   192
    JR   C, ld_next
    EI
ld_done:
    HALT
    JR   ld_done

ly: DB 0

    INCLUDE "lib/calc_pixel_addr.asm"
    INCLUDE "lib/build_row_table.asm"
    INCLUDE "lib/get_row_addr.asm"
    INCLUDE "lib/clear_screen_fast.asm"

    END  $8000
