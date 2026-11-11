;==============================================================================
; special.asm - the special bombs: suction, shove and the nuke
;
; Three rarer power-ups, in the missile's slot like the heart and the
; bubble (missile.asm), each with its own share of the roll and its own
; first level (config.asm). Touching one does not set it off: the diver
; carries it, one at a time, and a new one replaces the one he had. Its
; picture is on row 1, left of the bubble's cell. B sets it off.
;   suction  the escape: the bomb and the fish are pulled down towards
;            the seabed, CFG_SUCTION_SPEED pixels a 1/50 second for
;            CFG_SPECIAL_TIME, to the lowest middle their swing still
;            fits above the weed, and left there alive
;   shove    they are thrown right, CFG_SHOVE_SPEED pixels a 1/50 second
;            for the same time, and blow up at the right edge, or where
;            they are when the time runs out
;   nuke     they go up as if shot, from CFG_NUKE_LEVEL (0 leaves it out)
; Shove blows up a silo's missile, armed or in flight, as B is pressed;
; suction and the nuke take it away, with no burst. Each thing a power
; clears scores its points (CFG_PTS_SUCTION, _SHOVE, _NUKE: sp_score),
; not the level's: suction's are for what it pulled out of the way and
; the missile it took, and the total shows where it was (pop_add,
; pop_here, boom.asm). A
; throw kills as a torpedo would, with one burst on the screen at a
; time (boom.asm): the bomb waits at the edge until a missile's burst
; is over, and the fish flashes while a burst is up or the bomb is
; still there. A bomb that is pulled or thrown stops hunting.
; No new bomb or fish can appear while a throw lasts: the bomb's pause
; (WHEEL_GAP) and a dead fish's flash and pause are longer.
;
; What it costs the frame:
;   - nothing held, nothing moving: nothing. The key is read only while
;     one is held: main_loop's call to chords_poll (.chord_call) goes
;     through sp_poll then, about 60 T-states a step.
;   - while a bomb moves things: main_loop's two calls to missile_update
;     go through sp_tick, as they go through double_tick for the double
;     shot. msl_calls_set is the one place those calls are set, for
;     both. The bomb is repainted whole each 1/50 second while it is
;     thrown (wheel_odd), as a wave's jump is.
;==============================================================================

    IFDEF POWERUPS

sp_held:        db 0            ; the kind he carries (MSL_KIND_SUCTION...), 0 = none
sp_kind:        db 0            ; the kind moving things now
sp_left:        db 0            ; 1/50 seconds of it still to go, 0 = none
sp_prev:        db 0            ; the key last step (rising_edge)

; The key: B, on port $7FFE (bit 4). Nothing else in play uses it.
SP_KEYS         equ %00010000

