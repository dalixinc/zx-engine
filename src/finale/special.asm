;==============================================================================
; special.asm - Finale's special bombs: shove and the nuke
;
; Two rare power-ups in the missile's slot, like the heart, each with its
; own share of the roll and its own first level (config.asm). Touching
; one does not set it off: the diver carries it, one at a time, and a new
; one replaces the one he had. Its picture is on row 1, between the speed
; and the hearts (SP_COL), in its colour. B sets it off. Both stop the
; action first and shake the screen (sp_quake), and both take the Trigon
; divers' shots off the screen.
;   shove  the bomb and the divers are thrown right, CFG_SHOVE_SPEED
;          pixels a 1/50 second for CFG_SPECIAL_TIME, and blow up at the
;          right edge, or where they are when the time runs out. A silo's
;          missile blows up at once.
;   nuke   the bomb and the divers go up at once (one burst: the bomb's,
;          or a diver's; the rest are simply gone), and a silo's missile
;          is taken away.
; Each thing a bomb clears scores its points (CFG_PTS_SHOVE, _NUKE:
; sp_score) in place of the level's, and the total shows where the burst
; was (pop_add, boom.asm). One burst at a time: a thrown thing waits at
; the edge until the burst before it is over. A diver who is still
; waiting to come stays waiting while a throw lasts, and no new bomb can
; come (WHEEL_GAP is longer).
;
; What it costs the frame:
;   - nothing held, nothing moving: nothing. B is read only while a bomb
;     is held: main_loop's call to chords_poll (.chord_call) goes through
;     sp_poll then, about 60 T-states a step.
;   - while a throw lasts: main_loop's two calls to missile_update go
;     through sp_tick (the bomb), and ed_move's two calls to ed_move1 go
;     to ed_throw1 (the divers), whose cells are painted each 1/50
;     second, as the bomb's are while it is thrown (wheel_odd).
;     msl_calls_set is the one place all four calls are set.
;   - the nuke and the shake stop the game while they run, as the knell
;     does, so they cost no frame.
;==============================================================================

    IFDEF POWERUPS

sp_held:        db 0            ; the kind he carries (MSL_KIND_SHOVE, _NUKE), 0 = none
sp_kind:        db 0            ; the kind set off last
sp_left:        db 0            ; 1/50 seconds of the throw still to go, 0 = none
sp_prev:        db 0            ; the key last step (rising_edge)

; The key: B, on port $7FFE (bit 4). Nothing else in play uses it.
SP_KEYS         equ %00010000
; Row 1: the carried bomb, in the gap between the speed and the hearts.
SP_COL          equ LIVES_COL - 1
; How far right the throw takes them: their right edges on the screen's.
SHOVE_BOMB_MAX  equ 256 - WHEEL_WIDTH
ED_EDGE         equ 256 - EDIVER_WIDTH
        ASSERT SP_COL == HUD_RATE_COL + 2, "the carried bomb's cell is not the gap left of the hearts"
        ASSERT WHEEL_GAP > CFG_SPECIAL_TIME, "a new bomb could come and be blown up by the same throw"
        ASSERT CFG_SPECIAL_TIME >= 1 && CFG_SPECIAL_TIME <= 255
        ASSERT CFG_SPECIAL_FLASH >= 1 && CFG_SPECIAL_FLASH <= 255 && CFG_SHOVE_INK <= 7 && CFG_NUKE_INK <= 7
        ASSERT CFG_SHOVE_SPEED >= 1 && CFG_SHOVE_SPEED <= 32
        ASSERT CFG_SHOVE_LEVEL >= 1 && CFG_SHOVE_LEVEL <= 99 && CFG_NUKE_LEVEL >= 1 && CFG_NUKE_LEVEL <= 99
        ASSERT CFG_PTS_SHOVE <= 99 && CFG_PTS_NUKE <= 99, "a power's points are 0 to 99"
        ASSERT MSL_KIND_SHOVE == 4 && MSL_KIND_NUKE == 5, "power_tab and the cells are in kind order"

;------------------------------------------------------------------------------
; sp_poll - in chords_poll's place while a bomb is held: the chords, then
; B, on the edge. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
sp_poll:
        call chords_poll        ; Symbol Shift + P does not come back
        ld bc,ROW_SPC_B * 256 + ULA_PORT
        in a,(c)
        and SP_KEYS             ; 0: down
        sub 1
        sbc a,a                 ; $FF: down, 0: not
        ld hl,sp_prev
        call rising_edge
        ret z
        jp special_fire

;------------------------------------------------------------------------------
; sp_tick - in missile_update's place while a throw lasts: one 1/50
; second of it for the bomb, then missile_update.
; Corrupts: AF, BC, DE, HL, IX (as missile_update)
;------------------------------------------------------------------------------
sp_tick:
        ld hl,sp_left
        dec (hl)
        call z,sp_end           ; the last one: what is left blows up
        ld a,(wheel_phase)
        or a
        jp z,missile_update
        ld a,1
        ld (wheel_odd),a        ; more than a pixel: the whole bomb repainted
        ld hl,(wheel_x)         ; 16 bits: off the left it is negative
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
.bmax:  ld hl,SHOVE_BOMB_MAX    ; at the edge, all of it on the screen
        ld (wheel_x),hl
        ld a,(boom_t)
        or a                    ; a burst is up: it waits for it
        call z,sp_bomb_kill
        jp missile_update
.bx:    ld (wheel_x),hl
        jp missile_update

;------------------------------------------------------------------------------
; ed_throw1 - in ed_move1's place (ed_move) while a throw lasts: IX's
; diver is thrown right, and blows up at the edge once no burst is up.
; One who has not come yet keeps waiting. His cells are painted each
; time (ed_paint_if, after this). Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
ed_throw1:
        ld a,(ix + ED_ON)
        or a
        ret z                   ; waiting: his wait holds until it is over
        ld (ix + ED_REPAINT),1
        ld l,(ix + ED_X)
        ld h,(ix + ED_X + 1)
        ld de,CFG_SHOVE_SPEED
        add hl,de
        bit 7,h
        jr nz,.x                ; still off the left
        ld a,h
        or a
        jr nz,.edge             ; 256 or more
        ld a,l
        cp ED_EDGE
        jr c,.x
.edge:  ld (ix + ED_X),ED_EDGE
        ld (ix + ED_X + 1),0
        ld a,(boom_t)
        or a
        ret nz                  ; a burst is up: he waits at the edge
        jp ed_shoved
.x:     ld (ix + ED_X),l
        ld (ix + ED_X + 1),h
        ret

; sp_score - this bomb's points (sp_kind) for one thing it cleared, onto
; the score and the pop-up. Corrupts: AF, BC, DE, HL
sp_score:
        ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        ld a,CFG_PTS_SHOVE
        jr z,.add
        ld a,CFG_PTS_NUKE
.add:   jp pop_add

        COLD
;------------------------------------------------------------------------------
; msl_calls_set - main_loop's two missile_update calls (.msl_uc1,
; .msl_uc2) to sp_tick and ed_move's two ed_move1 calls (.mv0, .mv1) to
; ed_throw1 while a throw lasts; else back. Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
msl_calls_set:
        ld hl,sp_tick
        ld de,ed_throw1
        ld a,(sp_left)
        or a
        jr nz,.set
        ld hl,missile_update
        ld de,ed_move1
