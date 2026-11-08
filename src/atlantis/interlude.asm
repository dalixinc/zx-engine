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
; Then the ending (il_ending): he has reached Atlantis, and here is the
; code that lets him into Trigon, the second game, on its own tape. A
; fresh key goes back to the menu: Atlantis ends at the city. The score
; counts for the high score, as at GAME OVER, but there is no knell.
; The code is TRIGON_CODE (notes/LEVEL-CODES-LIST.md), which Trigon's
; menu asks for (src/trigon/).
;
; Only where boot goes to the menu (CITY_SHOW, main.asm). Run once a
; game, never per frame; in the hot code only because the cold block is
; full.
;==============================================================================

    IFDEF CITY_SHOW

IL_LINE1_ROW    equ 21
IL_LINE2_ROW    equ 22

;------------------------------------------------------------------------------
; interlude - the city, then the ending, then the menu. Never returns.
;------------------------------------------------------------------------------
interlude:
        call il_show
        call il_ending
        call score_game_over    ; a new high score?
        xor a
        ld (menu_game_over),a   ; not GAME OVER: he won
        jp enter_menu           ; it starts the stack again

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
        ; Black first: the border, and every cell black on black, so the
        ; pixels unpacked under them do not show yet.
        xor a                   ; BLACK
        call set_border
        ld hl,ATTRS
        ld de,ATTRS + 1
        ld bc,ATTRS_SIZE - 1
        ld (hl),a
        ldir
        ld hl,city_pix_zx0
        ld de,SCREEN
        call dzx0_standard      ; the pixels, unseen
        ld hl,city_atr_zx0
        ld de,IL_ATTRS
        call dzx0_standard      ; the colours, aside for the circle
        ; ATLANTIS, rows 2 and 3 (menu.asm), alone on the black at once;
        ; the circle puts its colours back as it passes.
        call title_draw
        ld hl,ATTRS + TITLE_ROW * 32 + TITLE_COL
        ld de,IL_ATTRS + TITLE_ROW * 32 + TITLE_COL
        ld bc,8
        ldir
        ld hl,ATTRS + (TITLE_ROW + 1) * 32 + TITLE_COL
        ld de,IL_ATTRS + (TITLE_ROW + 1) * 32 + TITLE_COL
        ld bc,8
        ldir
        ; The words in black for now: their cells are water colour in
        ; the picture's colours, so the circle shows them.
        xor a
        ld (text_attr),a
        ld hl,str_il_line1
        ld bc,(IL_LINE1_ROW << 8) | IL_LINE1_COL
        call print_string
        ld hl,str_il_line2
        ld bc,(IL_LINE2_ROW << 8) | IL_LINE2_COL
        call print_string
        call il_circle
        ld a,CFG_INTERLUDE_BORDER
        call set_border
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

; The ending: black, the words, and the code in yellow, until a fresh
; key. Corrupts: AF, BC, DE, HL
il_ending:
        xor a                   ; BLACK
        call set_border
        ld a,IL_END_ATTR
        call cls
        ld (text_attr),a
        ld hl,il_end_text
.line:  ld b,(hl)               ; the row, or 0 at the end
        inc b
        dec b
        jr z,.keys
        inc hl
        ld c,(hl)               ; the column
        inc hl
        ld a,(hl)               ; the colour
        inc hl
        ld (text_attr),a
        call print_string
        inc hl                  ; past its 0
        jr .line
.keys:  call keys_up            ; the key that ended the city first
.wait:  call wait_frame
        call any_key
        jr z,.wait
        jp keys_up              ; it does not reach the menu

IL_END_ATTR     equ BRIGHT | WHITE | (BLACK << 3)
IL_CODE_ATTR    equ BRIGHT | YELLOW | (BLACK << 3)
IL_KEY_ATTR     equ WHITE | (BLACK << 3)
; Each line: row, column, colour, the words, 0. A row of 0 ends them.
il_end_text:
        db 4, 3, IL_END_ATTR, "You have reached Atlantis.", 0
        db 6, 1, IL_END_ATTR, "The neutron bomb is yours. Now", 0
        db 7, 1, IL_END_ATTR, "carry it to Trigon, and end", 0
        db 8, 1, IL_END_ATTR, "the Empire.", 0
        db 11, 6, IL_END_ATTR, "Your Trigon code is", 0
        db 13, (32 - CODE_LEN) / 2, IL_CODE_ATTR
        TRIGON_CODE
        db 0
        db 16, 1, IL_END_ATTR, "Load Trigon, and type the code", 0
        db 17, 1, IL_END_ATTR, "on its menu.", 0
        db 21, 10, IL_KEY_ATTR, "PRESS A KEY", 0
        db 0

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

