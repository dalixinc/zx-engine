;==============================================================================
; menu.asm - the start screen, and coming back to it
;
; The play screen has no words on it. This screen is the title, the
; controls, and a numbered list. The list is menu_tab in data.asm.
; Adding a later option is a row in that list and a small routine here.
; It does not need a change to this loop.
;
; Keys 1 to 5 are the row. Key 1 starts. Key 2 swaps 50 and 25 frames a
; second and reprints that line, so the menu always shows the choice the
; game will start in. The choice survives a return to this screen.
;
; Symbol Shift + P during play comes back here. P on its own does not.
; The edge is the same rule as the other two chords: the moment both
; keys go down. Coming back does not wipe the diver or the bomb. Starting
; does. That way a check can still see the old game, and a new game is a
; clean one.
;==============================================================================

CODE_ROW        equ 13          ; option 3, and the code typed into it
CODE_COL        equ 12          ; its first letter

menu_prev:      db 0            ; last frame's 1-2-3-4-5 keys
leave_prev:     db 0            ; last frame's Symbol Shift + P
menu_game_over: db 0            ; 1 = the last life was lost: say GAME OVER

        ; The menu runs from the cold block (main.asm), apart from
        ; leave_key_p, which chords_poll reads every step.
        COLD

;------------------------------------------------------------------------------
; game_over - the last life is gone. Jumped to from the main loop, never
; called, so the stack is the main loop's and nothing is left on it.
;------------------------------------------------------------------------------
game_over:
    IFDEF AUTOPLAY
        ld a,(demo_on)
        or a
        jp nz,enter_menu        ; a demo: no knell, no high score
    ENDIF
    IFNDEF NO_SOUND
        call snd_knell          ; the last picture stays up while it plays
    ENDIF
        call score_game_over    ; a new high score?
        ld a,1
        ld (menu_game_over),a
        ; fall through

;------------------------------------------------------------------------------
; enter_menu - clear the play picture and draw this screen
; Does not move the diver, the fish or the bomb. draw_scenery rebuilds
; the seabed from column 0, which is what the player sees behind the words.
; Corrupts: AF, BC, DE, HL, IX
;
; Symbol Shift + P jumps here from inside chords_poll, so its return
; address is still on the stack. Nothing here returns, so the stack is
; simply started again. Without that, each trip to the menu left two
; bytes behind. At boot SP is already STACK_TOP, so it changes nothing.
;------------------------------------------------------------------------------
enter_menu:
        ld sp,STACK_TOP
    IFDEF SOAK
        ; Phase 2 is the play test that tries P on its own. That press
        ; must not arrive here. The real press sets the allow flag first.
        ld a,(soak_phase)
        cp 2
        jr nz,.allowed
        ld a,(soak_allow_leave)
        or a
        jr nz,.leave_ok
        ld a,13
        jp soak_fail
.leave_ok:
        ld a,3
        ld (soak_phase),a
        xor a
        ld (soak_menu_step),a
        ld (soak_keys),a
.allowed:
    ENDIF
        ld a,BLUE
        call set_border
        ld a,WATER_ATTR
        call cls

        ; The photographs and the bomb's ink rectangle belong to the
        ; picture we just threw away. Leaving them set would paint that
        ; picture back over the menu, or over the next game.
        xor a
        ld (diver_bg),a
        ld (fish_bg),a
        ld (wheel_bg),a
        ld (wheel_attr_n),a
    IFDEF STATS
        ld (stats_dirty),a
        ld (stats_template_up),a
    ENDIF
        call torpedo_reset

        call draw_scenery
        call menu_draw
        call menu_draw_game_over
        call menu_arm
    IFDEF AUTOPLAY
        call demo_off           ; the keyboard again, and the demo's wait
    ENDIF
        ; fall through

;------------------------------------------------------------------------------
; menu_loop - wait for a key whose routine starts the game
; A routine returns with the carry set to start, or clear to stay.
;------------------------------------------------------------------------------
menu_loop:
    IFDEF SOAK
        call soak_on_menu
    ENDIF
        call wait_frame
    IFDEF POWERUPS
        call cheat_poll         ; missile.asm
    ENDIF
        call menu_poll
    IFDEF AUTOPLAY
        jr c,.go
        call demo_idle          ; long enough without a key: the demo
        jr menu_loop