.set:   ld (fish_mv.msl_uc1 + 1),hl
        ld (fish_mv2.msl_uc2 + 1),hl
        ld (ed_move.mv0 + 1),de
        ld (ed_move.mv1 + 1),de
        ret
        ASSERT ({fish_mv.msl_uc1} & $FF) == $CD && {fish_mv.msl_uc1 + 1} == missile_update, ".msl_uc1 is not CALL missile_update"
        ASSERT ({fish_mv2.msl_uc2} & $FF) == $CD && {fish_mv2.msl_uc2 + 1} == missile_update, ".msl_uc2 is not CALL missile_update"
        ASSERT ({main_loop.chord_call} & $FF) == $CD && {main_loop.chord_call + 1} == chords_poll, ".chord_call is not CALL chords_poll"

; sp_end - the throw's last 1/50 second: the calls go back, and what is
; still thrown blows up where it is (one burst; the rest just go).
; Corrupts: AF, BC, DE, HL, IX
sp_end:
        call msl_calls_set
        call sp_bomb_kill
        ; fall through
; sp_divers - each diver who is out goes up, for this bomb's points.
; Corrupts: AF, BC, DE, HL, IX
sp_divers:
        ld ix,ed_rec0
        call .one
        ld ix,ed_rec1
.one:   ld a,(ix + ED_ON)
        or a
        ret z
        ld a,(ix + ED_X + 1)
        dec a
        jr nz,ed_shoved
        ld (ix + ED_X),ED_EDGE  ; just off the right: the burst at the edge
        ld (ix + ED_X + 1),a
        ; fall through
; ed_shoved - IX's diver goes up, for this bomb's points.
; Corrupts: AF, BC, DE, HL
ed_shoved:
        call sp_score
        jp ed_burst

