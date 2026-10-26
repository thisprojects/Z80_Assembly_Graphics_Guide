; flip_screen / init_page_flip
; 128K Spectrum only.  The 128K machine has two screens: the normal one in
; bank 5 (always at $4000) and a shadow screen in bank 7.  Bit 3 of port $7FFD
; chooses which one the ULA displays.  Bank 7 can be written through the
; $C000–$FFFF window, so with bank 7 paged in the program can draw into the
; hidden screen at $C000 and then flip.
;
; init_page_flip: page bank 7 in at $C000, display bank 5, draw to bank 7.
; flip_screen:    swap the displayed screen and retarget draw_offset at the
;                 screen that is now hidden.  Call it straight after a HALT.
; Input: none      Output: none      Destroys: A, B, C
; Requires draw_sprite_masked_buf.asm (for draw_offset).
BANKM EQU $5B5C            ; 128K system variable: copy of the last OUT to port $7FFD

init_page_flip:
    DI
    LD   A, (BANKM)
    AND  %11110000         ; keep the ROM-select (bit 4) and paging-lock (bit 5) bits
    OR   %00000111         ; bits 2-0 = 7: bank 7 at $C000; bit 3 = 0: show bank 5
    LD   (BANKM), A
    LD   BC, $7FFD
    OUT  (C), A
    EI
    LD   A, $80            ; displayed = bank 5, so draw into $C000
    LD   (draw_offset), A
    RET

flip_screen:
    DI                     ; the update of BANKM and the port must stay together
    LD   A, (BANKM)
    XOR  %00001000         ; bit 3: 0 = display bank 5, 1 = display bank 7
    LD   (BANKM), A
    LD   BC, $7FFD
    OUT  (C), A
    EI
    AND  %00001000         ; Z set: bank 5 is now displayed, so draw to bank 7
    LD   A, $80            ; (LD does not touch the flags)
    JR   Z, fs_store
    XOR  A                 ; bank 7 is displayed: draw straight to $4000
fs_store:
    LD   (draw_offset), A
    RET