.go:
    ELSE
        jr nc,menu_loop
    ENDIF
    IFDEF TYPEWRITER
        ld a,(start_level)
        dec a
        jp z,story_show         ; 1: the story, then the game (story.asm)
    ENDIF
        jp game_reset           ; a level code: straight in

;------------------------------------------------------------------------------
; menu_draw_game_over - GAME OVER under the options, after the last life
; Starting a new game clears the flag, so a return with Symbol Shift + P
; does not say it.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
menu_draw_game_over:
        ld a,WATER_ATTR
        ld (text_attr),a
        ld hl,str_high          ; the high score, always
        ld bc,(19 << 8) | 10
        call print_string
        ld hl,hiscore
        call menu_print_score
        ld a,(menu_game_over)
        or a
        ret z
        ld hl,str_score         ; the last game's, after GAME OVER
        ld bc,(17 << 8) | 10
        call print_string
        ld hl,score
        call menu_print_score
        call menu_print_code
        ld a,GAME_OVER_ATTR
        ld (text_attr),a
        ld hl,str_game_over
        ld bc,(15 << 8) | 11
        jp print_string

; The highest level reached and its code, under the score: the level
; the game ended on, since levels only go up. Past the last code, the
; last code. Level 1 has none. Corrupts: AF, BC, DE, HL
menu_print_code:
        ld a,(level_n)
        cp CFG_CODE_LEVELS + 1
        jr c,.has
        ld a,CFG_CODE_LEVELS
.has:   cp 2
        ret c
        push af
        call code_text
        ld hl,str_level_sp
        ld bc,(18 << 8) | 6
        call print_string
        pop af
        ld e,'0'                ; tens
.tens:  cp 10
        jr c,.units
        sub 10
        inc e
        jr .tens
.units: push af
        ld a,e
        cp '0'
        call nz,print_char
        pop af
        add a,'0'
        call print_char
        inc c
        ld hl,str_code_word
        call print_string
        ld hl,code_buf
        jp print_string

; HL = a BCD score, low byte first. Six digits at B, C.
; Corrupts: AF, DE, HL. C advances by 6.
menu_print_score:
        inc hl
        inc hl                  ; the top byte first
        ld e,3
.pair:  ld a,(hl)
        push hl
        push de
        push af
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        call print_char
        pop af
        and 15
        add a,'0'
        call print_char
        pop de
        pop hl
        dec hl
        dec e
        jr nz,.pair
        ret

;------------------------------------------------------------------------------
; title_draw - ATLANTIS in the tall letters (udg.asm), rows 2 and 3,
; columns 12 to 19: the top halves in the title's yellow, the bottom
; halves in black. Each letter is 16 rows: the top 8 in row 2, the
; bottom 8 in row 3.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
TITLE_ROW       equ 2
    IFDEF TRIGON
TITLE_LEN       equ 6           ; TRIGON
    ELSE
TITLE_LEN       equ 8           ; ATLANTIS
    ENDIF
TITLE_COL       equ (32 - TITLE_LEN) / 2
title_draw:
        ld hl,title_word
        ld c,TITLE_COL
.char:  ld a,(hl)
        inc hl
        push hl
        add a,a                 ; 16 bytes a letter
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,title_font
        add hl,de
        ex de,hl                ; DE = the letter
        ld b,TITLE_ROW
        call .cell
        ld b,TITLE_ROW + 1
        call .cell
        pop hl
        inc c
        ld a,c
        cp TITLE_COL + TITLE_LEN
        jr c,.char
        ; The colours: the top halves yellow, the bottom halves black.
        ; The stencil cut is the first line of row 3, so the change of
        ; colour falls on it.
        ld hl,ATTRS + TITLE_ROW * 32 + TITLE_COL
        ld c,TITLE_ATTR
        call .attrs
        ld hl,ATTRS + (TITLE_ROW + 1) * 32 + TITLE_COL
        ld c,TITLE_LOW_ATTR
