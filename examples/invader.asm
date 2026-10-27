; invader.asm — Space Invader movement demo, Chapter 6.
; Build: pasmo --tapbas invader.asm invader.tap
;
; draw_sprite         — three bunkers drawn once at startup (unmasked OR-draw).
; draw_sprite_masked  — main invader: two animated frames, cleanly erased each frame.
; draw_sprite_clipped — UFO drifting across the top; right edge clips at x=248.
;
; Press SPACE to return to BASIC.

    ORG  $8000

RIGHT_MAX  EQU 240     ; rightmost valid x for a 2-byte sprite (byte col 30–31)
BOTTOM_MAX EQU 184     ; lowest valid y for an 8-row sprite   (rows 184–191)
STEP_X     EQU 8       ; one character column per frame
STEP_Y     EQU 16      ; two character rows when reversing direction
UFO_Y      EQU 8       ; UFO row — never overlapped by the invader (multiples of 16)
BUNKER_Y   EQU 160     ; bunker row — invader sweeps through here

main:
    ; ── Black paper, bright green ink ──────────────────────────────────────
    LD   A, %01000010       ; bright=1, paper=0 (black), ink=2 (green)
    CALL fill_screen_attr

    ; ── Draw bunkers with draw_sprite (unmasked OR-draw) ───────────────────
    ; Pixels are ORed onto the display with no AND mask.  These are drawn once
    ; and never explicitly erased — but the invader's masked erase sprite will
    ; clear them automatically as it sweeps through y=160.
    LD   B, BUNKER_Y
    LD   C, 24
    LD   IX, BUNKER
    CALL draw_sprite

    LD   B, BUNKER_Y
    LD   C, 112
    LD   IX, BUNKER
    CALL draw_sprite

    LD   B, BUNKER_Y
    LD   C, 200
    LD   IX, BUNKER
    CALL draw_sprite

    ; ── Initialise state ────────────────────────────────────────────────────
    XOR  A
    LD   (inv_y),     A     ; start at top-left corner
    LD   (inv_x),     A
    LD   (inv_dir),   A     ; 0 = moving right
    LD   (inv_frame), A     ; start on frame A
    LD   (ufo_x),     A     ; UFO starts at the left edge

main_loop:
    ; ── SPACE key (port $7FFE bit 0, active-low) exits to BASIC ────────────
    LD   BC, $7FFE
    IN   A, (C)
    AND  $01
    RET  Z

    ; ── Erase invader at current position ───────────────────────────────────
    LD   A, (inv_y)
    LD   B, A
    LD   A, (inv_x)
    LD   C, A
    LD   IX, INV_ERASE
    CALL draw_sprite_masked

    ; ── Clear UFO row before redrawing ──────────────────────────────────────
    ; draw_sprite_clipped is OR-only and cannot erase its previous frame.
    ; Character row 1 (y=8..15) has eight scan lines.  In the display file
    ; their addresses share L=$20 (x=0) and step H from $40 to $47 — so
    ; incrementing H walks scan lines while L runs 32 byte-columns each time.
    LD   H, $40             ; scan line 0 of character row 1
    LD   D, 8               ; 8 scan lines to clear
ufo_clr_scan:
    LD   L, $20             ; byte column 0 of this scan line
    LD   B, 32              ; 32 bytes per scan line
    XOR  A
ufo_clr_byte:
    LD   (HL), A
    INC  L
    DJNZ ufo_clr_byte
    INC  H                  ; next scan line
    DEC  D
    JR   NZ, ufo_clr_scan

    ; ── Move invader one step horizontally ──────────────────────────────────
    LD   A, (inv_dir)
    OR   A
    JR   NZ, inv_go_left

inv_go_right:
    LD   A, (inv_x)
    ADD  A, STEP_X
    CP   RIGHT_MAX + 1      ; past the right edge?
    JR   C, inv_save_xr     ; no: save and continue
    LD   A, RIGHT_MAX       ; clamp to rightmost position
    LD   (inv_x), A
    LD   A, 1
    LD   (inv_dir), A       ; reverse: now moving left
    CALL inv_step_down
    JR   inv_draw

inv_save_xr:
    LD   (inv_x), A
    JR   inv_draw

inv_go_left:
    LD   A, (inv_x)
    SUB  STEP_X
    JR   NC, inv_save_xl    ; no borrow: still on-screen
    XOR  A                  ; underflow: clamp to 0
    LD   (inv_x), A
    LD   (inv_dir), A       ; A=0 = moving right
    CALL inv_step_down
    JR   inv_draw

inv_save_xl:
    LD   (inv_x), A

inv_draw:
    ; ── Toggle animation frame A ↔ B ────────────────────────────────────────
    LD   A, (inv_frame)
    XOR  1
    LD   (inv_frame), A
    JR   NZ, inv_frame_b

    LD   IX, INV_SPRITE_A
    JR   inv_blit

inv_frame_b:
    LD   IX, INV_SPRITE_B

inv_blit:
    LD   A, (inv_y)
    LD   B, A
    LD   A, (inv_x)
    LD   C, A
    CALL draw_sprite_masked

    ; ── Advance UFO and draw with draw_sprite_clipped ───────────────────────
    ; Adding STEP_X wraps through zero at 256 (8-bit overflow), returning the
    ; UFO to the left edge.  At x=248 byte-column 32 is off-screen; the right
    ; byte of the 2-byte UFO is trimmed automatically by draw_sprite_clipped.
    LD   A, (ufo_x)
    ADD  A, STEP_X          ; 248 + 8 = 256 = 0 mod 256: wraps to left edge
    LD   (ufo_x), A
    LD   B, UFO_Y
    LD   C, A               ; A = new ufo_x
    LD   IX, UFO_SPRITE
    CALL draw_sprite_clipped

    CALL inv_delay
    JP   main_loop

