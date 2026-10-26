; clear_buffer
; Clear the 6144 pixel bytes of the current draw target (see draw_offset).
; Input:  none      Output: none
; Destroys: A, B, C, D, E, H, L
; Requires draw_sprite_masked_buf.asm (for draw_offset).
clear_buffer:
    LD   A, (draw_offset)
    ADD  A, $40            ; high byte of the target's first pixel byte
    LD   H, A
    LD   L, 0
    LD   D, H
    LD   E, 1              ; DE = HL + 1: LDIR smears the first byte forwards
    LD   BC, 6143
    LD   (HL), 0
    LDIR
    RET