; sp_bomb_kill - the bomb, if it is out, goes up for this bomb's points.
; Corrupts: AF, BC, DE, HL
sp_bomb_kill:
        ld a,(wheel_phase)
        or a
        ret z
        call wheel_remove
        call boom_at_bomb
        jp sp_score

; HL = chords_poll or sp_poll: main_loop's call. Corrupts: nothing else
sp_chords:
        ld (main_loop.chord_call + 1),hl
        ret

;------------------------------------------------------------------------------
; special_take - he touched a special bomb: he carries it
; power_take jumps here with A = its kind - 1. Corrupts: AF, HL
;------------------------------------------------------------------------------
special_take:
        inc a
        ld (sp_held),a
        ld a,$FF
        ld (sp_prev),a          ; a key already down must go up first
        ld hl,hud_dirty
        set HUD_HEARTS,(hl)     ; its picture on row 1
        ld hl,sp_poll
        call sp_chords
        jp power_done

;------------------------------------------------------------------------------
; special_fire - B with a bomb held. Not while he dies.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
special_fire:
        ld a,(death_t)
        or a
        ret nz
        ld hl,sp_held
        ld a,(hl)
        ld (hl),0
        ld (sp_kind),a
        ld hl,hud_dirty
        set HUD_HEARTS,(hl)     ; row 1's cell back to water
        ld hl,chords_poll
        call sp_chords
        ; The border flashes its colour and black, and the screen shakes.
        ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        ld b,CFG_SHOVE_INK
        jr z,.look
        ld b,CFG_NUKE_INK