; How low the pull takes them: the bomb's middle as low as the wave's
; lowest (it fits the drift's and the hunter's too), the fish's as low
; as its own wave still keeps it above the weed.
SUCK_BOMB_LOW   equ WAVE_LOW_BASE
SUCK_FISH_LOW   equ BACK_ROW * 8 - FISH_HEIGHT - CFG_FISH_WAVE_AMP
; How far right the throw takes the bomb: its right edge on the screen's.
SHOVE_BOMB_MAX  equ 256 - WHEEL_WIDTH
        ASSERT WHEEL_GAP > CFG_SPECIAL_TIME, "a new bomb could come and be blown up by the same special bomb"
        ASSERT SUCK_BOMB_LOW <= WHEEL_LOW_BASE && SUCK_FISH_LOW >= FISH_SWIM_Y
        ASSERT SUCK_FISH_LOW + CFG_FISH_WAVE_AMP + FISH_HEIGHT <= BACK_ROW * 8, "a pulled fish would reach the seabed: it is drawn before the copy"
        ASSERT CFG_SPECIAL_TIME >= 1 && CFG_SPECIAL_TIME <= 255
        ASSERT CFG_SPECIAL_FLASH >= 1 && CFG_SPECIAL_FLASH <= 255 && CFG_SUCTION_INK <= 7 && CFG_SHOVE_INK <= 7
        ASSERT CFG_SUCTION_SPEED >= 1 && CFG_SUCTION_SPEED <= 32 && CFG_SHOVE_SPEED >= 1 && CFG_SHOVE_SPEED <= 32
        ASSERT CFG_SUCTION_LEVEL >= 1 && CFG_SUCTION_LEVEL <= 99 && CFG_SHOVE_LEVEL >= 1 && CFG_SHOVE_LEVEL <= 99 && CFG_NUKE_LEVEL <= 99
        ASSERT LIVES_COL - 4 >= HUD_LEN, "the held bomb's cell would cover the score line"

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
; sp_tick - in missile_update's place while a bomb moves things: one 1/50
; second of the pull or the throw, then on to the double shot's clock or
; missile_update. Corrupts: AF, BC, DE, HL (as missile_update)
;------------------------------------------------------------------------------
sp_tick:
        ld hl,sp_left
        dec (hl)
        call z,sp_end           ; the last one: a throw's leftovers blow up
        ld a,1
        ld (wheel_odd),a        ; more than a pixel: the whole bomb repainted
        ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        jr z,.shove
        ; Suction: the bomb's middle, then the fish's, down, never up.
        ; Nothing dies: they stay down there, alive.
        ld a,(wheel_base)
        cp SUCK_BOMB_LOW
        jr nc,.fish
        add a,CFG_SUCTION_SPEED
        cp SUCK_BOMB_LOW + 1
        jr c,.base
        ld a,SUCK_BOMB_LOW
.base:  ld (wheel_base),a
.fish:  ld a,(fish_busy)
        or a
        jr nz,.on               ; flashing or away: left alone
        ld a,(fish_wave.in + 1) ; the fish's middle (fish_wave's operand)
        cp SUCK_FISH_LOW
        jr nc,.on
        add a,CFG_SUCTION_SPEED
        cp SUCK_FISH_LOW + 1
        jr c,.mid
        ld a,SUCK_FISH_LOW
.mid:   ld (fish_wave.in + 1),a
        ld b,a
        ld a,(level_fmove)
        or a                    ; MOVE_STRAIGHT: its height is its middle
        ld a,b
        call z,fish_set_y
        jr .on
.shove: ld a,(wheel_phase)
        or a
        jr z,.sfish
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
        call sp_bomb_down
        jr .sfish
.bx:    ld (wheel_x),hl
.sfish: ld a,(fish_busy)
        or a
        jr nz,.on
        ld a,(fish_x)
        add a,CFG_SHOVE_SPEED
        jr c,.fmax
        cp FISH_MAX_X
        jr c,.fx
.fmax:  ld a,FISH_MAX_X
        ld (fish_x),a
        jp sp_fish_kill_on
.fx:    ld (fish_x),a
.on:
    IFDEF TWO_BOMBS
        call tb_sp_tick         ; the second bomb pulled or thrown too
    ENDIF
        ld a,(double_on)
        or a
        jp nz,double_tick
        jp missile_update

        COLD
;------------------------------------------------------------------------------
; msl_calls_set - main_loop's two missile_update calls (.msl_uc1, .msl_uc2)
; to sp_tick while a bomb moves things, else to double_tick while the
; double shot lasts, else to missile_update itself. Corrupts: AF, HL
;------------------------------------------------------------------------------
msl_calls_set:
        ld hl,sp_tick
        ld a,(sp_left)
        or a
        jr nz,.set
        ld hl,double_tick
        ld a,(double_on)
        or a
        jr nz,.set
        ld hl,missile_update
.set:   ld (fish_mv.msl_uc1 + 1),hl
        ld (fish_mv2.msl_uc2 + 1),hl
        ret
        ASSERT ({fish_mv.msl_uc1} & $FF) == $CD && {fish_mv.msl_uc1 + 1} == missile_update, ".msl_uc1 is not CALL missile_update"
        ASSERT ({fish_mv2.msl_uc2} & $FF) == $CD && {fish_mv2.msl_uc2 + 1} == missile_update, ".msl_uc2 is not CALL missile_update"
        ASSERT ({main_loop.chord_call} & $FF) == $CD && {main_loop.chord_call + 1} == chords_poll, ".chord_call is not CALL chords_poll"

