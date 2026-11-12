;==============================================================================
; story.asm - the story, typed out when 1 starts a game
;
; Between the menu and the game (menu_loop; a level code goes straight
; in), on a black screen in the ROM's font: a letter every
; CFG_STORY_CHAR 1/50 seconds with a click, a pause of CFG_STORY_PARA at
; each paragraph, then CFG_STORY_END or a key, and the game. Any key
; skips it, straight to the game; a key already down when it starts
; must be let go first, or the 1 that started it would skip it.
;
; Only where boot goes to the menu (TYPEWRITER, main.asm): the soak, the
; measurements and the other test builds go straight to their work.
; All of it is in the cold block: it runs before a game, not in one.
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
; story_show - type the story, then the game. menu_loop jumps here.
;------------------------------------------------------------------------------
story_show:
        ld a,BLACK
        call set_border
        ld a,STORY_ATTR
        call cls
        xor a
        ld (story_armed),a      ; the 1 must be let go first
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
        call keys_up            ; the skipping key does not reach the game
        ld sp,STACK_TOP         ; a skip leaves story_wait's return behind
        jp game_reset

; A = 1/50 seconds to wait. A fresh key skips the rest: to the game.
; Corrupts: AF, DE (and the stack, when it skips: story_done resets it)
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

; screen_pause - boot, before the menu: the loading screen, still on the
; screen, for CFG_SCREEN_PAUSE more 1/50 seconds, or until a key.
; Corrupts: AF, D
screen_pause:
    IF CFG_SCREEN_PAUSE
        ld d,CFG_SCREEN_PAUSE
.frame: call wait_frame
        call any_key
        ret nz
        dec d
        jr nz,.frame
    ENDIF
        ret
        ASSERT CFG_SCREEN_PAUSE <= 255

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
story_attr:     db 0            ; text_attr as it was, for the menu's next visit

    IFDEF TRIGON
; Trigon's, after the Atlantis ending, broken by hand for 30 columns.
story_text:
        ; Finale's (wording for Dalix to approve). 30 letters a line at most.
        db "This is it.", STORY_PARA
        db "You carry the bomb. Trigon", STORY_NL
        db "will throw everything at you.", STORY_PARA
        db "Get through, drop the bomb", STORY_NL
        db "into the Trigon power", STORY_NL
        db "generator, destroy the city,", STORY_NL
        db "and break the blockade on", STORY_NL
        db "Atlantis.", 0
    ELSE
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
    ENDIF