.look:  ld a,b
        ld (step_skip.flash_ink + 1),a ; the rest of the flash's colour
        ld a,CFG_SPECIAL_FLASH
        ld (chord_flash),a      ; as for a chord
        call sp_quake
    IFNDEF NO_SOUND
        ; Shove its rising slide (a thrown missile's bang cuts it short),
        ; the nuke the whoosh.
        ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        jr nz,.whoosh
        ld hl,snd_tune_shove
        call snd_tune_start
        jr .sounded
.whoosh:
        call snd_launch_start
.sounded:
    ENDIF
        ; The divers' shots go, both ways: the next steps put back what
        ; they covered, as when one leaves the screen.
        xor a
        ld (ed_rec0 + ED_SHOT),a
        ld (ed_rec1 + ED_SHOT),a
        ; A silo's missile, armed or flying: a throw blows it up, the nuke
        ; takes it away; both score. A power-up is left alone.
        ld a,(msl_phase)
        or a
        jr z,.nomsl
        ld a,(msl_kind)
        or a
        jr nz,.nomsl
        call sp_score           ; before missile_gone: its place
        ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        jr nz,.taken
        call boom_at_missile
        jr .gone
.taken: ld a,(msl_x)            ; where it was, as boom_at_missile
        ld l,a
        ld h,0
        ld de,(MISSILE_WIDTH - 16) / 2
        add hl,de
        ld a,(msl_y)
        add a,(MISSILE_HEIGHT - BOOM_ROWS) / 2
        call pop_here
.gone:  call missile_gone
.nomsl: ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        jr nz,.nuke
        xor a
        ld (wheel_hunting),a    ; thrown, it hunts no more
        ld a,CFG_SPECIAL_TIME
        ld (sp_left),a
        jp msl_calls_set
        ; The nuke: the bomb, then the divers, go up at once.
.nuke:  call sp_bomb_kill
        jp sp_divers

        HOT
; The shake is in the hot code: the cold block is full. It runs only
; when a bomb is set off.
;------------------------------------------------------------------------------
; sp_quake - the action stops for CFG_QUAKE_TIME 1/50 seconds. The whole
; picture jumps CFG_QUAKE_SHAKE pixel rows down and back, again and again,
; the border flashes the bomb's colour and black, and the beeper rumbles,
; fading out. Nothing else runs meanwhile, as in the knell. A shift down
; and then up puts every pixel row back but the bottom CFG_QUAKE_SHAKE,
; which are the ground's, and the next step's seabed copy rewrites those;
; the sprites' photographs stay true. The colours never move. Each shift
; takes two to three television frames, so the beam sees it tear a
; little: that is part of the shake. The banner's clock is pushed on by
; the time it took, as a death does.
; In: B = the border colour. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
sp_quake:
        ld a,b
        ld (qk_ink),a
        ld (qk_port),a
        out (ULA_PORT),a
        ld a,CFG_QUAKE_TIME
        ld (qk_loud),a
        ld hl,(frame_count)
        ld (qk_start),hl
.again: call qk_down
        call qk_hold
        call qk_up
        call qk_hold
        call qk_spent
        cp CFG_QUAKE_TIME
        jr c,.again
        ex de,hl                ; DE = television frames it took
        ld hl,(banner_until)
        add hl,de
        ld (banner_until),hl
        ld a,(qk_ink)
        out (ULA_PORT),a        ; speaker in
        ret

; Out: HL = television frames since the quake began, A = L (it is short).
qk_spent:
        ld hl,(frame_count)
        ld de,(qk_start)
        or a
        sbc hl,de
        ld a,l
        ret

; The picture down CFG_QUAKE_SHAKE rows, from the bottom up, and back up.
qk_down:
        ld hl,ROW_TABLE + 191 * 2
        ld de,ROW_TABLE + (191 - CFG_QUAKE_SHAKE) * 2
        ld bc,-2
        jr qk_move
qk_up:
        ld hl,ROW_TABLE
        ld de,ROW_TABLE + CFG_QUAKE_SHAKE * 2
        ld bc,2
; HL -> the first destination's entry in ROW_TABLE, DE -> its source's,
; BC = the step between entries. Corrupts: AF, BC, DE, HL
qk_move:
        ld (qk_step),bc
        ld b,192 - CFG_QUAKE_SHAKE
.row:   push bc
        push hl
        push de
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = the destination row
        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = the source row
        ld d,b
        ld e,c
        ld bc,32
        ldir
        call qk_click
        pop hl
        ld bc,(qk_step)
        add hl,bc
        ex de,hl                ; DE = the next source's entry
        pop hl
        add hl,bc               ; HL = the next destination's
        pop bc
        djnz .row
        ret

; Hold the picture for CFG_QUAKE_HOLD television frames, still rumbling,
; with the border the other way (the colour or black), and the rumble a
; little quieter as the time runs out. Corrupts: AF, BC, DE, HL
qk_hold:
        ld a,(qk_port)
        ld b,a
        and 7
        ld a,(qk_ink)
        jr z,.lit
        xor a                   ; BLACK
.lit:   ld c,a
        ld a,b
        and $F8
        or c
        ld (qk_port),a
        out (ULA_PORT),a
        call qk_spent
        ld b,a
        ld a,CFG_QUAKE_TIME
        sub b
        jr nc,.loud
        xor a
.loud:  ld (qk_loud),a
        ld b,CFG_QUAKE_HOLD
.frame: ld a,(frame_count)
        ld c,a
.wait:  call qk_click
        ld a,QK_ROW_WAIT
.idle:  dec a                   ; about as long as a row's copy
        jr nz,.idle
        ld a,(frame_count)
        cp c
        jr z,.wait
        djnz .frame
        ret
QK_ROW_WAIT     equ 50

; The rumble: every CFG_QUAKE_PITCH rows a random number decides whether
; the speaker moves, more often the louder it still is. Corrupts: AF, HL
qk_click:
        ld hl,qk_tick
        dec (hl)
        ret nz
        ld (hl),CFG_QUAKE_PITCH
        ld a,(qk_seed)
        add a,a
        jr nc,.same
        xor $1D                 ; a shift register: 255 values, never 0
.same:  ld (qk_seed),a
        and 63
        ld hl,qk_loud
        cp (hl)
        ret nc
        ld a,(qk_port)
        xor %00010000           ; the speaker
        ld (qk_port),a
        out (ULA_PORT),a
        ret

qk_ink:         db 0            ; the bomb's colour
qk_port:        db 0            ; what goes to the port: the border, the speaker
qk_loud:        db 0            ; out of 64: how often the speaker moves
qk_tick:        db 1            ; rows to the next noise value
qk_seed:        db $A5          ; never 0
qk_start:       dw 0            ; frame_count when it began
qk_step:        dw 0            ; qk_move's step between ROW_TABLE entries

        ASSERT CFG_QUAKE_SHAKE >= 1 && CFG_QUAKE_SHAKE <= GROUND_PX, "the rows a shake loses must be the ground's, which the seabed copy rewrites"
        ASSERT CFG_QUAKE_TIME >= 2 && CFG_QUAKE_TIME <= 200
        ASSERT CFG_QUAKE_HOLD >= 1 && CFG_QUAKE_HOLD <= 10
        ASSERT CFG_QUAKE_PITCH >= 1 && CFG_QUAKE_PITCH <= 255
        COLD

;------------------------------------------------------------------------------
; special_reset - nothing held, nothing thrown, the key unread, the calls
; back. torpedo_reset calls it. Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
special_reset:
        xor a
        ld (sp_held),a
        ld (sp_left),a
        call msl_calls_set
        ld hl,chords_poll
        jp sp_chords
        HOT

    ENDIF
