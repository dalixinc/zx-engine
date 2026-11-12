;==============================================================================
; trigon/ending.asm - the end of Trigon (TRIGON_END: Trigon, booting to
; the menu)
;
; When level CFG_ENDING_LEVEL is finished, level_up comes here before
; the next level's banner. The game stops where it is: black, a few
; words, and the code that lets him into Finale, the third game, until a
; fresh key. The score counts for the high score, as at GAME OVER, but
; there is no knell, and the menu does not say GAME OVER. The picture of
; Trigon City belongs to Finale, which starts with the whole 48K.
; The code is FINALE_WORD (notes/LEVEL-CODES-LIST.md). It has an N,
; which no level code has (codes.asm), so it never clashes with one.
;==============================================================================

    IFDEF TRIGON_END


; level_up: the next level would be CFG_ENDING_LEVEL + 1. Never returns.
tg_ending:
        xor a                   ; BLACK
        call set_border
        ld a,TG_END_ATTR
        call cls
        ld hl,tg_end_text
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
.keys:  call keys_up            ; he was playing: that key goes up first
.wait:  call wait_frame
        call any_key
        jr z,.wait
        call keys_up            ; it does not reach the menu
        call score_game_over    ; a new high score?
        xor a
        ld (menu_game_over),a   ; not GAME OVER: he won
        jp enter_menu           ; it starts the stack again

TG_END_ATTR     equ BRIGHT | WHITE | (BLACK << 3)
TG_CODE_ATTR    equ BRIGHT | YELLOW | (BLACK << 3)
; Each line: row, column, colour, the words, 0. A row of 0 ends them.
; Finale's placeholder: chunk 5 of the brief puts the city of Trigon
; and the bomb drop before it.
tg_end_text:
        db 7, 5, TG_END_ATTR, "THE BLOCKADE IS BROKEN", 0
        db 10, 8, TG_CODE_ATTR, "ATLANTIS IS FREE", 0
        db 18, 10, TG_END_ATTR, "PRESS A KEY", 0
        db 0

    ENDIF