.attrs: ld b,TITLE_LEN
.attr:  ld (hl),c
        inc l
        djnz .attr
        ret
; 8 rows of DE into the cell at row B, column C. Corrupts: AF, B, DE, HL
.cell:  push bc
        call char_addr
        pop bc
        push bc
        ld b,8
.line:  ld a,(de)
        ld (hl),a
        inc de
        inc h
        djnz .line
        pop bc
        ret

    IFDEF TRIGON
; TRIGON: title_font is T R I G O N (udg.asm).
title_word:     db 0, 1, 2, 3, 4, 5
    ELSE
; ATLANTIS as letters of title_font: A 0, T 1, L 2, N 3, I 4, S 5.
title_word:     db 0, 1, 2, 0, 3, 1, 4, 5
    ENDIF
        ASSERT $ - title_word == TITLE_LEN

;------------------------------------------------------------------------------
; menu_draw - title, the control lines (the bomb key's with power-ups), then
;             every row of menu_tab
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
menu_draw:
        call title_draw

        ld a,WATER_ATTR
        ld (text_attr),a
        ld hl,str_ctrl_swim
        ld bc,(5 << 8) | 4
        call print_string
    IFDEF STATS
        ld hl,str_ctrl_stats
        ld bc,(6 << 8) | 4
        call print_string
CTRL_ROW        equ 7
    ELSE
CTRL_ROW        equ 6           ; the tape has no stat line to switch on
    ENDIF
        ld hl,str_ctrl_speed
        ld bc,(CTRL_ROW << 8) | 4
        call print_string
        ld hl,str_ctrl_menu
        ld bc,((CTRL_ROW + 1) << 8) | 4
        call print_string
    IFDEF POWERUPS
        ld hl,str_ctrl_bomb     ; sets off a carried special bomb (special.asm)
        ld bc,((CTRL_ROW + 2) << 8) | 4
        call print_string
    ENDIF

        ld hl,menu_tab
.item:  ld a,(hl)
        or a
        ret z
        inc hl
        ld b,(hl)               ; character row
        inc hl
        ld c,(hl)               ; character column
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; words, or 0 for the speed line
        inc hl
        inc hl                  ; step over the routine; drawing does not call it
        inc hl
        push hl
        ld a,d
        or e
        jr z,.rate
        ex de,hl
        call print_string
        jr .next
.rate:  call menu_print_rate
.next:  pop hl
        jr .item

; The speed line. BC is the row and column. The two sentences are the
; same length, so one sits exactly on top of the other.
menu_print_rate:
        ld a,(game_rate)
        cp 25
        ld hl,str_rate50
        jr nz,.go
        ld hl,str_rate25
.go:    jp print_string

; Find the speed row (the row whose words are 0) and print it again.
menu_reprint_rate:
        ld hl,menu_tab
.find:  ld a,(hl)
        or a
        ret z
        push hl
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr z,.here
        pop hl
        ld de,7
        add hl,de
        jr .find
.here:  pop hl
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld a,WATER_ATTR
        ld (text_attr),a
        jr menu_print_rate

;------------------------------------------------------------------------------
; menu_poll - a key that has just gone down runs its routine
; Out: carry set if that routine started the game.
;      menu_prev remembers the whole row, so a key that is held does not
;      run a second time.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
menu_poll:
        call menu_read_keys
        ld e,a
        ld hl,menu_tab
.item:  ld a,(hl)
        or a
        jr z,.stay
        ld d,a                  ; this option's mask
        ld a,(menu_prev)
        and d
        jr nz,.skip             ; it was already down
        ld a,e
        and d
        jr z,.skip              ; it is up now
        push hl
        push de
        ld de,5
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call menu_call_hl
        pop de
        pop hl
        jr c,.start
.skip:  ld a,l
        add a,7
        ld l,a
        jr nc,.item
        inc h
        jr .item
.stay:  ld a,e
        ld (menu_prev),a
        or a                    ; clear carry: stay on the menu
        ret
.start: ld a,e
        ld (menu_prev),a
        scf
        ret

; HL = routine. The called routine's carry comes back to us.
menu_call_hl:
        jp (hl)

; Out: A = bits of the 1-2-3-4-5 row that are down. Bit 0 is key 1.
menu_read_keys:
    IFDEF SOAK
        ld a,(soak_keys)
        ret
    ENDIF
        ld bc,ROW_1_5 * 256 + ULA_PORT
        in a,(c)
        cpl
        and %00011111
        ret

menu_arm:
        call menu_read_keys
        ld (menu_prev),a
        ret

;------------------------------------------------------------------------------
; The two routines the table points at.
; menu_start        sets carry. The loop then calls game_reset.
; menu_toggle_rate  flips the speed, reprints the line, carry clear.
;------------------------------------------------------------------------------
menu_start:
        ld a,1
        ld (start_level),a
        scf
        ret

;------------------------------------------------------------------------------
; menu_code - option 3: six letters, then a game at that code's level
; The letters go in on the option's own line. 0 (or Delete, which is
; Caps Shift + 0) rubs one out, Space gives up. The sixth letter checks
; the code: a good one starts the game (carry set), a bad one says BAD
; CODE for a moment and puts the option back (carry clear).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
menu_code:
        ld a,WATER_ATTR
        ld (text_attr),a
        ld hl,str_code_ask
        ld bc,(CODE_ROW << 8) | 4
        call print_string
        ld hl,str_code_dots
        call print_string
        ld e,0                  ; letters so far
