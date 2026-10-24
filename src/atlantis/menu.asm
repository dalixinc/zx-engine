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

menu_prev:      db 0            ; last frame's 1-2-3-4-5 keys
leave_prev:     db 0            ; last frame's Symbol Shift + P
menu_game_over: db 0            ; 1 = the last life was lost: say GAME OVER

;------------------------------------------------------------------------------
; game_over - the last life is gone. Jumped to from the main loop, never
; called, so the stack is the main loop's and nothing is left on it.
;------------------------------------------------------------------------------
game_over:
        ld a,1
        ld (menu_game_over),a
        ; fall through

;------------------------------------------------------------------------------
; enter_menu - clear the play picture and draw this screen
; Does not move the diver, the fish or the bomb. draw_scenery rebuilds
; the seabed from column 0, which is what the player sees behind the words.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
enter_menu:
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
        ld (stats_dirty),a
        ld (stats_template_up),a

        call draw_scenery
        call menu_draw
        call menu_draw_game_over
        call menu_arm
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
        call menu_poll
        jr nc,menu_loop
        jp game_reset

;------------------------------------------------------------------------------
; menu_draw_game_over - GAME OVER under the options, after the last life
; Starting a new game clears the flag, so a return with Symbol Shift + P
; does not say it.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
menu_draw_game_over:
        ld a,(menu_game_over)
        or a
        ret z
        ld a,GAME_OVER_ATTR
        ld (text_attr),a
        ld hl,str_game_over
        ld bc,(15 << 8) | 11
        jp print_string

;------------------------------------------------------------------------------
; menu_draw - title, four control lines, then every row of menu_tab
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
menu_draw:
        ld a,TITLE_ATTR
        ld (text_attr),a
        ld hl,str_title
        ld bc,(2 << 8) | 12
        call print_string

        ld a,WATER_ATTR
        ld (text_attr),a
        ld hl,str_ctrl_swim
        ld bc,(5 << 8) | 4
        call print_string
        ld hl,str_ctrl_stats
        ld bc,(6 << 8) | 4
        call print_string
        ld hl,str_ctrl_speed
        ld bc,(7 << 8) | 4
        call print_string
        ld hl,str_ctrl_menu
        ld bc,(8 << 8) | 4
        call print_string

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
        scf
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

; Out: A nonzero if P is down. P is the outside key on its half-row.
; The chord itself is chords_poll, which reads Symbol Shift once for
; all three chords.
leave_key_p:
    IFDEF SOAK
        ld a,(soak_p)
        cp $FF
        jr z,.hw
        ret
.hw:
    ENDIF
        ld bc,ROW_P_Y * 256 + ULA_PORT
        in a,(c)
        cpl
        and %00000001
        ret

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
        ld a,WATER_ATTR
        call cls
        xor a
        ld (diver_bg),a
        ld (fish_bg),a
        ld (wheel_bg),a
        ld (wheel_attr_n),a
        ld (stats_on),a
        ld (stats_dirty),a
        ld (stats_template_up),a
        ld a,7
        ld (stats_phase),a

        ld a,CFG_LIVES
        ld (lives),a
        xor a
        ld (hit_flash),a
        ld (menu_game_over),a

        ld a,60
        ld (diver_x),a
        ld a,110
        ld (diver_y),a
        xor a
        ld (diver_facing),a
        ld (diver_moving),a
        ld (diver_anim),a

        ld a,180
        ld (fish_x),a
        ld a,FISH_SWIM_Y
        ld (fish_y),a
        ld a,FACE_LEFT
        ld (fish_facing),a

        call wheel_reset

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
        cp 50
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
        ld a,MEAS_STATS
        ld (stats_on),a
        ld a,MEAS_RATE
        call rate_apply
    ENDIF
    IFDEF TIMING_BARS
        ; The border clock can be asked to turn the digits on, so a
        ; stripe shows what they cost. Left out, the digits stay off.
        IFDEF MEAS_STATS
        ld a,MEAS_STATS
        ld (stats_on),a
        ENDIF
    ENDIF

        call stats_arm
        call rate_arm
        call leave_arm
        call draw_scenery
        ; Start the first picture on an interrupt, so the work below
        ; begins while the beam is still in the top border.
        call wait_frame
        jp main_loop
