;==============================================================================
; story.asm - the story, typed out once, as the tape's game starts
;
; Between start-up and the menu (boot), on a black screen in the ROM's
; font: a letter every CFG_STORY_CHAR 1/50 seconds with a click, a pause
; of CFG_STORY_PARA at each paragraph, then CFG_STORY_END or a key, and
; the menu. Any key skips it, straight to the menu; a key already down
; when it starts must be let go first, or the one that loaded the tape
; would skip it.
;
; Only where boot goes to the menu (TYPEWRITER, main.asm): the soak, the
; measurements and the other test builds go straight to their work.
; All of it is in the cold block: it runs once, before the game.
;==============================================================================

STORY_NL        equ 13          ; the next line
STORY_PARA      equ 1           ; a blank line, then the paragraph's pause
STORY_COL       equ 1           ; 30 columns, one free each side
STORY_ROWS      equ 17          ; lines, blank ones included
STORY_ROW       equ (24 - STORY_ROWS) / 2
STORY_ATTR      equ WHITE | (BLACK << 3)

        ASSERT CFG_STORY_CHAR >= 1 && CFG_STORY_CHAR <= 255 && CFG_STORY_PARA >= 1 && CFG_STORY_PARA <= 255
        ASSERT CFG_STORY_END >= 1 && CFG_STORY_END <= 255 && CFG_STORY_CLICK >= 1 && CFG_STORY_CLICK <= 255

;------------------------------------------------------------------------------
; story_show - type the story, then the menu. boot jumps here.
;------------------------------------------------------------------------------
story_show:
        ld a,BLACK
        call set_border
        ld a,STORY_ATTR
        call cls
        ld a,(text_attr)
        ld (story_attr),a
        ld a,STORY_ATTR
        ld (text_attr),a
        ld hl,story_text
        ld bc,STORY_ROW * 256 + STORY_COL ; B = row, C = column
.next:  ld a,(hl)
        inc hl
        or a
        jr z,.end
        cp STORY_NL
        jr z,.line
        cp STORY_PARA
        jr z,.para
        push hl
        push af
        call print_char         ; C moves on
        pop af
        cp ' '
        call nz,story_click
        ld a,CFG_STORY_CHAR
        call story_wait
        pop hl
        jr .next
.para:  inc b
        ld a,CFG_STORY_PARA
        push hl
        call story_wait
        pop hl
.line:  inc b
        ld c,STORY_COL
        jr .next
.end:   ld a,CFG_STORY_END
        call story_wait
story_done:
        ld a,(story_attr)
        ld (text_attr),a
        call keys_up            ; the skipping key does not reach the menu
        jp enter_menu           ; it starts its own stack

; A = 1/50 seconds to wait. A fresh key skips the rest: to the menu.
; Corrupts: AF, DE (and the stack, when it skips: enter_menu resets it)
story_wait:
        ld d,a
.frame: call wait_frame
        call any_key
        jr nz,.down
        ld a,1
        ld (story_armed),a      ; every key up: the next one counts
        jr .on
.down:  ld a,(story_armed)
        or a
        jr nz,story_done
.on:    dec d
        jr nz,.frame
        ret

; One short pulse of the speaker, the border kept black. Corrupts: AF
story_click:
    IFNDEF NO_SOUND
        push bc
        ld a,%00010000 | BLACK
        out (ULA_PORT),a
        ld b,CFG_STORY_CLICK
.hold:  djnz .hold
        ld a,BLACK
        out (ULA_PORT),a
        pop bc
    ENDIF
        ret

story_armed:    db 0            ; 1 once every key has been up
story_attr:     db 0            ; text_attr as it was, for the menu

; The words, as Quartus wrote them, broken by hand for 30 columns.
story_text:
        db "These are dark times.", STORY_PARA
        db "Atlantis is besieged by the", STORY_NL
        db "Trigon Empire.", STORY_NL
        db "Its force field still holds,", STORY_NL
        db "but it cannot hold for ever.", STORY_PARA
        db "One diver can still", STORY_NL
        db "get through.", STORY_PARA
        db "Fight your way through the", STORY_NL
        db "waters of Atlantis.", STORY_NL
        db "Find the neutron bomb.", STORY_NL
        db "Carry it to Trigon and destroy", STORY_NL
        db "the Empire's power source.", STORY_PARA
        db "Atlantis is counting on you.", 0