; ─────────────────────────────────────────────────────────────────────────────
inv_step_down:
    LD   A, (inv_y)
    ADD  A, STEP_Y
    CP   BOTTOM_MAX + 1     ; gone past the bottom?
    JR   C, isd_ok
    XOR  A                  ; yes: wrap back to the top
isd_ok:
    LD   (inv_y), A
    RET

; ─────────────────────────────────────────────────────────────────────────────
inv_delay:
    LD   BC, 30000          ; ~223 ms at 3.5 MHz
idly_loop:
    DEC  BC
    LD   A, B
    OR   C
    JR   NZ, idly_loop
    RET

; ─────────────────────────────────────────────────────────────────────────────
; State variables

inv_y:     DB 0             ; current pixel row    (0–184)
inv_x:     DB 0             ; current pixel column  (0–240, multiple of 8)
inv_dir:   DB 0             ; 0 = moving right, 1 = moving left
inv_frame: DB 0             ; 0 = frame A,      1 = frame B
ufo_x:     DB 0             ; UFO pixel column      (0–255, multiple of 8)

; ─────────────────────────────────────────────────────────────────────────────
; Invader sprite data — masked format, 8 rows × 2 bytes (16 pixels wide).
; Each row: AND_byte0, OR_byte0, AND_byte1, OR_byte1
; AND = $00 everywhere — fully opaque 16×8 bounding box.
;
;        byte 0           byte 1
;        7 6 5 4 3 2 1 0  7 6 5 4 3 2 1 0
; row 0  . . * . . . . *  * . . . . * . .   antennae
; row 1  . . * * * * * *  * * * * * * . .   head
; row 2  . * * . * * . .  . . * * . * * .   eyes
; row 3  . * * * * * * *  * * * * * * * .   body
; row 4  * * . * * . * *  * * . * * . * *   claws
; row 5  . . * * * * * *  * * * * * * . .   body
; Frame A — row 6: legs wide, row 7: feet inner
; Frame B — row 6: feet inner, row 7: legs wide

INV_SPRITE_A:
    DB  8, 2
    DB  $00,%00100001, $00,%10000100   ; row 0  antennae
    DB  $00,%00111111, $00,%11111100   ; row 1  head
    DB  $00,%01101100, $00,%00110110   ; row 2  eyes
    DB  $00,%01111111, $00,%11111110   ; row 3  body
    DB  $00,%11011011, $00,%11011011   ; row 4  claws
    DB  $00,%00111111, $00,%11111100   ; row 5  body
    DB  $00,%01000000, $00,%00000010   ; row 6  legs wide
    DB  $00,%00001000, $00,%00010000   ; row 7  feet inner

INV_SPRITE_B:
    DB  8, 2
    DB  $00,%00100001, $00,%10000100   ; row 0  antennae
    DB  $00,%00111111, $00,%11111100   ; row 1  head
    DB  $00,%01101100, $00,%00110110   ; row 2  eyes
    DB  $00,%01111111, $00,%11111110   ; row 3  body
    DB  $00,%11011011, $00,%11011011   ; row 4  claws
    DB  $00,%00111111, $00,%11111100   ; row 5  body
    DB  $00,%00001000, $00,%00010000   ; row 6  feet inner  (rows 6–7 swapped vs A)
    DB  $00,%01000000, $00,%00000010   ; row 7  legs wide

; Erase sprite: AND=$00, OR=$00 — clears the entire 16×8 bounding box.
INV_ERASE:
    DB  8, 2
    DB  $00,$00, $00,$00
    DB  $00,$00, $00,$00
    DB  $00,$00, $00,$00
    DB  $00,$00, $00,$00
    DB  $00,$00, $00,$00
    DB  $00,$00, $00,$00
    DB  $00,$00, $00,$00
    DB  $00,$00, $00,$00

; ─────────────────────────────────────────────────────────────────────────────
; UFO sprite — unmasked format (used with draw_sprite_clipped).
; 2 rows × 2 bytes = 16 pixels wide.
;
;        byte 0           byte 1
; row 0  . . * * * * . .  . . * * * * . .   dome
; row 1  * * * * * * * *  * * * * * * * *   body

UFO_SPRITE:
    DB  2, 2
    DB  %00111100, %00111100   ; dome
    DB  %11111111, %11111111   ; body

; ─────────────────────────────────────────────────────────────────────────────
; Bunker sprite — unmasked format (used with draw_sprite).
; 4 rows × 2 bytes = 16 pixels wide.
;
;        byte 0           byte 1
; row 0  . * * * * * * .  . * * * * * * .   top
; row 1  * * * * * * * *  * * * * * * * *   body
; row 2  * * . . . . * *  * * . . . . * *   notched base
; row 3  * * . . . . * *  * * . . . . * *

BUNKER:
    DB  4, 2
    DB  %01111110, %01111110   ; top
    DB  %11111111, %11111111   ; body
    DB  %11000011, %11000011   ; notched base
    DB  %11000011, %11000011

    INCLUDE "lib/calc_pixel_addr.asm"
    INCLUDE "lib/fill_screen_attr.asm"
    INCLUDE "lib/draw_sprite.asm"
    INCLUDE "lib/draw_sprite_masked.asm"
    INCLUDE "lib/draw_sprite_clipped.asm"

    END  main
