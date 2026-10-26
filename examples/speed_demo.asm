; speed_demo — Chapter 10 example.
; The border colour is switched around each routine, so the height of the
; coloured band is how long the routine takes.  Red = LDIR clear (about 1.9
; frames), green = PUSH clear (about half a frame).
; Build from the project root:  pasmo --tapbas examples/speed_demo.asm speed_demo.tap
    ORG  $8000

main:
    EI
loop:
    HALT
    LD   A, 2               ; red border
    OUT  ($FE), A
    CALL clear_screen_ldir
    XOR  A                  ; black border
    OUT  ($FE), A

    HALT
    LD   A, 4               ; green border
    OUT  ($FE), A
    CALL clear_screen_fast
    XOR  A
    OUT  ($FE), A
    JR   loop

clear_screen_ldir:
    LD   HL, $4000
    LD   DE, $4001
    LD   BC, 6143
    LD   (HL), 0
    LDIR
    RET

    INCLUDE "lib/clear_screen_fast.asm"

    END  $8000