; sp_end - the last 1/50 second of the pull or the throw: the calls go
; back, and after a throw the bomb and the fish blow up where they are.
; sp_bomb_down - the bomb is at the right edge: it blows up,
; unless a burst is still up (a missile's). sp_tick asks again next time.
; sp_fish_kill_on - the fish is there: it dies, then on to the clock.
; Corrupts: AF, BC, DE, HL
sp_end:
        call msl_calls_set
        ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        jp nz,sp_sucked         ; suction: nothing dies
        call sp_bomb_kill
    IFDEF TWO_BOMBS
        call tb_kill            ; and the second bomb
    ENDIF
        jr sp_fish_kill

sp_bomb_down:
        ld a,(boom_t)
        or a
        ret nz
sp_bomb_kill:
        ld a,(wheel_phase)
        or a
        ret z
        call wheel_remove
        call boom_at_bomb
        jp sp_score

sp_fish_kill_on:
        call sp_fish_kill
        jp sp_tick.on

; The fish as a torpedo kills it (torpedo_fish), for shove's points.
; It flashes while the bomb is there or a burst is up.
sp_fish_kill:
        ld a,(fish_busy)
        or a
        ret nz
        ld a,(boom_t)
        ld hl,wheel_phase
        or (hl)
        jr nz,.flash
        call sp_score
        jp boom_at_fish
.flash: call sp_fish_pts
        jp fish_flash_begin

; HL = chords_poll or sp_poll: main_loop's call. Corrupts: nothing else
sp_chords:
        ld (main_loop.chord_call + 1),hl
        ret

;------------------------------------------------------------------------------
; special_take - he touched a special bomb: he carries it
; power_take jumps here with A = its kind - 2. Corrupts: AF, HL
;------------------------------------------------------------------------------
special_take:
        add a,MSL_KIND_DOUBLE
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
; Corrupts: AF, BC, DE, HL
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
        ; Its own sound and border colour: suction a falling slide and
        ; cyan, shove a rising one and yellow, the nuke the whoosh and
        ; white. A thrown missile's bang, below, cuts the slide short.
        ld a,(sp_kind)
        ld hl,snd_tune_suction
        ld b,CFG_SUCTION_INK
        cp MSL_KIND_SUCTION
        jr z,.look
        ld hl,snd_tune_shove
        ld b,CFG_SHOVE_INK
        cp MSL_KIND_SHOVE
        jr z,.look
        ld hl,0                 ; the nuke
        ld b,WHITE
.look:  ld a,b
        ld (step_skip.flash_ink + 1),a ; the rest of the flash's colour
        ld a,CFG_SPECIAL_FLASH
        ld (chord_flash),a      ; the border flashes, as for a chord
    IFNDEF TRIGON
    IF CFG_NUKE_LEVEL
        call nuke_word          ; the nuke: its word, before the quake
    ENDIF
    ENDIF
        ; Shove and the nuke stop the action for a moment and shake the
        ; screen first; suction, the escape, stays quiet.
        ld a,(sp_kind)
        cp MSL_KIND_SUCTION
        jr z,.calm
        push hl
        call sp_quake           ; B is still the colour
        pop hl
.calm:
    IFNDEF NO_SOUND
        ld a,h
        or l
        jr z,.whoosh
        call snd_tune_start
        jr .sounded
.whoosh:
        call snd_launch_start
.sounded:
    ENDIF
        ; A silo's missile, armed or flying: a throw blows it up and it
        ; scores, as if shot; suction (the escape) and the nuke only take
        ; it away. A power-up is left alone.
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
.nomsl:
    IF CFG_NUKE_LEVEL
        ld a,(sp_kind)
        cp MSL_KIND_NUKE
        jr z,special_nuke
    ENDIF
        xor a
        ld (wheel_hunting),a    ; pulled or thrown, it hunts no more
    IFDEF TWO_BOMBS
        ld (b2.wheel_hunting),a
    ENDIF
        ld a,CFG_SPECIAL_TIME
        ld (sp_left),a
        jp msl_calls_set

    IF CFG_NUKE_LEVEL
; The nuke: the bomb and the fish go up as a torpedo would take them,
; for the nuke's points each. The bomb's burst first, then the fish's
; flash.
special_nuke:
    IFDEF TWO_BOMBS
        call tb_nuke            ; the second bomb goes too
    ENDIF
        ld a,(wheel_phase)
        or a
        jr z,.fish
        call wheel_remove
        call boom_at_bomb
        call sp_score
        ld a,(fish_busy)
        or a
        ret nz
        call sp_score
        jp fish_flash_begin
.fish:  ld a,(fish_busy)
        or a
        ret nz
        call sp_score
        jp boom_at_fish
    ENDIF

;------------------------------------------------------------------------------
; sp_quake - shove or the nuke: the action stops for CFG_QUAKE_TIME 1/50
; seconds. The whole picture jumps CFG_QUAKE_SHAKE pixel rows down and
; back, again and again, the border flashes the bomb's colour and black,
; and the beeper rumbles, fading out. Nothing else runs meanwhile, as in
; the knell. A shift down and then up puts every pixel row back but the
; bottom CFG_QUAKE_SHAKE, which are the ground's, and the next step's
; seabed copy rewrites those; the sprites' photographs stay true. The
; colours never move. Each shift takes two to three television frames,
; so the beam sees it tear a little: that is part of the shake. The
; clocks that count television frames (the banner's, the double shot's)
; are pushed on by the time it took, as a death does.
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
    IFDEF DOUBLE_SHOT
        ld hl,(double_until)
        add hl,de
        ld (double_until),hl
    ENDIF
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
        ld b,192 - CFG_QUAKE_SHAKE
.row:   push bc
        call qk_row
        dec hl
        dec hl
        dec de
        dec de
        pop bc
        djnz .row
        ret

qk_up:
        ld hl,ROW_TABLE
        ld de,ROW_TABLE + CFG_QUAKE_SHAKE * 2
        ld b,192 - CFG_QUAKE_SHAKE
.row:   push bc
        call qk_row
        inc hl
        inc hl
        inc de
        inc de
        pop bc
        djnz .row
        ret

; One pixel row: HL -> the destination's entry in ROW_TABLE, DE -> the
; source's. Keeps HL and DE. Corrupts: AF, BC
qk_row:
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
        pop de
        pop hl
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

        ASSERT CFG_QUAKE_SHAKE >= 1 && CFG_QUAKE_SHAKE <= GROUND_PX, "the rows a shake loses must be the ground's, which the seabed copy rewrites"
        ASSERT CFG_QUAKE_TIME >= 2 && CFG_QUAKE_TIME <= 200
        ASSERT CFG_QUAKE_HOLD >= 1 && CFG_QUAKE_HOLD <= 10
        ASSERT CFG_QUAKE_PITCH >= 1 && CFG_QUAKE_PITCH <= 255

;------------------------------------------------------------------------------
; special_reset - nothing held, nothing moving, the key unread
; torpedo_reset calls it, before it sets the missile calls.
; Corrupts: AF, HL
;------------------------------------------------------------------------------
special_reset:
        xor a
        ld (sp_held),a
        ld (sp_left),a
        ld hl,chords_poll
        jp sp_chords

;------------------------------------------------------------------------------
; power_build - the sinking power-ups' masked pictures (POWER_PICS), from
; row 1's cells, at start-up: mask then ink a row, the mask the ink's
; complement, as missile_draw reads them. Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
power_build:
        ld hl,lives_heart
        ld de,POWER_PICS
        ld b,POWER_KINDS * 8
.row:   ld a,(hl)
        inc hl
        cpl
        ld (de),a
        inc de
        cpl
        ld (de),a
        inc de
        djnz .row
        ret
        HOT

; Suction's end: what it pulled out of the way scores, and the points
; show where the bomb is (or the fish, with no bomb). Both stay, alive.
sp_sucked:
    IFDEF TWO_BOMBS
        call tb_sucked
    ENDIF
        ld a,(fish_busy)
        or a
        call z,sp_fish_pts
        ld a,(wheel_phase)
        or a
        ret z
        call sp_score
        ld hl,(wheel_x)
        ld a,(wheel_y)
        jp pop_here

; The fish's points, shown where it is unless a burst shows them.
; Corrupts: AF, BC, DE, HL
sp_fish_pts:
        call sp_score
        ld a,(fish_x)
        ld l,a
        ld h,0
        ld a,(fish_y)
        jp pop_here

; sp_score - this power's points (sp_kind) for one thing it cleared,
; onto the score and the pop-up. Corrupts: AF, BC, DE, HL
sp_score:
        ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        ld a,CFG_PTS_SHOVE
        jr z,.add
        ld a,CFG_PTS_SUCTION
        jr c,.add               ; MSL_KIND_SUCTION is below shove
        ld a,CFG_PTS_NUKE
.add:   jp pop_add
        ASSERT MSL_KIND_SUCTION < MSL_KIND_SHOVE && MSL_KIND_SHOVE < MSL_KIND_NUKE, "sp_score tells the kinds apart by order"
        ASSERT CFG_PTS_SUCTION <= 99 && CFG_PTS_SHOVE <= 99 && CFG_PTS_NUKE <= 99, "a power's points are 0 to 99"


    ENDIF

;------------------------------------------------------------------------------
; nuke_word - the nuke's word across the middle, Atlantis only: the
; banner's block letters (score.asm) in CFG_NUKE_WORD_PAPER, for
; CFG_NUKE_WORD_TIME. special_fire calls it before the quake, which
; pushes the banner's clock on by its own time, so the word outlasts the
; shake (the shake moves only the pixels; the word stays still). A
; banner already up (a level's, and its code) comes down first. Once
; per nuke, so in the data block; nuke_heal, below, fills its holes.
; Out: HL and B kept (special_fire's sound and colour). Corrupts: AF, C, DE
;------------------------------------------------------------------------------
        MACRO NUKE_WORD
nuke_word:
        ld a,(sp_kind)
        cp MSL_KIND_NUKE
        ret nz
        push bc
        push hl
        ld a,(hud_dirty)
        bit HUD_BANNER,a
        call nz,banner_erase    ; a level's banner comes down first
        ld hl,nuke_letters
        ld de,banner_chars
        ld bc,NUKE_LEN
        ldir
        ld a,NUKE_LEN
        ld (banner_len),a
        ld a,(32 - (NUKE_LEN * 4 - 1)) / 2
        ld (banner_col),a       ; centred, as banner_show does
        xor a
        ld (banner_code),a      ; no code under it
        ld a,BRIGHT | BLUE | (CFG_NUKE_WORD_PAPER << 3)
        call banner_paint
        ld hl,(frame_count)
        ld de,CFG_NUKE_WORD_TIME
        add hl,de
        ld (banner_until),hl
        ld hl,hud_dirty
        set HUD_BANNER,(hl)     ; banner_tick takes it down
        pop hl
        pop bc
        ret
nuke_letters:   db "NUKE"
NUKE_LEN        equ $ - nuke_letters
; nuke_heal - banner_tick, each step a banner is up: if it is the
; nuke's word (four letters; "LEVEL n" has seven or eight), every 16
; television frames (as Trigon's tp_banner_heal) its blocks are painted
; again, about 14 scanlines. The things the nuke
; blows up, and the next bomb and fish, give their colour cells back to
; water as they go and leave holes in it. The screen has just been
; cleared, so these steps are light: measured, no frame lost, a few
; more late steps that catch up. Corrupts: AF, BC, DE, HL
nuke_heal:
        ld a,(banner_len)
        cp NUKE_LEN
        ret nz
        ld a,(frame_count)
        and 15
        ret nz
        ld a,(banner_ink)
        jp banner_paint
        ENDM
    IFNDEF TRIGON
        ASSERT CFG_NUKE_WORD_PAPER >= 0 && CFG_NUKE_WORD_PAPER <= 7 && CFG_NUKE_WORD_PAPER != BLUE, "CFG_NUKE_WORD_PAPER: a colour 0-7, not the sea's blue"
        ASSERT CFG_NUKE_WORD_TIME >= 1 && CFG_NUKE_WORD_TIME <= 1000
    ENDIF
