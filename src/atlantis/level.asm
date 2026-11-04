;==============================================================================
; level.asm - how each level looks: the bomb's colour and movement, the
;             fish's movement and speed, the border
;
; The five numbers are columns of CFG_LEVELS (config.asm), and the
; three after them are what a shot scores on this level.
; level_enter (score.asm) hands them to level_style when a level
; starts, by score or by code. Level 1 has the old values, so level 1
; plays exactly as it did: the old bomb, update_fish, the heartbeat.
;
; Level 2 brings two movers, both a sine (MOVE_WAVE):
;   - wheel_wave, the bomb: the same picture and the same crossing as
;     the drift, but its height follows a wave, not the small bob.
;   - fish_wave, the fish: up and down about its usual depth, and a
;     little faster across (the level's fspeed).
; Both run every step, so they are here in the hot code. level_style
; runs once a level and is in the cold block.
;
; A wave is a table of 128 heights (data.asm, made from CFG_*_WAVE_AMP
; when the game is assembled) and a phase byte, which goes up by
; CFG_*_WAVE_SPEED each 1/50 second; its top 7 bits pick the height.
;==============================================================================

; How this level looks and what it scores, in CFG_LEVELS' order.
; level_style fills it. The points are BCD, for score_add.
level_look:
level_ink:      db CFG_WHEEL_INK ; the bomb's cell colour (wheel_type)
level_bmove:    db MOVE_BOB     ; the bomb's movement (wheel_kind)
level_fmove:    db MOVE_STRAIGHT ; the fish's movement
level_fhaste:   db 0            ; the fish's haste (fish_wave only)
level_border:   db BORDER_BEAT
level_pts_fish: db $01          ; a shot fish (torpedo_fish)
level_pts_bomb: db $02          ; a shot bomb (torpedo_hit)
level_pts_msl:  db $10          ; a shot missile (missile_shot)
LEVEL_LOOK      equ $ - level_look

fish_mover:     dw update_fish  ; what fish_unhold puts back in the moves
fish_wave_p:    db 0            ; the fish's place on its wave
fish_frac:      db 0            ; its haste's fraction of a pixel
wheel_wave_p:   db 0            ; the bomb's place on its wave

; The bomb's middle stays this far from the score row and the seaweed,
; so the whole wave is in open water.
WAVE_TOP_BASE   equ WHEEL_TOP_Y + CFG_BOMB_WAVE_AMP
WAVE_LOW_BASE   equ BACK_ROW * 8 - WHEEL_HEIGHT - CFG_BOMB_WAVE_AMP

        ASSERT CFG_BOMB_WAVE_AMP >= 1 && WAVE_LOW_BASE >= WAVE_TOP_BASE, "the bomb's wave does not fit in the water"
        ASSERT CFG_BOMB_WAVE_SPEED >= 1 && CFG_BOMB_WAVE_SPEED <= 255
        ; The steepest step of the table is 6/127 of AMP, taken SPEED/2
        ; times a 1/50 second: 40 keeps it under a pixel, so the colour's
        ; one-pixel path holds. More would repaint the whole rectangle.
        ASSERT CFG_BOMB_WAVE_AMP * CFG_BOMB_WAVE_SPEED <= 40, "the bomb's wave is too steep: keep AMP * SPEED at 40 or less"
        ASSERT LEVEL_LOOK == LEVEL_ROW_BYTES - 6, "level_look is not the tail of a CFG_LEVELS row"
        ASSERT CFG_FISH_WAVE_SPEED >= 1 && CFG_FISH_WAVE_SPEED <= 255
        ASSERT FISH_SWIM_Y - CFG_FISH_WAVE_AMP >= 16, "the fish's wave reaches the hearts' row"
        ASSERT FISH_SWIM_Y + CFG_FISH_WAVE_AMP + FISH_HEIGHT <= BACK_ROW * 8, "the fish's wave reaches the seabed; it is drawn before the blit"
        ASSERT FISH_MIN_X == 0, "fish_wave turns at 0"
        ASSERT FISH_HEIGHT <= 9, "fish_paint colours two rows of cells"

;------------------------------------------------------------------------------
; wheel_wave - update_wheel's kind 1: the drift, on a wave
; Waiting is the drift's own. Flying: the phase goes on step_ticks times,
; the height is the middle plus the wave's, then the drift spins and
; moves it (wheel_drift.spin1 at 50, .spin2 at 25). A height more than a
; pixel from the last asks wheel_colours to paint the whole rectangle,
; as a wobble does: its one-pixel path cannot follow a bigger jump.
; Cost at 50: about 150 T-states before the drift's own, a little less
; than the bob's path. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_wave:
        ld a,(wheel_phase)
        or a
        jp z,wheel_drift.waiting
        ld a,(wheel_x + 1)
        dec a                   ; x is 256 only on a new bomb's first step
        call z,wheel_wave_new
        ld a,(step_ticks)
        ld b,a
        ld a,(wheel_wave_p)
.adv:   add a,CFG_BOMB_WAVE_SPEED
        djnz .adv
        ld (wheel_wave_p),a
        srl a                   ; 0..127
        ld hl,bomb_wave_tab
        add a,l
        ld l,a
        jr nc,.in
        inc h
.in:    ld a,(wheel_base)
        add a,(hl)
        ld b,a                  ; the new height
        ld a,(wheel_y)
        sub b
        inc a
        cp 3                    ; within a pixel of the last?
        jr c,.near
        ld a,1
        ld (wheel_odd),a
.near:  ld a,b
        ld (wheel_y),a
        ld a,(step_ticks)
        dec a
        jp z,wheel_drift.spin1
        jp wheel_drift.spin2

; A new bomb: the start of the wave, and a middle the wave fits round.
; The bomb is still off the right edge, so a middle that moves here was
; never seen. Corrupts: AF
wheel_wave_new:
        xor a
        ld (wheel_wave_p),a
        ld a,(wheel_base)
        cp WAVE_TOP_BASE
        jr nc,.top
        ld a,WAVE_TOP_BASE
.top:   cp WAVE_LOW_BASE + 1
        jr c,.low
        ld a,WAVE_LOW_BASE
.low:   ld (wheel_base),a
        ret

;------------------------------------------------------------------------------
; fish_wave - one 1/50 second of the level 2 fish, in update_fish's place
; Across: a pixel, and one more each time the level's haste carries out
; of the fraction; it turns at the edges as update_fish does. Up and
; down: the wave about FISH_SWIM_Y. The new height also goes into the
; three hit tests that would otherwise use FISH_SWIM_Y (boom.asm).
; Cost: about 250 T-states, against update_fish's 50: about one scanline
; more, on level 2 only.
; Corrupts: AF, B, HL
;------------------------------------------------------------------------------
fish_wave:
        ld a,(level_fhaste)
        ld b,a
        ld a,(fish_frac)
        add a,b
        ld (fish_frac),a
        ld b,1
        jr nc,.step
        inc b                   ; the haste carried: a pixel more
.step:  ld a,(fish_facing)
        cp FACE_LEFT
        ld a,(fish_x)
        jr z,.left
        add a,b
        cp FISH_MAX_X + 1
        jr c,.x
        ld a,FACE_LEFT          ; the right edge: turn
        ld (fish_facing),a
        ld a,FISH_MAX_X
        jr .x
.left:  sub b
        jr nc,.x
        ld a,FACE_RIGHT         ; the left edge: turn
        ld (fish_facing),a
        xor a
.x:     ld (fish_x),a

        ld a,(fish_wave_p)
        add a,CFG_FISH_WAVE_SPEED
        ld (fish_wave_p),a
        srl a                   ; 0..127
        ld hl,fish_wave_tab
        add a,l
        ld l,a
        jr nc,.in
        inc h
.in:    ld a,FISH_SWIM_Y
        add a,(hl)
        ld (fish_y),a
        ld (fish_touch_y + 1),a
        ld (torpedo_fish_y + 1),a
        add a,FISH_HEIGHT
        ld (fish_aside_y + 1),a
        ret

        COLD
;------------------------------------------------------------------------------
; level_style - HL = the look and points bytes of a CFG_LEVELS row
; Called by level_enter, at a new game and at each new level. The bomb
; on the screen keeps its colour and movement: wheel_type gives the next
; one the level's. The fish changes at once, and so does the border.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
level_style:
        ld de,level_look
        ld bc,LEVEL_LOOK
        ldir
        xor a
        ld (fish_wave_p),a
        ld hl,fish_wave
        ld a,(level_fmove)
        or a
        jr nz,.mover
        ; Straight across at its own depth, with the hit tests there.
        ld a,FISH_SWIM_Y
        ld (fish_y),a
        ld (fish_touch_y + 1),a
        ld (torpedo_fish_y + 1),a
        ld a,FISH_SWIM_Y + FISH_HEIGHT
        ld (fish_aside_y + 1),a
        ld hl,update_fish
.mover: ld (fish_mover),hl
        ld a,(fish_busy)
        or a
        call z,fish_unhold      ; a fish held for a burst gets it when let go

        ; The border. The heartbeat's first four bytes are either its own
        ; or "LD A,colour : JR to the border". These builds have their own
        ; border and no heartbeat.
    IFNDEF TIMING_BARS
    IFNDEF SOAK
        ld a,(level_border)
        ld hl,beat_own
        cp BORDER_BEAT
        jr z,.beat
        ld (beat_fixed + 1),a
        ld hl,beat_fixed
.beat:  ld de,step_skip.beat
        ld bc,4
        ldir
    ENDIF
    ENDIF
        ret

    IFNDEF TIMING_BARS
    IFNDEF SOAK
; The heartbeat's first four bytes, as main_loop has them, and what a
; fixed border puts there. Not run here: level_style copies them.
beat_own:
        ld hl,(frame_count)
        ld a,l
beat_fixed:
        ld a,0                  ; the colour
        jr $ + 5                ; at step_skip.beat + 2: to .border
        ASSERT beat_fixed - beat_own == 4 && $ - beat_fixed == 4
        ASSERT step_skip.border - step_skip.beat == 7, "the heartbeat is not LD HL,(nn) : LD A,L : RRCA x3"
    ENDIF
    ENDIF
        HOT