.key:   push de
        call keys_up            ; the 3, or the last letter, let go
.wait:  call wait_frame
        call key_char
        or a
        jr z,.wait
        pop de
        cp ' '
        jr z,.back
        cp '0'
        jr z,.rub
        cp 'A'
        jr c,.key               ; the other digits and Enter
        ld hl,code_buf
        ld d,0
        add hl,de
        ld (hl),a
        ld hl,(CODE_ROW << 8) | CODE_COL
        add hl,de
        ld b,h
        ld c,l
        inc e
        push de
        call print_char
        pop de
        ld a,e
        cp CODE_LEN
        jr c,.key
    IFDEF CITY_SHOW
        call il_menu_code       ; the city's own code: shown, then the menu
    ENDIF
        call code_level
        or a
        jr z,.bad
        ld (start_level),a
        scf
        ret
.rub:   ld a,e
        or a
        jr z,.key
        dec e
        ld hl,(CODE_ROW << 8) | CODE_COL
        add hl,de
        ld b,h
        ld c,l
        ld a,'.'
        push de
        call print_char
        pop de
        jr .key
.bad:   ld a,GAME_OVER_ATTR
        ld (text_attr),a
        ld hl,str_code_bad
        ld bc,(CODE_ROW << 8) | 4
        call print_string
        ld b,75                 ; a second and a half
.pause: call wait_frame
        djnz .pause
.back:  ld a,WATER_ATTR
        ld (text_attr),a
        ld hl,str_opt_code
        ld bc,(CODE_ROW << 8) | 4
        call print_string
        call keys_up
        call menu_arm
        or a
        ret

menu_toggle_rate:
        ld a,(game_rate)
        cp 25
        ld a,50
        jr z,.set
        ld a,25
.set:   call rate_apply
        call menu_reprint_rate
        or a
        ret

        HOT
; Out: A nonzero if P is down. P is the outside key on its half-row.
; The chord itself is chords_poll, which reads Symbol Shift once for
; all three chords.
leave_key_p:
    IFDEF SOAK
        ld a,(soak_p)
        cp $FF
        jr z,.hw
        neg                     ; as stats_key_sym: through the real mask
        jr .mask
.hw:
    ENDIF
        ld bc,ROW_P_Y * 256 + ULA_PORT
        in a,(c)
        cpl
.mask:  and %00000001
        ret

        COLD
leave_arm:
        call stats_key_sym
        ld e,a
        call leave_key_p
        and e
        ld (leave_prev),a
        ret