;------------------------------------------------------------------------------
; il_circle - the colours come on in a circle that grows from the middle
; of the screen, a ring of CFG_INTERLUDE_RIM leading it. Distances are in
; half cells, so the middle (between cells 15 and 16, and 11 and 12) is
; whole: a cell's is |2x - 31| and |2y - 23|, and it is inside when the
; sum of their squares is under R squared. Each ring looks at all 768
; cells, about two television frames, and R grows by IL_STEP.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
IL_STEP         equ 2           ; half cells a ring
IL_RIM          equ 4           ; the ring's width, half cells
IL_R_END        equ 40          ; past the corners (38.6)

il_circle:
        xor a
.ring:  ld (il_r),a
        call il_sq
        ld (il_in),hl
        ld a,(il_r)
        add a,IL_RIM
        call il_sq
        ld (il_rim),hl
        ld hl,ATTRS
        ld de,IL_ATTRS
        ld b,0                  ; the row
.row:   ld a,b
        add a,a
        sub 23
        jr nc,.ydown
        neg
.ydown: push hl
        call il_sq
        ld (il_dy),hl
        pop hl
        ld c,0                  ; the column
.cell:  push bc
        ld a,c
        add a,a
        sub 31
        jr nc,.xright
        neg
.xright:
        push hl
        call il_sq
        ld bc,(il_dy)
        add hl,bc               ; the distance squared
        ld bc,(il_in)
        or a
        sbc hl,bc
        jr c,.inside
        add hl,bc
        ld bc,(il_rim)
        or a
        sbc hl,bc
        pop hl
        jr nc,.next             ; not reached yet
        ld (hl),CFG_INTERLUDE_RIM
        jr .next
.inside:
        pop hl
        ld a,(de)               ; its own colours
        ld (hl),a
.next:  inc hl
        inc de
        pop bc
        inc c
        bit 5,c
        jr z,.cell              ; 32 columns
        inc b
        ld a,b
        cp 24
        jr c,.row
        ld a,(il_r)
        add a,IL_STEP
        cp IL_R_END + IL_STEP
        jr c,.ring
        ret

; HL = A squared, A up to IL_R_END + IL_STEP + IL_RIM. Corrupts: AF
il_sq:  push de
        ld e,a
        ld d,0
        ld hl,il_squares
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ret
il_squares:
il_n = 0
        DUP IL_R_END + IL_STEP + IL_RIM + 1
        dw il_n * il_n
il_n = il_n + 1
        EDUP
il_r:           db 0
il_in:          dw 0
il_rim:         dw 0
il_dy:          dw 0
; The picture's colours wait here while the circle grows: free room
; above the data block, below the diver's shifted copies.
IL_ATTRS        equ data_end
        ASSERT IL_ATTRS + ATTRS_SIZE <= PRESHIFT_START, "no room above the data for the city's colours"
        ASSERT (IL_R_END / 2) * (IL_R_END / 2) * 4 > 31 * 31 + 23 * 23, "the circle stops short of the corners"

str_il_line1:   db "The city holds.", 0
str_il_line2:   db "Take the neutron bomb to Trigon.", 0
IL_LINE1_COL    equ (32 - 15) / 2
IL_LINE2_COL    equ 0
il_armed:       db 0

        INCLUDE "../../tools/dzx0_standard.asm"

        ASSERT CFG_INTERLUDE_LEVEL >= 1 && CFG_INTERLUDE_LEVEL <= 98
        ASSERT CFG_INTERLUDE_TIME >= 1 && CFG_INTERLUDE_TIME <= 255
        ASSERT CFG_INTERLUDE_BORDER >= 0 && CFG_INTERLUDE_BORDER <= 7
    ENDIF
