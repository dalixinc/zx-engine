;==============================================================================
; special.asm - the special bombs: suction, shove and the nuke
;
; Three rarer power-ups, in the missile's slot like the heart and the
; bubble (missile.asm), each with its own share of the roll and its own
; first level (config.asm). Touching one does not set it off: the diver
; carries it, one at a time, and a new one replaces the one he had. Its
; picture is on row 1, left of the bubble's cell. Symbol Shift + B sets
; it off.
;   suction  the bomb and the fish are pulled down towards the seabed,
;            CFG_SUCTION_SPEED pixels a 1/50 second for CFG_SPECIAL_TIME,
;            to the lowest middle their swing still fits above the weed
;   shove    they are thrown right, CFG_SHOVE_SPEED pixels a 1/50 second
;            for the same time, to the right edge at most
;   nuke     they go up as if shot (CFG_NUKE_LEVEL; 0 leaves it out)
; Each also takes away a silo's missile, armed or in flight. Nothing
; moved or cleared scores. A bomb that is pulled or thrown stops hunting.
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

; The two keys on port $7FFE: Symbol Shift (bit 1) and B (bit 4).
SP_KEYS         equ %00010010

; How low the pull takes them: the bomb's middle as low as the wave's
; lowest (it fits the drift's and the hunter's too), the fish's as low
; as its own wave still keeps it above the weed.
SUCK_BOMB_LOW   equ WAVE_LOW_BASE
SUCK_FISH_LOW   equ BACK_ROW * 8 - FISH_HEIGHT - CFG_FISH_WAVE_AMP
        ASSERT SUCK_BOMB_LOW <= WHEEL_LOW_BASE && SUCK_FISH_LOW >= FISH_SWIM_Y
        ASSERT SUCK_FISH_LOW + CFG_FISH_WAVE_AMP + FISH_HEIGHT <= BACK_ROW * 8, "a pulled fish would reach the seabed: it is drawn before the copy"
        ASSERT CFG_SPECIAL_TIME >= 1 && CFG_SPECIAL_TIME <= 255
        ASSERT CFG_SUCTION_SPEED >= 1 && CFG_SUCTION_SPEED <= 32 && CFG_SHOVE_SPEED >= 1 && CFG_SHOVE_SPEED <= 32
        ASSERT CFG_SUCTION_LEVEL >= 1 && CFG_SUCTION_LEVEL <= 99 && CFG_SHOVE_LEVEL >= 1 && CFG_SHOVE_LEVEL <= 99 && CFG_NUKE_LEVEL <= 99
        ASSERT LIVES_COL - 4 >= HUD_LEN, "the held bomb's cell would cover the score line"

;------------------------------------------------------------------------------
; sp_poll - in chords_poll's place while a bomb is held: the chords, then
; Symbol Shift + B, on the edge. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
sp_poll:
        call chords_poll        ; Symbol Shift + P does not come back
        ld bc,ROW_SPC_B * 256 + ULA_PORT
        in a,(c)
        and SP_KEYS             ; 0: both down
        sub 1
        sbc a,a                 ; $FF: both down, 0: not
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
        call z,msl_calls_set    ; the last one: the calls go back
        ld a,1
        ld (wheel_odd),a        ; more than a pixel: the whole bomb repainted
        ld a,(sp_kind)
        cp MSL_KIND_SHOVE
        jr z,.shove
        ; Suction: the bomb's middle, then the fish's, down, never up.
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
.shove: ld hl,(wheel_x)         ; 16 bits: off the left it is negative
        ld de,CFG_SHOVE_SPEED
        add hl,de
        ld a,h
        dec a
        jr nz,.bx               ; below 256
        ld hl,256               ; just off the right, as a new bomb starts
.bx:    ld (wheel_x),hl
        ld a,(fish_busy)
        or a
        jr nz,.on
        ld a,(fish_x)
        add a,CFG_SHOVE_SPEED
        jr c,.fmax
        cp FISH_MAX_X + 1
        jr c,.fx
.fmax:  ld a,FISH_MAX_X
.fx:    ld (fish_x),a
.on:    ld a,(double_on)
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
; special_fire - Symbol Shift + B with a bomb held. Not while he dies.
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
        ; A silo's missile, armed or flying, is taken away: no burst.
        ld a,(msl_phase)
        or a
        jr z,.nomsl
        ld a,(msl_kind)
        or a
        call z,missile_gone
.nomsl:
    IFNDEF NO_SOUND
        call snd_launch_start   ; the whoosh
    ENDIF
        ld a,CFG_CHORD_FLASH
        ld (chord_flash),a      ; the border flashes, as for a chord
    IF CFG_NUKE_LEVEL
        ld a,(sp_kind)
        cp MSL_KIND_NUKE
        jr z,special_nuke
    ENDIF
        xor a
        ld (wheel_hunting),a    ; pulled or thrown, it hunts no more
        ld a,CFG_SPECIAL_TIME
        ld (sp_left),a
        jp msl_calls_set

    IF CFG_NUKE_LEVEL
; The nuke: the bomb and the fish go up as a torpedo would take them,
; with no points. The bomb's burst first, then the fish's flash.
special_nuke:
        ld a,(wheel_phase)
        or a
        jr z,.fish
        call wheel_remove
        call boom_at_bomb
        ld a,(fish_busy)
        or a
        ret nz
        jp fish_flash_begin
.fish:  ld a,(fish_busy)
        or a
        ret nz
        jp boom_at_fish
    ENDIF

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

    ENDIF
