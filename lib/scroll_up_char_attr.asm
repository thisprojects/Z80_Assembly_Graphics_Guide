; scroll_up_char_attr
; Scrolls the colour attribute file ($5800-$5AFF) up by one character row.
; Attribute row 0 is lost; the new bottom row (attr row 23) is filled with
; zero (black ink, black paper, no flash, no bright).
; The pixel display file is not touched — call scroll_up_char separately.
; Destroys: A, B, C, D, E, H, L.
scroll_up_char_attr:
    LD   HL, $5820         ; source: attribute row 1
    LD   DE, $5800         ; dest:   attribute row 0
    LD   BC, 23 * 32       ; 23 rows x 32 bytes = 736 bytes
    LDIR
    LD   B, 32             ; clear the 32 bytes of attr row 23
    XOR  A
suca_clr:
    LD   (DE), A           ; DE points to attr row 23 after the LDIR
    INC  DE
    DJNZ suca_clr
    RET
