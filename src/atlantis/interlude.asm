;==============================================================================
; interlude.asm - the Atlantis city, between Atlantis and Trigon
;
; When the last level of Atlantis (CFG_INTERLUDE_LEVEL) is finished,
; level_up calls interlude before the next level's banner. The game
; stops where it is. The screen is Erin's picture of the city, unpacked
; straight onto it from the end of the data block (city_zx0, made by
; tools/mkcity.py from gfx/city_*.bin), with ATLANTIS in the title's tall
; letters above it and a line of story under it, a solid border, and a
; chime. A fresh key, or CFG_INTERLUDE_TIME, carries on.
;
; Then the play screen comes back: water, the sand's and the ground's
; colours, and row 1 (the score, the hearts, a bubble or a special
; bomb held). The seabed's pixels come back from the scroll buffers on
; the next two steps, as every step copies them. The sprites keep their
; places and their photographs, which hold water or seabed, so their
; restores put back nothing wrong; the bomb repaints its colours. The
; banner's and the double shot's clocks are pushed on by the time it
; took, as the quake does.
;
; Only where boot goes to the menu (CITY_SHOW, main.asm). Run once a
; game, never per frame; in the hot code only because the cold block is
; full.
;==============================================================================

    IFDEF CITY_SHOW

IL_LINE1_ROW    equ 21
IL_LINE2_ROW    equ 22

;------------------------------------------------------------------------------
; interlude - the city, then the play screen back
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
interlude:
        ld hl,(frame_count)
        ld (il_start),hl
        call il_show
        jr il_back

;------------------------------------------------------------------------------
; il_menu_code - option 3 on the menu (menu_code), after the sixth letter:
; the city's own code (notes/CHEATS.md) shows it, then the menu again.
; It has an N, which no level's code has (codes.asm), so it is never
; one. Returns if the letters are not it. Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
il_menu_code:
        ld hl,code_buf
        ld de,il_code
        ld b,CODE_LEN
.cmp:   ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .cmp
        call il_show
        jp enter_menu           ; it starts the stack again
il_code:        db "SUNKEN"
        ASSERT $ - il_code == CODE_LEN

;------------------------------------------------------------------------------
; il_show - the city, the words and the chime, until a fresh key or
; CFG_INTERLUDE_TIME. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
il_show:
        ld a,CFG_INTERLUDE_BORDER
        call set_border
        ld hl,city_zx0
        ld de,SCREEN
        call dzx0_standard      ; the whole screen, pixels and colours
        call title_draw         ; ATLANTIS, rows 2 and 3 (menu.asm)
        ld a,WATER_ATTR
        ld (text_attr),a
        ld hl,str_il_line1
        ld bc,(IL_LINE1_ROW << 8) | IL_LINE1_COL
        call print_string
        ld hl,str_il_line2
        ld bc,(IL_LINE2_ROW << 8) | IL_LINE2_COL
        call print_string
    IFNDEF NO_SOUND
        call il_chime
    ENDIF

        ; A key down now (he was playing) must go up first; then a fresh
        ; one carries on at once.
        xor a
        ld (il_armed),a
        ld d,CFG_INTERLUDE_TIME
.frame: call wait_frame
        call any_key
        jr nz,.down
        ld a,1
        ld (il_armed),a
        jr .on
.down:  ld a,(il_armed)
        or a
        jr z,.on
        jp keys_up              ; the key does not reach the game
.on:    dec d
        jr nz,.frame
        ret

; The play screen back, as it was.
il_back:
        ld a,WATER_ATTR
        call cls
        ld b,SAND_ROW
        ld d,1
        ld e,SAND_ATTR
        call fill_attr_rows
        ld b,GROUND_ROW
        ld d,1
        ld e,GROUND_ATTR
        call fill_attr_rows
        xor a
        ld (wheel_attr_n),a     ; the bomb paints its colours afresh
        ld hl,hud_text          ; row 1 draws only the cells that changed:
        ld b,HUD_LEN            ; forget them all, so it draws every one
.forget:
        ld (hl),0
        inc hl
        djnz .forget
        ld hl,hud_dirty
        ld a,(hl)
        or (1 << HUD_HEARTS) | (1 << HUD_TEXT)
        ld (hl),a
        ; The clocks that count television frames, on by the time taken.
        ld hl,(frame_count)
        ld de,(il_start)
        or a
        sbc hl,de
        ex de,hl
        ld hl,(banner_until)
        add hl,de
        ld (banner_until),hl
    IFDEF DOUBLE_SHOT
        ld hl,(double_until)
        add hl,de
        ld (double_until),hl
    ENDIF
        ret

    IFNDEF NO_SOUND
;------------------------------------------------------------------------------
; il_chime - a rising C major arpeggio, played straight away (blocking,
; as the knell is). il_tune: half-periods of 25 T-states, then how many
; television frames, ending in 0.
; Corrupts: AF, BC, D, E, HL
;------------------------------------------------------------------------------
il_chime:
        ld hl,il_tune
        ld d,CFG_INTERLUDE_BORDER
.note:  ld a,(hl)
        or a
        jr z,.done
        ld c,a
        inc hl
        ld a,(frame_count)
        add a,(hl)
        ld e,a                  ; the frame it ends on
        inc hl
.half:  ld a,d
        xor %00010000           ; the speaker
        ld d,a
        out (ULA_PORT),a
        ld b,c
.wait:  nop
        nop
        nop
        djnz .wait
        ld a,(frame_count)
        cp e
        jr nz,.half
        jr .note
.done:  ld a,CFG_INTERLUDE_BORDER
        out (ULA_PORT),a        ; the speaker in
        ret

il_tune:        db 134, 6, 106, 6, 89, 6, 67, 24, 0     ; C5 E5 G5 C6
    ENDIF

str_il_line1:   db "The city holds.", 0
str_il_line2:   db "Take the neutron bomb to Trigon.", 0
IL_LINE1_COL    equ (32 - 15) / 2
IL_LINE2_COL    equ 0
il_armed:       db 0
il_start:       dw 0

        INCLUDE "../../tools/dzx0_standard.asm"

        ASSERT CFG_INTERLUDE_LEVEL >= 1 && CFG_INTERLUDE_LEVEL <= 98
        ASSERT CFG_INTERLUDE_TIME >= 1 && CFG_INTERLUDE_TIME <= 255
        ASSERT CFG_INTERLUDE_BORDER >= 0 && CFG_INTERLUDE_BORDER <= 7
    ENDIF
