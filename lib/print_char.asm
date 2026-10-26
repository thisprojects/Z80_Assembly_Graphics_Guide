; print_char
; Print one character from the current character set into a character cell.
; Input:  A = character code (32–127)
;         B = character row    (0–23)
;         C = character column (0–31)
; Output: none
; Destroys: A, B, D, E, H, L
; Requires draw_glyph.asm.
print_char:
    LD   L, A
    LD   H, 0
    ADD  HL, HL            ; * 2
    ADD  HL, HL            ; * 4
    ADD  HL, HL            ; * 8: eight bytes per glyph
    LD   DE, (charset_ptr) ; address of the glyph for code 0 (font base - 256)
    ADD  HL, DE            ; HL = address of this character's glyph
    EX   DE, HL            ; DE = glyph pointer for draw_glyph
    JP   draw_glyph

; The default points at the ROM font: glyph for code 32 is at $3D00,
; so the "code 0" address is $3D00 - 32*8 = $3C00.  This is the same value
; the ROM keeps in the CHARS system variable (address 23606).
charset_ptr: DW $3C00
