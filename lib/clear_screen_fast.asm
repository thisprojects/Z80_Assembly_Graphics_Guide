; clear_screen_fast
; Clear the whole 6144-byte display file by pushing zeros onto the screen.
; PUSH HL writes two bytes in 11 T-states (5.5 per byte); LDIR needs 21.
; Input:  none      Output: none
; Destroys: B, H, L.  Leaves interrupts ENABLED.
; Interrupts are disabled while SP points into the display file, because an
; interrupt would push its return address on top of the pixels.
clear_screen_fast:
    DI
    LD   (csf_sp), SP      ; save the real stack pointer
    LD   SP, $5800         ; one past the end of the display file
    LD   HL, 0
    LD   B, 192            ; 192 passes of 16 PUSHes = 192 * 32 bytes = 6144
csf_loop:
    REPT 16
    PUSH HL                ; SP -= 2, (SP) = HL: two zero bytes
    ENDM
    DJNZ csf_loop
    LD   SP, (csf_sp)      ; restore the real stack
    EI
    RET
csf_sp: DW 0
