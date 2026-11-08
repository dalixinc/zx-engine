;==============================================================================
; trigon/twobomb.asm - a second bomb, of the same type (TWO_BOMBS)
;
; A wave in Trigon is a bomb and a fish, or two bombs. The second bomb
; takes the fish's place: when a new fish is due (fish_wait_step,
; boom.asm), the level's share (TB_TABLE, config.asm) decides whether a
; second bomb comes instead, and the fish waits until it has gone.
;
; The second bomb is the first one's code assembled again, in its own
; module, b2: src/atlantis/wheel.asm and the bomb's movers from
; level.asm, with B2_PASS defined (which keeps its once-a-bomb code with
; the rest, out of the cold block). So b2.wheel_x, b2.update_wheel and
; the rest are its own, and it costs exactly what the first bomb costs.
; It is the same type as the first (the level's), with its own colour
; and movement from the table, and its own background record (tb_bg)
; and shift register (so it picks other heights). It lives in the data
; block, which is uncontended like the code.
;
; The main loop restores it just before the fish, and draws it and its
; colours just after (where the fish would be), so it is always drawn
; before the seabed copy: like the first bomb, it never reaches the
; weed.
;==============================================================================

    IFDEF TWO_BOMBS

        DEFINE B2_PASS
        MODULE b2
wheel_bg        equ tb_bg               ; its own photograph
level_ink       equ tb_ink              ; its colour and movement: this
level_bmove     equ tb_bmove            ; wave's row of TB_TABLE, not
level_hunt      equ tb_hunt             ; the level's
        INCLUDE "../atlantis/wheel.asm"
        INCLUDE "../atlantis/level.asm"
        ENDMODULE
        UNDEFINE B2_PASS

;------------------------------------------------------------------------------
; Two bombs at 25 (tb_slow, the menu's option 3): at 50 frames a second
; the second bomb does not fit in the frame (docs/TRIGON.md), so while
; one is out the game can drop to 25, and go back to 50 once it has
; gone. The speed is changed at the start of a step (in tb_restore), as
; Symbol Shift + F changes it, never in the middle of one: the 25 idle
; frame sets step_ticks itself round its moves. tb_want asks for it.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; tb_restore, tb_draw, tb_move - main_loop: before the fish's restore,
; after its draw, after the first bomb's move (and idle_move's)
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
tb_restore:
        ld a,(tb_want)
        or a
        call nz,tb_rate         ; a speed asked for: now, at the step's start
        ld iy,tb_bg
        jp fast_restore

; A = 25 or 50, from tb_want. Corrupts: AF, HL
tb_rate:
        call rate_apply
        xor a
        ld (tb_want),a
        ret

tb_draw:
        call b2.wheel_draw
        jp b2.wheel_colours

tb_move:
    IFDEF MEAS_TWO
        ld a,(tb_meas_fish)     ; measuring two bombs: no fish, from the
        or a                    ; first step (game_reset's boom_reset has
        jr nz,.nofish           ; just sent one swimming)
        inc a
        ld (tb_meas_fish),a
        call fish_begin_wait
.nofish:
    ENDIF
        ld a,(b2.wheel_phase)
        or a
    IFDEF MEAS_TWO
        jp z,tb_go              ; measuring: always out
    ELSE
        jr z,tb_idle            ; waiting for the fish's slot
    ENDIF
        jp b2.update_wheel

; No second bomb out: if the game dropped to 25 for the last one, back
; to 50 at the next step's start. Corrupts: AF
tb_idle:
        ld a,(tb_forced)
        or a
        jr z,.off
        xor a
        ld (tb_forced),a
        ld a,(game_rate)
        cp 25
        ret nz                  ; Symbol Shift + F has changed it since
        ld a,50
        ld (tb_want),a          ; the next step's tb_restore asks for it
        ret
.off:   ld a,(tb_want)
        or a
        ret nz                  ; a speed still to ask for
        ld a,TB_CALLS_OFF       ; gone, wiped and its colours given back:
        ; fall through          ; nothing more until the next one

;------------------------------------------------------------------------------
; tb_calls - main_loop's four calls to tb_restore, tb_draw and tb_move
; (two) are CALLs only while a second bomb is out, and until the steps
; after it has gone have wiped it, given its cells back and put the
; speed back. Otherwise each is LD HL,nn: 10 T-states, against some
; hundreds a step for the three routines finding nothing to do.
; In: A = TB_CALLS_ON or TB_CALLS_OFF. Corrupts: nothing else
;------------------------------------------------------------------------------
tb_calls:
        ld (main_loop.tb_c1),a
        ld (fish_draw_call.tb_c2),a
        ld (fish_mv.tb_c3),a
        ld (fish_mv2.tb_c4),a
        ret
TB_CALLS_ON     equ $CD                 ; CALL nn
TB_CALLS_OFF    equ $21                 ; LD HL,nn: HL is free at all four
        ASSERT ({main_loop.tb_c1} & $FF) == $CD && {main_loop.tb_c1 + 1} == tb_restore, ".tb_c1 is not CALL tb_restore"
        ASSERT ({fish_draw_call.tb_c2} & $FF) == $CD && {fish_draw_call.tb_c2 + 1} == tb_draw, ".tb_c2 is not CALL tb_draw"
        ASSERT ({fish_mv.tb_c3} & $FF) == $CD && {fish_mv.tb_c3 + 1} == tb_move, ".tb_c3 is not CALL tb_move"
        ASSERT ({fish_mv2.tb_c4} & $FF) == $CD && {fish_mv2.tb_c4 + 1} == tb_move, ".tb_c4 is not CALL tb_move"

;------------------------------------------------------------------------------
; The hits: hit_check and torpedo_hit (hit.asm, torpedo.asm) go on to the
; second bomb where they would have gone on to the fish (HIT_NO_BOMB,
; HIT_MISSED, TORP_NOT_BOMB), then to the fish. The same boxes as the
; first bomb's.
;------------------------------------------------------------------------------
; The diver against the second bomb, then the fish. Out: carry set if
; he was hit (diver_hurt). Corrupts: AF, BC, DE, HL
tb_hit_none:
        call tb_diver
        ret c
        jp fish_hit
tb_hit_miss:
        call tb_diver
        ret c
        jp fish_cheap
tb_diver:
    IFDEF MEASURE
        or a                    ; measuring: it passes through him, so the
        ret                     ; diver on the seabed lives (carry clear)
    ENDIF
        ld a,(b2.wheel_phase)
        or a
        ret z                   ; none out (carry clear)
        ld hl,(b2.wheel_x)
        ld a,(diver_x)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld de,-HIT_X_LO
        add hl,de
        ld a,h
        or a
        ret nz                  ; carry clear: OR
        ld a,l
        cp HIT_X_SPAN
        ret nc                  ; missed (carry clear)
        ld a,(diver_y)
        ld b,a
        ld a,(b2.wheel_y)
        sub b
        add a,-HIT_Y_LO
        cp HIT_Y_SPAN
        ret nc
        call b2.wheel_remove
        call tb_boom
        jp diver_hurt           ; carry set

; A running torpedo against the second bomb, then the fish (torpedo_hit's
; own y span, which the double shot may patch). Corrupts: AF, BC, DE, HL
tb_torpedo:
        ld a,(b2.wheel_phase)
        or a
        jp z,torpedo_fish
        ld hl,(b2.wheel_x)
        ld de,(torp_x)
        or a
        sbc hl,de
        ld de,-TORP_X_LO
        add hl,de
        ld a,h
        or a
        jp nz,torpedo_fish
        ld a,l
        cp TORP_X_SPAN
        jp nc,torpedo_fish
        ld a,(torp_y)
        ld b,a
        ld a,(b2.wheel_y)
        sub b
        add a,-TORP_Y_LO
        ld hl,torpedo_hit.yspan + 1
        cp (hl)
        jp nc,torpedo_fish
        call b2.wheel_remove
        call tb_boom
        ld a,(level_pts_bomb)
        call score_add
        jp torpedo_spent

; The burst over the second bomb, as boom_at_bomb's over the first.
tb_boom:
    IFNDEF NO_SOUND
        call snd_boom_start
    ENDIF
        call boom_show_fish
        ld hl,(b2.wheel_x)
        ld a,(b2.wheel_y)
        jp boom_arm

    IFDEF POWERUPS
;------------------------------------------------------------------------------
; The special bombs (special.asm) on the second bomb, as on the first:
; suction pulls its middle down, shove throws it to the right edge,
; where it blows up and scores (and at the end), the nuke takes it.
;------------------------------------------------------------------------------
; sp_tick, each 1/50 second a special lasts. Corrupts: AF, DE, HL
tb_sp_tick:
        ld a,(b2.wheel_phase)
        or a
        ret z
        ld a,1
        ld (b2.wheel_odd),a     ; more than a pixel: the whole bomb repainted
        ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        jr z,.shove
        ld a,(b2.wheel_base)
        cp SUCK_BOMB_LOW
        ret nc
        add a,CFG_SUCTION_SPEED
        cp SUCK_BOMB_LOW + 1
        jr c,.base
        ld a,SUCK_BOMB_LOW
.base:  ld (b2.wheel_base),a
        ret
.shove: ld hl,(b2.wheel_x)
        ld de,CFG_SHOVE_SPEED
        add hl,de
        ld a,h
        inc a
        jr z,.bx                ; still off the left
        dec a
        jr nz,.bmax             ; 256 or more
        ld a,l
        cp SHOVE_BOMB_MAX
        jr c,.bx
.bmax:  ld hl,SHOVE_BOMB_MAX
        ld (b2.wheel_x),hl
        ld a,(boom_t)           ; one burst at a time: it waits for the last
        or a
        ret nz
        jr tb_kill
.bx:    ld (b2.wheel_x),hl
        ret

; Blown up, as a torpedo would: the burst and the points.
; Corrupts: AF, BC, DE, HL
tb_kill:
        ld a,(b2.wheel_phase)
        or a
        ret z
        call b2.wheel_remove
        call tb_boom
        jp sp_score

; Suction's end: it pulled the second bomb out of the way too.
tb_sucked:
        ld a,(b2.wheel_phase)
        or a
        ret z
        call sp_score
        ld hl,(b2.wheel_x)
        ld a,(b2.wheel_y)
        jp pop_here

; The nuke: gone, its burst only if the first bomb has none.
tb_nuke:
        ld a,(b2.wheel_phase)
        or a
        ret z
        call b2.wheel_remove
        call sp_score
        ld a,(wheel_phase)
        or a
        ret nz
        jp tb_boom

    ENDIF

    IFDEF FISH_LEAVES
;------------------------------------------------------------------------------
; fish_once - the fish's move (fish_mv, fish_mv2) in Trigon: the level's
; own (fish_unhold patches .real), then, if that turned it at the left
; edge, it has crossed once and goes: no burst, no points. Its draw is
; dropped on the next step (the restore takes it away) and the usual
; wait follows, so the next wave, a fish or two bombs (tb_launch), comes
; sooner than if it swam back. About 40 T-states a move.
; Corrupts: AF, B, HL (and what the mover does)
;------------------------------------------------------------------------------
fish_once:
.real:  call update_fish
        ld a,(fish_facing)
        cp FACE_RIGHT
        ret nz
        call fish_hold          ; no second move this step (at 25)
        ld a,1
        ld (fish_busy),a        ; nothing hits it meanwhile
        ld hl,fish_gone_draw
        ld (FISH_DRAW_TO),hl
        ret
        ASSERT FISH_MIN_X == 0  ; it turns only at the left edge, facing right

; In the fish's draw place, its restore just done: not drawn again.
fish_gone_draw:
        ld iy,fish_bg
        ld (iy+BG_VALID),0
        jp fish_begin_wait
    ENDIF

;------------------------------------------------------------------------------
; tb_launch - fish_wait_step, as a new fish is due: two bombs instead?
; Out: carry set if the second bomb has gone out (the fish waits again).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
tb_launch:
        ld a,(tb_share)
        or a
        ret z                   ; none on this level (carry clear)
        ld b,a
        call b2.wheel_rng
        cp b
        ret nc                  ; a fish this time
tb_go:  ld a,TB_CALLS_ON
        call tb_calls
        ld a,(wheel_haste)      ; the level's haste, as the first bomb's
        ld (b2.wheel_haste),a
        call b2.wheel_drift.spawn ; in from the right edge, at its own height
        ld a,(tb_slow)
        or a
        jr z,.go
        ld a,(game_rate)
        cp 50
        jr nz,.go               ; at 25 already
        ld (tb_forced),a        ; not 0: put 50 back afterwards
        ld a,25
        ld (tb_want),a
.go:    scf
        ret

;------------------------------------------------------------------------------
; tb_reset - a new game, and the menu: no second bomb out, nothing of it
; on the screen to put back
; Corrupts: AF
;------------------------------------------------------------------------------
tb_reset:
        ld a,(tb_forced)        ; the menu: the speed it was chosen at
        or a
        ld a,50
        call nz,rate_apply
        xor a
        ld (tb_forced),a
        ld (tb_want),a
        ld (b2.wheel_phase),a
        ld (b2.wheel_attr_n),a
        ld (b2.wheel_shown),a
        ld (tb_bg + BG_VALID),a
        ld a,TB_SEED
        ld (b2.wheel_seed),a
    IFDEF MEAS_TWO
        ld (tb_meas_fish),a     ; A is not 0: TB_SEED
        xor a
        ld (tb_meas_fish),a
        ret                     ; measuring: the calls stay, as it is always out
    ELSE
        ld a,TB_CALLS_OFF
        jp tb_calls
    ENDIF
    IFDEF MEAS_TWO
tb_meas_fish:   db 0
    ENDIF

;------------------------------------------------------------------------------
; tb_level - level_style, on a new level: its row of TB_TABLE into
; tb_share and the second bomb's settings. A second bomb out keeps its
; own until it has gone, as the first does.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
tb_level:
        ld a,(level_n)
        cp TB_ROWS + 1
        jr c,.row
        ld a,TB_ROWS            ; past the table: the last row again
.row:   dec a
        add a,a
        add a,a                 ; 4 bytes a row
        ld e,a
        ld d,0
        ld hl,tb_table
        add hl,de
        ld de,tb_share
        ld bc,4
        ldir
    IFDEF LANCEGUN
        jp lance_level          ; is the Lance his now? (lance.asm)
    ELSE
        ret
    ENDIF

        MACRO TB_ROW share?, ink?, bmove?, hunt?
        ASSERT share? >= 0 && share? <= 255
        ASSERT bmove? == MOVE_BOB || bmove? == MOVE_WAVE || bmove? == MOVE_HOME
        ASSERT bmove? != MOVE_HOME || (hunt? >= 1 && hunt? <= 128), "a hunter's hunt is 1 to 128"
        ASSERT bmove? == MOVE_HOME || hunt? == 0, "only MOVE_HOME hunts: hunt 0"
        db share?, ink?, bmove?, hunt?
        ENDM
tb_table:
        TB_TABLE
TB_ROWS         equ ($ - tb_table) / 4
        ASSERT TB_ROWS >= 1

;------------------------------------------------------------------------------
; tb_toggle - the menu's option 3: two bombs at 25, or at the game's own
; speed, and the line again. Out: carry clear (stay on the menu).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
    IFDEF CODE_GATE
tb_toggle:
        ld a,(tb_slow)
        xor 1
        ld (tb_slow),a
        ld hl,'5' | ('0' << 8)  ; "50"
        jr z,.text
        ld hl,'2' | ('5' << 8)  ; "25"
.text:  ld (str_tb_opt + TB_OPT_DIGITS),hl
        ld a,WATER_ATTR
        ld (text_attr),a
        ld hl,str_tb_opt
        ld bc,(TB_OPT_ROW << 8) | 4
        call print_string
        or a
        ret
str_tb_opt:     db "3  Two bombs at 25 a second",0
TB_OPT_DIGITS   equ 16                  ; where the "25" is
TB_OPT_ROW      equ CODE_ROW + 2
    ENDIF

    IFDEF MEASURE
tb_slow:        db 0                    ; measuring: the speed MEAS_RATE asks for
    ELSE
tb_slow:        db 1                    ; 1 = drop to 25 while a second bomb is out
    ENDIF
tb_forced:      db 0                    ; not 0 = it dropped: put 50 back
tb_want:        db 0                    ; 25 or 50: change at the next step's start

; This wave's second bomb (tb_level fills them from TB_TABLE).
tb_share:       db 0                    ; two-bomb waves in 256 on this level
tb_ink:         db 0
tb_bmove:       db 0
tb_hunt:        db 0
TB_SEED         equ 137                 ; not the first bomb's 42: other heights

    ENDIF

;------------------------------------------------------------------------------
; bomb_art - wheel_type, as each bomb appears: A = its kind (BOMB_P or
; BOMB_W). The pulsar and the spinning wheel share one room for their
; shifted copies (SHARED_BOMB, preshift.asm), which holds one kind at a
; time; start-up makes the pulsar's. A bomb of the other kind has them
; made again first, from its art: once a level, at most, while the last
; bomb has gone and the next is just off the right edge. A second bomb
; still out takes the new pictures too (it keeps flying, as the new
; kind). Out: A as it was. Corrupts: F, BC, DE, HL, IX
;------------------------------------------------------------------------------
    IFDEF SHARED_BOMB
bomb_art:
        ld hl,bomb_built
        cp (hl)
        ret z
        ld (hl),a
        push af
        ld hl,bomb_job_spin
        cp BOMB_W
        jr z,.make
        ld hl,bomb_job_pulsar
.make:  call preshift_list
    IFDEF TWO_BOMBS
        ld a,(b2.wheel_phase)
        or a
        call nz,b2.wheel_type
    ENDIF
        pop af
        ret
bomb_built:     db BOMB_P               ; start-up made the pulsar's

; tb_art_now - level_up, with the "LEVEL n" banner just painted: if the
; new level's bomb is the other kind, its pictures are made now, while
; the banner holds the eye, not when its first bomb appears. A bomb
; still out takes the new kind at once (wheel_type), as bomb_art does
; to the second; it is repainted whole, as its box may change.
; Corrupts: AF, BC, DE, HL, IX
tb_art_now:
        ld a,(level_bomb)
        ld hl,bomb_built
        cp (hl)
        ret z
        ld a,(wheel_phase)
        or a
        ld a,(level_bomb)
        jp z,bomb_art
        ld a,1
        ld (wheel_odd),a
        jp wheel_type
bomb_job_pulsar:
        PRESHIFT_JOB wheel_src, WHEEL_BUF, WHEEL_PICS, WHEEL_HEIGHT, WHEEL_WIDE, WHEEL_RAW, 0
        dw 0
bomb_job_spin:
        PRESHIFT_JOB wspin_src, WSPIN_BUF, WSPIN_PICS, WSPIN_HEIGHT, WSPIN_WIDE, WSPIN_RAW, 0
        dw 0
    ENDIF