;------------------------------------------------------------------------------
; game_reset - a clean game, in the speed the menu is showing
; The seabed is rebuilt. The diver, the fish and the bomb go back to the
; places they have when the tape loads. The stat line is hidden. A chord
; that is already down does not fire on the first step.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
game_reset:
        call death_reset        ; a death cut short by Symbol Shift + P
        ld a,WATER_ATTR
        call cls
        xor a
        ld (diver_bg),a
        ld (fish_bg),a
        ld (wheel_bg),a
        ld (wheel_attr_n),a
    IFDEF STATS
        ld (stats_on),a
        ld (stats_dirty),a
        ld (stats_template_up),a
        ld a,7
        ld (stats_phase),a
    ENDIF

        ld a,CFG_LIVES
        ld (lives),a
        call score_reset        ; 0 points, level 1, row 1 to be drawn
        xor a
        ld (hit_flash),a
        ld (menu_game_over),a

        ld a,60
        ld (diver_x),a
        ld a,DIVER_START_Y
        ld (diver_y),a
        xor a
        ld (diver_touch),a
        xor a
        ld (diver_facing),a
        ld (diver_moving),a
        ld (diver_anim),a

        ld a,180
        ld (fish_x),a
        ld a,FISH_SWIM_Y        ; its own depth and hit tests, the wave's middle
        ld (fish_wave.in + 1),a
        call fish_set_y
        xor a
        ld (fish_wave_p),a      ; boom_reset gives it the level's mover
        ld a,FACE_LEFT
        ld (fish_facing),a

        call wheel_reset
        call torpedo_reset
        call missile_reset
        call boom_reset
    IFNDEF NO_SOUND
        call snd_reset
    ENDIF

        ; Start just after an interrupt, so the first step is always at
        ; the same point in the frame, however long the menu or the
        ; start-up took. The test builds' results depend on it.
        ei
        halt
        di
        ld hl,0
        ld (frame_count),hl
    IFDEF SOAK
        ; Still with interrupts off, so the frame counter is really 0
        ; and not 0 plus the interrupt that would have landed in between.
        ld a,(soak_phase)
        cp 3
        jr nz,.soak_ei
        call soak_check_restart
.soak_ei:
    ENDIF
        ei

    IFDEF SOAK
.soak_start:
        ld a,(game_rate)
        cp CFG_START_RATE
        jr z,.rate_ok
        ld a,12
        jp soak_fail
.rate_ok:
        ld a,1
        ld (soak_phase),a
        xor a
        ld (soak_frame),a
        ld (soak_frame+1),a
        ld (soak_have_snap),a
        ld (soak_have_title),a
        ld (soak_toggles),a
        ld (soak_stats_prev),a
        ld (soak_saw_sand),a
        ld (soak_saw_silo),a
        ld (soak_saw_diver_bg),a
        ld (soak_saw_fish_bg),a
        ld (soak_saw_wheel_right),a
        ld (soak_saw_wheel_left),a
        ld (soak_saw_wheel_fish),a
        ld (soak_saw_wheel_diver),a
        ld (soak_saw_wheel_stats),a
    ENDIF

    IFDEF MEASURE
    IFDEF STATS
        ld a,MEAS_STATS
        ld (stats_on),a
    ENDIF
        ld a,MEAS_RATE
        call rate_apply
    ENDIF
    IFDEF TIMING_BARS
        ; The border clock can be asked to turn the digits on, so a
        ; stripe shows what they cost. Left out, the digits stay off.
        IFDEF MEAS_STATS
        IFDEF STATS
        ld a,MEAS_STATS
        ld (stats_on),a
        ENDIF
        ENDIF
    ENDIF

    IFDEF STATS
        call stats_arm
    ENDIF
        call rate_arm
        call leave_arm
        call draw_scenery
    IFDEF AUTOPLAY
        ld a,(demo_on)
        or a
        call nz,demo_label      ; DEMO on row 0
    ENDIF
        ; Start the first picture on an interrupt, so the work below
        ; begins while the beam is still in the top border.
        call wait_frame
        jp main_loop
        HOT
