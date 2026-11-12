;==============================================================================
; wheel.asm - the first Trigon enemy, the wheel bomb
;
; One at a time. It slides in from the right edge, a pixel a frame, bobs
; up and down, and leaves through the left edge. After a short pause
; another one appears at a different height.
;
; The legs spin. The T does not: that mark is on every Trigon enemy,
; and it stays upright. The art is gfx/wheel.txt, 12 by 12, four frames,
; the wide leg stepping a quarter turn counter-clockwise (the way a
; wheel rolls when it travels left). There is a one-pixel gap of water
; between the T and the rim. The picture is a placeholder.
;
; It is drawn by the walker in fastsprite.asm, not by the shared sprite
; loop. A 16 by 16 wheel on that loop cost about 60 scanlines, and the
; frame only had 7 to spare, so the picture missed the interrupt and
; flickered. Twelve pixels is the size asked for. Shifted by 0 to 4 it
; is two bytes wide; shifted by 5 to 7 it is three. The walker writes
; the row in a straight line, and the fish and the diver on this build
; use the same walker, which is where the spare scanlines come from.
;
; Each bomb has its own ink colour, copied from the enemy settings in
; config.asm when it appears. The test colour is black ink on the blue
; of the water. White is the diver, the fish and the water ink, so a
; white bomb would not read, and that is why black was picked.
;
; Colour clash: an 8 by 8 cell has one ink and one paper. Any cell the
; bomb covers is drawn in the bomb's colour until the bomb moves on.
; On open water that is black on blue. A sand cell is yellow on blue,
; so while the bomb covers it the yellow becomes black and the blue
; stays. A weed cell is green on blue and turns black on blue the same
; way. A ground cell is black on yellow, so it also loses the yellow
; paper and becomes blue. The cell is put back when the bomb leaves.
; The ordinary bob stays above the weed. Wobble, or a taller bob in
; config.asm, can carry one down onto those rows.
;
; Movement is a kind byte, from the level: the drift here, the wave and
; the hunter (wheel_wave, wheel_home) in level.asm.
;
; The top of a swing is never above pixel row 16 (WHEEL_TOP_Y), so the
; bomb never covers the score line on row 1. With wobble left at 0 the
; bottom of the lowest swing is the last pixel of row 20, one above the
; seaweed.
;==============================================================================

; Kind values. wheel_kind picks a row of wheel_kind_tab. The level
; (CFG_LEVELS, bmove) sets it for each new bomb.
WHEEL_KIND_DRIFT equ 0          ; straight left, with the small bob
WHEEL_KIND_WAVE  equ 1          ; straight left, on a wave (level.asm)
WHEEL_KIND_HOME  equ 2          ; the drift, hunting the diver's depth (level.asm)
        ASSERT WHEEL_KIND_DRIFT == MOVE_BOB && WHEEL_KIND_WAVE == MOVE_WAVE
        ASSERT WHEEL_KIND_HOME == MOVE_HOME
    IFDEF TRIGON
        ASSERT MOVE_ZIG == 3 && MOVE_STOP == 4 && MOVE_ZING == 5, "update_wheel's kinds 3 to 5"
    ENDIF

; --- Tuning. Names are the knobs. -------------------------------------------
; One pixel a frame, the same speed as the diver, so this first bomb is
; something he can swim away from and something the eye can follow while
; it clips at the edge. 50 pixels a second.
WHEEL_SPEED     equ 1

; The sine table in data.asm is drawn for a swing of 6 pixels. A bomb
; whose setting is 6 uses the table as it stands. Any other height
; multiplies those numbers. 6 is not the setting: the setting is
; CFG_WHEEL_BOB, and each bomb keeps its own copy, because wobble can
; change one bomb without changing the next.
WHEEL_BOB       equ 6

; How many 1/50 seconds each picture of the pulsar is held. Level 1's
; bomb, so it stays 8.
WHEEL_SPIN      equ 8

; The spinning wheel rolls: its 4 pictures are one turn in quarter
; turns, counter-clockwise, the way a wheel turns going left. The rim is
; 5 to 6 pixels from the middle, so a turn rolls about 34 pixels, about
; 8.6 a picture. At 1 + haste/256 pixels a 1/50 second that is 8.6 /
; speed 1/50 seconds a picture: 7.2 at level 3's haste (48), 4.9 at
; level 9's (192). A hold of 7 below SPIN_MID_HASTE, 6 below
; SPIN_FAST_HASTE and 5 from it keeps every level within about a tenth
; of a true roll. wheel_type picks it when a bomb appears.
SPIN_HOLD_SLOW  equ 7
SPIN_HOLD_MID   equ 6
SPIN_HOLD_FAST  equ 5
SPIN_MID_HASTE  equ 96
SPIN_FAST_HASTE equ 144

; Frames to wait after one bomb has gone, before the next appears.
; 48 frames is just under a second.
WHEEL_GAP       equ 48

; Legal middles, for the height in config.asm. The bob is added to the
; middle, so the middle itself stays this far from the score row and
; from the seaweed:
;   top:    middle - height >= WHEEL_TOP_Y
;   bottom: middle + height + the picture <= row 21
; Wobble is allowed to drift past the weed after the spawn. These two
; are only the table entries, so a fresh bomb still starts in the water.
; The highest the top of the bomb goes: the first pixel row below the
; score line. The soak keeps the old 0: its script parks the surface bomb
; on row 0 to test it against the stat digits, and its frame numbers
; expect that bomb where it always was.
    IFDEF SOAK
WHEEL_TOP_Y     equ 0
    ELSE
WHEEL_TOP_Y     equ 16
    ENDIF
WHEEL_TOP_BASE  equ WHEEL_TOP_Y + CFG_WHEEL_BOB
WHEEL_LOW_BASE  equ BACK_ROW * 8 - WHEEL_HEIGHT - CFG_WHEEL_BOB

; Phase of the one bomb. Not the same thing as the kind: drifting covers
; both the flight and the pause between flights.
WHEEL_FLY       equ 1
WHEEL_WAIT      equ 0

;------------------------------------------------------------------------------
; update_wheel - one step of movement, via the kind table
; A step is one television frame at 50, or two at 25. The distances
; below are all per 1/50 second, and this routine applies them
; step_ticks times so both speeds cover the same water.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
update_wheel:
        ld a,(wheel_kind)
        or a
        jp z,wheel_drift        ; level 1's bomb: the test costs it nothing more
        dec a
        jp z,wheel_wave
        dec a
        jp z,wheel_home
    IFDEF TRIGON
      IFNDEF B2_PASS            ; the first bomb's only (src/trigon/moves.asm)
        dec a
        jp z,wheel_zig          ; level.asm
        dec a
        jp z,wheel_ss
        dec a
        jp z,wheel_zing
      ENDIF
    ENDIF
        ; No other kind: LEVEL_ROW asserts the column, so this is never
        ; reached, and a stray value cannot land in other code.
        ret

;------------------------------------------------------------------------------
; wheel_drift - the straight-left bomb
; Flying: bob, spin, move left, and when it has gone past the left edge,
; start the pause. Waiting: count down, then spawn the next one.
;------------------------------------------------------------------------------
wheel_drift:
        ld a,(wheel_phase)
        or a
        jp z,.waiting

        ; The usual bomb: one pixel a frame, the sine table as it stands,
        ; no wobble. This is the path the frame has time for. The scaled
        ; path below handles a taller swing, a wobble, or two pixels in
        ; one step, and that arithmetic does not fit on the heavy frame.
        ld a,(step_ticks)
        cp 1
        jr nz,.scaled
        ld a,(wheel_wobble)
        or a
        jr nz,.scaled
        ld a,(wheel_swing)
        cp WHEEL_BOB
        jr nz,.scaled

        ld a,(wheel_bob_i)
        inc a
        and 31
        ld (wheel_bob_i),a
        ld hl,wheel_bob
        ld e,a
        ld d,0
        add hl,de
        ld a,(wheel_base)
        add a,(hl)
        ld (wheel_y),a

.spin1: ld hl,wheel_spin_n      ; the wave joins here at 50 (level.asm)
        inc (hl)
        ld a,(hl)
.hold1: cp WHEEL_SPIN           ; patched: the bomb's hold (wheel_type)
        jr c,.moved
        ld (hl),0
        call wheel_next_frame
.moved: ; One pixel, and one more each time the level's haste carries
        ; out of the fraction (score.asm). Haste 0 never carries.
        ld a,(wheel_haste)
        ld b,a
        ld a,(wheel_frac)
        add a,b
        ld (wheel_frac),a
        ld hl,(wheel_x)
        dec hl                      ; WHEEL_SPEED is 1
        jr nc,.one
        dec hl
        ; Two pixels. wheel_colours_fast finds a column from the shift
        ; it lands on: 7 paints the new left column, 4 gives the old
        ; right one back. Landing on 6 or 3 stepped over one of them,
        ; and the column was missed: a cell left in the bomb's ink. Those
        ; two landings repaint the whole rectangle instead.
        ld a,l
        and 7
        cp 6
        jr z,.over
        cp 3
        jr nz,.one
.over:  ld a,1
        ld (wheel_odd),a
.one:   ld (wheel_x),hl
        ld de,WHEEL_WIDTH
        add hl,de
        bit 7,h
        jr nz,.leave
        ld a,h
        or l
        ret nz
        jr .leave

.scaled:
        ; Steps along the sine. Bob speed and the 25-frame step are both
        ; small numbers, so adding them is the multiply.
        ld a,(wheel_bob_spd)
        ld b,a
        ld a,(step_ticks)
        ld c,a
        xor a
.spd:   add a,b
        dec c
        jr nz,.spd
        ld hl,wheel_bob_i
        add a,(hl)
        and 31
        ld (hl),a

        call wheel_apply_wobble
        call wheel_place

.spin2: ; The wave joins here at 25 (level.asm). Spin. The hold is 8 frames and a step is 1 or 2, so this
        ; advances the picture at most once per step at the normal hold.
        ld a,(step_ticks)
        ld b,a
        ld a,(wheel_spin_n)
        add a,b
.spin:  cp WHEEL_SPIN           ; patched, as .hold1
        jr c,.spun
.hold2: sub WHEEL_SPIN           ; and this
        push af
        call wheel_next_frame
        pop af
        jr .spin
.spun:  ld (wheel_spin_n),a

        ; One pixel per 1/50 second, times the step. WHEEL_SPEED is 1.
        ; Each 1/50 second also adds the level's haste to the fraction,
        ; and a carry is one pixel more.
        ld a,(step_ticks)
        ld b,a
        ld c,a
        ld a,(wheel_haste)
        ld e,a
        ld a,(wheel_frac)
.haste: add a,e
        jr nc,.slow
        inc c
.slow:  djnz .haste
        ld (wheel_frac),a
        ld b,WHEEL_SPEED - 1    ; 0. A speed above 1 would need a real multiply.
        ld hl,(wheel_x)
        or a
        sbc hl,bc
        ld (wheel_x),hl

        ; Gone once the right-hand pixel is off the screen too:
        ; x + width <= 0.
        ld de,WHEEL_WIDTH
        add hl,de
        bit 7,h
        jr nz,.leave            ; x + width is negative
        ld a,h
        or l
        ret nz                  ; still a pixel on the screen, or more
.leave: jp wheel_remove

.waiting:
        ; Subtract the whole step. A delay of 1 at 50, or 2 at 25, is the
        ; step that spawns. Going past zero spawns as well: the pause is
        ; in 1/50 seconds, and it must not run long just because the step
        ; is two frames wide.
        ld a,(step_ticks)
        ld b,a
        ld a,(wheel_delay)
        sub b
        jr z,.spawn
        jr c,.spawn
        ld (wheel_delay),a
        ret
.spawn: call wheel_next_height  ; a new middle, from the shift register
        ld hl,256               ; left pixel just past the right edge
        ld (wheel_x),hl
        xor a
        ld (wheel_bob_i),a
        ld (wheel_spin_n),a
        ld (wheel_frame),a
        ld (wheel_step),a
        call wheel_spawn_type
        call wheel_place
        ld a,WHEEL_FLY
        ld (wheel_phase),a
        ret

;------------------------------------------------------------------------------
; wheel_remove - this bomb is over: start the pause before the next one
; Used when it leaves through the left edge, and when it hits the diver.
; Nothing is wiped here. The next wheel_draw sees the pause, the restore
; before it has already put the last photograph back, and
; wheel_colours_clear gives the cells back their own colour.
; Corrupts: AF
;------------------------------------------------------------------------------
wheel_remove:
        xor a
        ld (wheel_phase),a
        ld a,WHEEL_GAP
        ld (wheel_delay),a
        ret

;------------------------------------------------------------------------------
; wheel_place - pixel y from the middle plus this step of the sine
; The picture stays on the screen: y is held at 0 and at 180, which is
; the lowest top that still keeps the bottom pixel on row 23.
; Corrupts: AF, BC
;------------------------------------------------------------------------------
wheel_place:
        ld a,(wheel_base)
        ld b,a
        call wheel_bob_offset
        ld c,a
        bit 7,c
        jr z,.down
        ld a,c
        neg
        ld d,a
        ld a,b
        sub d
        jr nc,.store
        xor a
        jr .store
.down:  ld a,b
        add a,c
        jr c,.low
        cp 181
        jr c,.store
.low:   ld a,180
.store: ld (wheel_y),a
        ret

;------------------------------------------------------------------------------
; wheel_bob_offset - the signed pixel offset for this step of the sine
; The table is a swing of 6. A bomb whose swing is 6 uses the byte as
; it stands, which is the original bob and the one the soak measures.
; Any other swing multiplies by the swing and divides by 6.
; Out: A = signed offset. Corrupts: AF, DE, HL. BC kept apart from A.
;------------------------------------------------------------------------------
wheel_bob_offset:
        ld a,(wheel_bob_i)
        and 31
        ld hl,wheel_bob
        add a,l
        ld l,a
        jr nc,.in
        inc h
.in:    ld a,(hl)
        ld e,a
        ld a,(wheel_swing)
        cp WHEEL_BOB
        ld a,e
        ret z
        or a
        ret z
        push bc
        ld b,0
        bit 7,a
        jr z,.abs
        neg
        ld b,1
.abs:   ld c,a                  ; 1..6
        ld a,(wheel_swing)
        ld d,a
        xor a
.mul:   add a,d
        dec c
        jr nz,.mul
        ; A is the table times the swing. Divide by 6, dropping the
        ; remainder. The result is smaller than the true value, never
        ; larger, so a tall swing cannot step past the clamp by a pixel
        ; the table did not mean.
        ld d,a
        xor a
.div:   ld e,a
        ld a,d
        sub WHEEL_BOB
        jr c,.quot
        ld d,a
        ld a,e
        inc a
        jr .div
.quot:  ld a,e
        bit 0,b
        jr z,.sign
        neg
.sign:  pop bc
        ret

;------------------------------------------------------------------------------
; wheel_apply_wobble - one nudge, or nothing
; Wobble 0 returns before the shift register is touched. The soak's
; height order depends on that register, and a bomb with no wobble must
; not spend a value from it.
;
; Otherwise one new byte. The low four bits are a roll of 0..15. If that
; roll is greater than or equal to the wobble, nothing moves: wobble 1
; nudges about one step in sixteen, wobble 8 about half of them, wobble
; 15 nearly all of them.
; Bit 0 of the byte grows or shrinks the swing by one pixel. The swing
; stays between 0 and twice the height in the settings.
; Bit 1 drifts the middle down or up by one pixel. The picture is kept
; on the screen.
; Corrupts: AF, BC, HL
;------------------------------------------------------------------------------
wheel_apply_wobble:
        ld a,(wheel_wobble)
        or a
        ret z
        call wheel_rng
        ld b,a
        and 15
        ld c,a
        ld a,(wheel_wobble)
        dec a
        cp c
        ret c                   ; roll >= wobble: this step is smooth
        ld a,1
        ld (wheel_odd),a        ; the colour rectangle may have jumped
        bit 0,b
        jr nz,.shrink
        ld a,(wheel_swing)
        inc a
        ld hl,wheel_swing_max
        cp (hl)
        jr c,.setsw
        jr z,.setsw
        ld a,(hl)
.setsw: ld (wheel_swing),a
        jr .drift
.shrink:
        ld hl,wheel_swing
        ld a,(hl)
        or a
        jr z,.drift
        dec (hl)
.drift: bit 1,b
        jr nz,.up
        ld hl,wheel_base
        inc (hl)
        jr wheel_clamp_base
.up:    ld a,(wheel_base)
        or a
        jr z,wheel_clamp_base
        dec a
        ld (wheel_base),a
        ; fall through

; Pull the middle back inside the water: the top of the swing below the
; score row, the bottom inside the picture. A middle that already fits
; is not changed: every height the soak uses already fits.
wheel_clamp_base:
        ld a,(wheel_swing)
        add a,WHEEL_TOP_Y
        ld b,a
        ld a,(wheel_base)
        cp b
        jr nc,.above
        ld a,b
        ld (wheel_base),a
.above: ld a,(wheel_swing)
        ld b,a
        ld a,180
        sub b
        ld b,a
        ld a,(wheel_base)
        cp b
        ret c
        ret z
        ld a,b
        ld (wheel_base),a
        ret

        ; Once a bomb, as it appears: in the cold block, with its tables.
        ; (Trigon's second bomb, B2_PASS, keeps its copy with its code.)
    IFNDEF B2_PASS
        COLD
    ENDIF
;------------------------------------------------------------------------------
; wheel_type - this level's kind of bomb: its five settings, its pictures
; level_bomb (from CFG_LEVELS) picks the pulsar or the spinning wheel.
; The pictures are switched by patching two operands, the draw's table
; and the animation's order, so the draw costs exactly what it did. Only
; called when a bomb appears, never while one is on the screen.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_type:
        ld a,(level_bomb)
    IFDEF MEAS_SPIN
        ld a,BOMB_W             ; measure the spinning wheel at level 1
    ENDIF
    IFDEF SHARED_BOMB
    IFNDEF B2_PASS
        call bomb_art           ; Trigon: this kind's copies, if not made (twobomb.asm)
    ENDIF
    ENDIF
        ld hl,enemy_wheel
        ld de,wheel_pics
        ld c,WHEEL_SPIN
        cp BOMB_W
        jr nz,.got
        ld hl,enemy_spin
        ld de,spin_pics
        ld c,SPIN_HOLD_SLOW     ; the roll: see SPIN_HOLD_SLOW
        ld a,(wheel_haste)
        cp SPIN_MID_HASTE
        jr c,.got
        ld c,SPIN_HOLD_MID
        cp SPIN_FAST_HASTE
        jr c,.got
        ld c,SPIN_HOLD_FAST
.got:   ld a,c
        ld (wheel_drift.hold1 + 1),a
        ld (wheel_drift.spin + 1),a
        ld (wheel_drift.hold2 + 1),a
        push de
        ld de,wheel_swing
        ld bc,ENEMY_ROW
        ldir
        ; The level's colour and movement (CFG_LEVELS) over the row's.
        ; MEAS_SPIN keeps the spinning wheel's own red at level 1.
    IFNDEF MEAS_SPIN
        ld a,(level_ink)
        ld (wheel_ink),a
    ENDIF
        ld a,(level_bmove)
        ld (wheel_kind),a
        ld a,(level_hunt)       ; MOVE_HOME's strength (0 for the others)
        ld (wheel_hunt),a
    IFDEF TRIGON
        call mv_pick            ; or, at random, the level's second (moves.asm)
    ENDIF
        ld a,1
        ld (wheel_hunting),a    ; a new bomb starts right of the diver
        xor a
        ld (wheel_hfrac),a
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (wheel_draw.img + 1),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (wheel_next_frame.seq + 1),de
        ret

; Each kind's pictures and animation order.
wheel_pics:     dw wheel_images, wheel_seq
spin_pics:      dw wspin_images, wspin_seq
    IFNDEF B2_PASS
        HOT
    ENDIF

;------------------------------------------------------------------------------
; wheel_spawn_type - copy the settings onto this bomb
; Five bytes: swing, bob speed, wobble, kind, colour. With wobble above
; 0 the new bomb also starts somewhere else on the sine, and takes one
; nudge, so two bombs of the same type do not travel together.
; A wobble of 0 does none of that, and does not touch the shift register.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_spawn_type:
        call wheel_type
        ld a,(wheel_swing)
        add a,a
        ld (wheel_swing_max),a
        ld a,(wheel_wobble)
        or a
        jp z,wheel_clamp_base
        call wheel_rng
        and 31
        ld (wheel_bob_i),a
        call wheel_apply_wobble
        jp wheel_clamp_base

;------------------------------------------------------------------------------
; wheel_next_frame - one step along wheel_seq
; The pictures are stored once each. wheel_seq says which shape this
; step shows, and that number is what the draw loads. Called only when
; the spin hold runs out, not while the picture is being copied.
; Corrupts: AF, HL
;------------------------------------------------------------------------------
wheel_next_frame:
        ld hl,wheel_step
        ld a,(hl)
        inc a
        cp WHEEL_FRAMES
        jr c,.step
        xor a
.step:  ld (hl),a
.seq:
        ld hl,wheel_seq         ; or wspin_seq: patched by wheel_type
        add a,l
        ld l,a
        jr nc,.got
        inc h
.got:   ld a,(hl)
        ld (wheel_frame),a
        ret

    IFNDEF B2_PASS
        COLD
    ENDIF
;------------------------------------------------------------------------------
; wheel_reset - the bomb the tape starts with
; Fixed height, the start of the sine, just off the right edge. This is
; not a spawn: the shift register stays on its seed, so the first bomb
; the player meets is the same one every time.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_reset:
        call wheel_type
        ld a,(wheel_swing)
        add a,a
        ld (wheel_swing_max),a
        ld hl,256
        ld (wheel_x),hl
        ld a,36
        ld (wheel_y),a
        ld (wheel_base),a
        xor a
        ld (wheel_bob_i),a
        ld (wheel_frame),a
        ld (wheel_step),a
        ld (wheel_spin_n),a
        ld (wheel_delay),a
        ld (wheel_odd),a
        ld (wheel_attr_n),a
        ld (wheel_shown),a
        ld a,42
        ld (wheel_seed),a
        ld a,WHEEL_FLY
        ld (wheel_phase),a
        ret

    IFNDEF B2_PASS
        HOT
    ENDIF

;------------------------------------------------------------------------------
; wheel_is_low - carry clear if this bomb has to be drawn after the seabed
; A bomb whose bottom pixel is on the weed, the sand or the ground is
; covered by the seabed copy, the same way the diver is. Carry set means
; it is up in the water, or it is not on screen, and the early draw is
; the right one. Corrupts: AF
;------------------------------------------------------------------------------
wheel_is_low:
        ld a,(wheel_phase)
        or a
        jr z,.early
        ld a,(wheel_y)
        add a,WHEEL_HEIGHT - 1
        cp BACK_ROW * 8
        ret
.early: scf
        ret

;------------------------------------------------------------------------------
; wheel_next_height - step the LFSR and take a base from the table
; The low 3 bits pick one of 8 heights. Every entry is between
; WHEEL_TOP_BASE and WHEEL_LOW_BASE, so the bob cannot leave the water.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
wheel_next_height:
        call wheel_rng
        and 7
        ld e,a
        ld d,0
        ld hl,wheel_heights
        add hl,de
        ld a,(hl)
        ld (wheel_base),a
        ret

;------------------------------------------------------------------------------
; wheel_rng - one step of an 8-bit LFSR. A is the new value.
;
; The other cheap source is the R register. R counts instructions, so it
; changes when a frame runs long, and a soak test could not know which
; height was coming. This sequence is the same every time the game is
; switched on.
;
; Galois form, polynomial x^8 + x^6 + x^5 + x^4 + 1. The shifted-out bit
; selects the xor with $B8. Period 255. Seed 0 would stay 0, so the seed
; below is not 0, and the xor keeps it off 0.
;
; Seed 42. The first step is 21 (index 5, the fish's depth). The second
; is 178 (index 2, the surface). The soak counts on that order.
; Corrupts: AF
;------------------------------------------------------------------------------
wheel_rng:
        ld a,(wheel_seed)
        srl a                   ; bit 0 into carry, a zero into bit 7
        jr nc,.keep
        xor $B8
.keep:  ld (wheel_seed),a
        ret

;------------------------------------------------------------------------------
; wheel_restore - put back the pixels and the attribute bytes from last
;                 frame
; wheel_draw    - photograph the new position, draw, and colour the cells,
;                 or do none of that when it is fully off the screen
; Drawn after the fish and before the diver, so the fish is behind it
; and the diver is in front. It never reaches the seaweed, so it is
; always drawn before the seabed copy. Both of these run at the start
; of the frame, while the beam is still up in the border on a frame
; that finishes on time. That is what keeps the erase from flickering.
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
wheel_restore:
        ld iy,wheel_bg
        jp fast_restore

wheel_draw:
        ld a,(wheel_phase)
        or a
        jr z,.off               ; the pause: nothing on screen

        ; Stored width depends on the shift. The low 3 bits of x pick
        ; it, including when x is negative: -1 has low bits 7, and that
        ; copy is 3 bytes. sprite_set_pos_x then clips that width.
        ld hl,(wheel_x)
        ld a,l
        and 7
        ld e,a
        ld d,0
        ld hl,wheel_shift_bytes
        add hl,de
        ld d,(hl)               ; stored bytes for this shift
        ld a,(wheel_y)
        ld b,a
        ld e,WHEEL_HEIGHT
        ld hl,(wheel_x)
        call sprite_set_pos_x
        ld a,(spr_hidden)
        or a
        jr nz,.off

        ; The ink is the byte copied from the settings when this bomb
        ; appeared. It is already in wheel_ink. A draw does not look
        ; it up again.

        ld iy,wheel_bg
        call fast_save

        ld a,(wheel_frame)      ; shape number, from wheel_seq
.img:
        ld hl,wheel_images      ; or wspin_images: patched by wheel_type
        call sprite_image
        call fast_pick          ; HL -> image for this shift

        ; Fully on screen: every stored byte is drawn, and the gap
        ; between rows is zero. That is the slow case (a shift of 5, 6
        ; or 7 is three bytes, and all three are on the screen). Skip
        ; the "add the gap" step, which would be adding zero.
        ; Clipped: step over the pairs hanging off the left, then
        ; fast_draw_gap skips the hidden pairs after each row.
        ld a,(spr_skip2)
        or a
        jr nz,.clipped
        ld a,(spr_gap2)
        or a
        jr nz,.clipped
        call fast_draw
        ret
.clipped:
        ld a,(spr_skip2)
        add a,l
        ld l,a
        jr nc,.noskip
        inc h
.noskip:
        call fast_draw_gap
        ret

.off:   ; Fully off, or waiting. wheel_colours, which runs next and
        ; still before the seabed copy, puts the water colour back on
        ; the rectangle. Drop the pixel record so the next restore
        ; does not paint the old photograph.

        ld iy,wheel_bg
        ld (iy+BG_VALID),0
        ret


;------------------------------------------------------------------------------
; wheel_colours - keep the bomb's ink on its rectangle
;
; The bomb moves one pixel a frame, so it usually stays inside the same
; character cells. Those cells are already the right colour. Writing
; them again, and putting the old bytes back first, was a few scanlines
; on every frame, and the frames where the rectangle was three cells
; tall missed the interrupt.
;
; The common frame finds the same rectangle as last time and returns.
; While the whole bomb is on the screen, the column that changed is
; read from the shift instead of from a second compare: shift 7 paints
; the new left column, shift 4 puts the old right column back. A frame
; that is clipped compares the rectangle and updates the strip that
; moved. The strip is written in the bomb's ink, or back to the water
; colour. It does not read the old bytes. Everything above the seaweed
; is the water colour, apart from the title word, which is put back
; when a strip that covered it is given back to the sea.
;
; A store to wheel_colour is picked up on this frame even when the
; rectangle has not moved: the byte last written is wheel_shown.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_colours:
    IFDEF NO_INK
        ; Measurement only. The tape does not define this. It leaves the
        ; ink out so the spare-scanline count can be taken without the
        ; attribute fill.
        ret
    ENDIF
        call wheel_attr_box
        jr z,.clear
        ; Two pixels in one step (25 frames a second), or a wobble
        ; nudge, does not fit the one-pixel colour path. Paint the
        ; whole rectangle again. The same if the rectangle touches the
        ; weed, the sand or the ground: those cells are not plain water,
        ; and the one-pixel path only knows how to put water back.
        ld a,(step_ticks)
        cp 1
        jr nz,.full
        ld a,(wheel_odd)
        or a
        jr nz,.full
        ld a,(wheel_r1)
        cp BACK_ROW
        jr nc,.full
        ld a,(wheel_attr_n)
        or a
        jr z,.fast
        ld a,(wheel_pr1)
        cp BACK_ROW
        jr nc,.full
.fast:  xor a
        ld (wheel_odd),a
        ld a,(wheel_attr_n)
        or a
        jp z,wheel_paint_attrs
        ld a,(wheel_ink)
        ld hl,wheel_shown
        cp (hl)
        jp nz,wheel_full_recolour

        ; Partly or wholly on the screen. The box already returned
        ; otherwise, and that case was the clear above. Past the left
        ; edge the right-hand column shrinks; the shift is not used
        ; there (wheel_colours_fast.column). Repainting the whole
        ; rectangle on the way out was the seabed frame that missed.
        jp wheel_colours_fast
.full:  xor a
        ld (wheel_odd),a
        jp wheel_full_recolour
.clear: xor a
        ld (wheel_odd),a
        jp wheel_colours_clear

;------------------------------------------------------------------------------
; wheel_colours_fast - the bomb is wholly on screen and the ink is the
; same as last frame
; A one-pixel slide to the left changes a column only on two shifts.
; Shift 7: the left pixel has entered a new cell, so that column is
; painted. Shift 4: the right pixel has left a cell, so the old column
; is put back to the water colour. Any other shift is the same columns.
; The bob moves one pixel up, one down, or not at all, so at most one
; row edge changes, and only by one cell.
; Working out which edge from the two column numbers, then checking the
; difference was exactly one, was most of the time on the frame that
; also draws the three-byte picture.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_colours_fast:
        ; The row test comes first. Most frames do not cross a row, and
        ; then only the shift is looked at. The accumulator holds the
        ; new row while HL points at the old one, so a difference of one
        ; does not have to be loaded again.
        ld a,(wheel_r0)
        ld hl,wheel_pr0
        cp (hl)
        jr nz,.top
        inc hl                      ; the old bottom row sits next to it
        ld a,(wheel_r1)
        cp (hl)
        jr nz,.bottom
        call .column
        ret z                       ; same rectangle: nothing to write
        jp wheel_remember_edges

.top:   sub (hl)                    ; new top minus the old top
        cp 1
        jr z,.drop_top              ; moved down: the old top row is left
        cp $FF
        jr nz,.odd                  ; not a one-cell step
        ld a,(wheel_r0)
        ld b,a
        ld a,(wheel_ink)
        ld d,a
        call wheel_paint_row        ; the new top row, current columns
        jr .both
.drop_top:
        ld a,(wheel_pr0)
        ld b,a
        call wheel_water_row
        jr .both

.bottom:sub (hl)
        cp 1
        jr z,.add_bot
        cp $FF
        jr nz,.odd
        ld a,(wheel_pr1)
        ld b,a
        call wheel_water_row
        jr .both
.add_bot:
        ld a,(wheel_r1)
        ld b,a
        ld a,(wheel_ink)
        ld d,a
        call wheel_paint_row

.both:  call .column
        jp wheel_remember_edges

.odd:   ; The bob only ever steps one pixel, so this is a safety net
        ; (a height change that is not a single cell). Repaint. Nothing
        ; has been written yet on this path.
        jp wheel_full_recolour

; Shift 7 paints the new left column. Shift 4 puts the old right column
; back. Anything else leaves the columns alone and returns with the zero
; flag set. A column that is written returns with the zero flag clear.
.column:
        ; Off the left, a pixel is still showing (the box said so). The
        ; left edge stays column 0, so only the right edge can move, and
        ; a one-pixel step moves it by one cell. The low byte of a
        ; negative x is not a shift we can trust.
        ld a,(wheel_x+1)
        or a
        jr z,.by_shift
        ld a,(wheel_c0)
        ld hl,wheel_pc0
        cp (hl)
        jr nz,.odd_col
        ld a,(wheel_c1)
        inc hl                      ; the old right column
        cp (hl)
        jr z,.none
        ld b,a
        ld a,(hl)
        sub b
        cp 1
        jr nz,.odd_col
        ld c,(hl)
        ld a,(wheel_pr0)
        ld b,a
        ld a,(wheel_pr1)
        sub b
        inc a
        ld e,a
        call wheel_water_cells_col
        or 1
        ret
.odd_col:
        pop af                      ; drop the return from call .column
        jp wheel_full_recolour
.by_shift:
        ld a,(wheel_x)
        and 7
        cp 7
        jr z,.add_left
        cp 4
        jr nz,.none
        ; Shift 4 is a right-hand column left behind only once the right
        ; pixel is on the screen (x <= 243). While the bomb is still
        ; clipped on the right, that column was never painted: x = 244
        ; is shift 4 and the old right edge is still column 31.
        ld a,(wheel_x)
        cp 244
        jr c,.drop_right
.none:  xor a
        ret
.add_left:
        ld a,(wheel_c0)
        ld c,a
        ld a,(wheel_ink)
        ld d,a
        ld a,(wheel_r0)
        ld b,a
        ld a,(wheel_r1)
        sub b
        inc a
        ld e,a                      ; how many rows the new column covers
        call wheel_solid_col
        or 1
        ret
.drop_right:
        ld a,(wheel_pc1)            ; the column just left behind
        ld c,a
        ld a,(wheel_pr0)
        ld b,a
        ld a,(wheel_pr1)
        sub b
        inc a
        ld e,a
        call wheel_water_cells_col
        or 1
        ret

wheel_colours_clear:
    IFDEF NO_INK
        ret
    ENDIF
        ld a,(wheel_attr_n)
        or a
        ret z
        call wheel_restore_attrs
        ret

;------------------------------------------------------------------------------
; wheel_restore_attrs - water colour back on the rectangle from last frame
; The address and the size were saved when it was painted, so this does
; not work them out again. The title word is yellow, so any cell of it
; inside that rectangle is put back afterwards. The count is cleared.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_restore_attrs:
        ld a,(wheel_attr_n)
        or a
        ret z
        ; One row at a time. Open water goes back to the water colour.
        ; A row of weed, sand or ground goes back to that row's own
        ; colour. There is no title word on the play screen, so row 2
        ; is water like every other row above the weed.
        ld a,(wheel_pr0)
        ld b,a
.row:   push bc
        ld a,(wheel_pc0)
        ld c,a
        ld a,(wheel_pc1)
        sub c
        inc a
        ld e,a
        call wheel_restore_span
        pop bc
        ld a,(wheel_pr1)
        cp b
        jr z,.rows_done
        inc b
        jr .row
.rows_done:
        xor a
        ld (wheel_attr_n),a
        ld (wheel_shown),a
        ret

; B = row, C = left column, E = how many columns.
wheel_restore_span:
        ld a,b
        cp BACK_ROW
        jp nc,wheel_scenery_span
        ld d,WATER_ATTR
        jp wheel_solid_row

;------------------------------------------------------------------------------
; wheel_attr_box - the character cells this bomb covers
; Out: Z if it is waiting, or fully off the screen.
;      NZ, and wheel_c0..wheel_c1, wheel_r0..wheel_r1 are inclusive.
;      The bottom row can be the weed, the sand or the ground. A bomb
;      that reaches them is drawn in its own colour there, and the old
;      colour is put back when it leaves. The bottom pixel is held on
;      the screen: row 23 is the last row.
; x between 0 and 255 is the short path. That is every frame where the
; whole bomb is on the screen, which is the slow frame. Hanging off
; the left or the right is the longer path under it.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
wheel_attr_box:
        ld a,(wheel_phase)
        or a
        ret z

        ld hl,(wheel_x)
        bit 7,h
        jr nz,.negative
        ld a,h
        or a
        jr z,.on_screen
        xor a                   ; x >= 256, still off the right
        ret

.on_screen:
        ld a,l
        rrca
        rrca
        rrca
        and 31
        ld (wheel_c0),a
        ld a,l
        add a,WHEEL_WIDTH - 1
        jr nc,.last_ok
        ld a,255
.last_ok:
        rrca
        rrca
        rrca
        and 31
        ld (wheel_c1),a
        jr .rows

.negative:
        ld de,WHEEL_WIDTH
        add hl,de               ; x + width. Positive: a pixel is on.
        bit 7,h
        jr z,.some_left
        xor a
        ret
.some_left:
        ld a,h
        or l
        ret z
        xor a
        ld (wheel_c0),a
        ld hl,(wheel_x)
        ld de,WHEEL_WIDTH - 1
        add hl,de
        ld a,l
        rrca
        rrca
        rrca
        and 31
        ld (wheel_c1),a

.rows:  ld a,(wheel_y)
        rrca
        rrca
        rrca
        and 31
        ld (wheel_r0),a
        ld a,(wheel_y)
        add a,WHEEL_HEIGHT - 1
        cp 192
        jr c,.bottom_ok
        ld a,191
.bottom_ok:
        rrca
        rrca
        rrca
        and 31
        ld (wheel_r1),a
        or 1                    ; NZ. Row 0 alone would leave A = 0.
        ret

;------------------------------------------------------------------------------
; wheel_paint_attrs - ink across the rectangle worked out just above
; The rectangle is already in wheel_c0..wheel_r1. Paper stays blue,
; because that is what the palette entries use. The title word is
; covered in the same ink for as long as the bomb sits on it, and
; The old rectangle is then put back to the colour of whatever it covered.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_paint_attrs:
        ; Attribute address of the top-left cell. Same arithmetic as
        ; attr_addr, written here so the repaint does not pay for a call.
        ld a,(wheel_r0)
        rrca
        rrca
        rrca
        ld l,a
        and %00000011
        or high ATTRS
        ld h,a
        ld a,l
        and %11100000
        ld c,a
        ld a,(wheel_c0)
        or c
        ld l,a
        ld (wheel_pat),hl

        ld a,(wheel_c1)
        ld c,a
        ld a,(wheel_c0)
        ld b,a
        ld a,c
        sub b
        inc a
        ld (wheel_pcols),a
        ld c,a                  ; C = columns

        ld a,(wheel_r1)
        ld b,a
        ld a,(wheel_r0)
        ld e,a
        ld a,b
        sub e
        inc a
        ld (wheel_prows),a
        ld b,a                  ; B = rows

        ld hl,(wheel_pat)       ; the width math used A, not HL, but be sure
        ld a,(wheel_ink)
        ld d,a
        call wheel_fill_hl
        jp wheel_remember

; Colour changed: the whole old rectangle goes back to water, then the
; whole new one is painted. This is rare (the drifting bomb does not
; change colour mid-flight). A one-pixel move uses wheel_delta instead.
wheel_full_recolour:
        call wheel_restore_attrs
        jp wheel_paint_attrs

;------------------------------------------------------------------------------
; wheel_remember - the rectangle just painted is the one to compare next
; Corrupts: AF, HL
;------------------------------------------------------------------------------
wheel_remember_fast:
        ld a,(wheel_ink)
        ld (wheel_shown),a
        ld a,1
        ld (wheel_attr_n),a
        ; Fall through. The fast path, which already knows the ink has
        ; not changed and a rectangle is on screen, enters here.
wheel_remember_edges:
        ; The new rectangle is four bytes in a row, and so is the copy
        ; kept for next frame, in the same order. Two word stores move
        ; all four. The order of the bytes inside the word does not
        ; matter: the same pair is written back.
        ld hl,(wheel_c0)
        ld (wheel_pc0),hl
        ld hl,(wheel_r0)
        ld (wheel_pr0),hl
        ret

wheel_remember:
        call wheel_remember_fast
        ; Address and size, for a later full restore.
        ld a,(wheel_r0)
        rrca
        rrca
        rrca
        ld l,a
        and %00000011
        or high ATTRS
        ld h,a
        ld a,l
        and %11100000
        ld c,a
        ld a,(wheel_c0)
        or c
        ld l,a
        ld (wheel_pat),hl
        ld a,(wheel_c1)
        ld c,a
        ld a,(wheel_c0)
        ld b,a
        ld a,c
        sub b
        inc a
        ld (wheel_pcols),a
        ld a,(wheel_r1)
        ld b,a
        ld a,(wheel_r0)
        ld c,a
        ld a,b
        sub c
        inc a
        ld (wheel_prows),a
        ret

; Paint one new row. B = row, D = ink.
wheel_paint_row:
        ld a,(wheel_c0)
        ld c,a
        ld a,(wheel_c1)
        sub c
        inc a
        ld e,a
        call wheel_solid_row
        ret

; Water back one old row. B = row.
wheel_water_row:
        ld a,(wheel_pc0)
        ld c,a
        ld a,(wheel_pc1)
        sub c
        inc a
        ld e,a
        call wheel_water_cells_row
        ret

; B = top row, C = column, E = number of rows, D = byte.
wheel_solid_col:
        call attr_addr
.cell:  ld (hl),d
        dec e
        ret z
        ld a,l
        add a,32
        ld l,a
        jr nc,.cell
        inc h
        jr .cell

; B = top row, C = column, E = number of rows.
; Above the weed every cell is the water colour. A column that reaches
; the weed is restored one cell at a time, because the rows are not all
; the same colour.
wheel_water_cells_col:
        ld a,b
        cp BACK_ROW
        jr nc,.scenery
        add a,e
        dec a
        cp BACK_ROW
        jr c,.plain
.scenery:
        call attr_addr
.cell:  push de
        call wheel_cell_colour
        pop de
        ld (hl),a
        dec e
        ret z
        inc b
        ld a,l
        add a,32
        ld l,a
        jr nc,.cell
        inc h
        jr .cell
.plain: ld d,WATER_ATTR
        jp wheel_solid_col

; B = row, C = left column, E = number of columns, D = byte.
wheel_solid_row:
        call attr_addr
.cell:  ld (hl),d
        dec e
        ret z
        inc c
        inc l
        jr .cell

; B = row, C = left column, E = number of columns.
wheel_water_cells_row:
        jp wheel_restore_span

; A row of the seabed. Weed is not one colour for the whole row: a cell
; with a plant is green, and the rest is water. paint_weed_attrs writes
; the whole row from the plants, which is correct when we are putting
; the whole old rectangle back. A one-cell strip calls wheel_cell_colour
; instead, so a plant the bomb is still sitting on is not wiped early.
wheel_scenery_span:
        ld a,b
        cp SAND_ROW
        jr z,.sand
        cp GROUND_ROW
        jr z,.ground
        cp BACK_ROW
        jr z,.weed
        ld d,WATER_ATTR
        jp wheel_solid_row
.sand:  ld d,SAND_ATTR
        jp wheel_solid_row
.ground:
        ld d,GROUND_ATTR
        jp wheel_solid_row
.weed:  ; The bomb's new cells are painted after this returns. Painting
        ; the plants first, across the whole row, puts back every cell
        ; the bomb has left, including ones beside the span.
        push bc
        push de
        call paint_weed_attrs
        pop de
        pop bc
        ret

; Out: A = the colour this cell should be when the bomb is not on it.
; In:  B = row, C = column. Corrupts: AF. Used for a single column that
;      crosses more than one kind of row. The weed answer is water if we
;      cannot cheaply know the plant: paint_weed_attrs is the accurate
;      path, and the one-pixel path does not come here for a bomb that
;      touches the weed (that bomb is repainted in full).
wheel_cell_colour:
        ld a,b
        cp SAND_ROW
        jr z,.sand
        cp GROUND_ROW
        jr z,.ground
        cp BACK_ROW
        jr nc,.water
        ld a,WATER_ATTR
        ret
.sand:  ld a,SAND_ATTR
        ret
.ground:
        ld a,GROUND_ATTR
        ret
.water: ld a,WATER_ATTR
        ret

;------------------------------------------------------------------------------
; wheel_fill_hl - write D across the rectangle
; In:  HL = first cell, B = rows, C = columns, D = the byte.
; Used for the first paint and for a colour change. A one-pixel move
; does not come here: it recolours the strip that changed, which is
; wheel_delta. A counted loop is fine on this rare path.
; A row of attributes can cross into the next page, so the carry is kept.
; Corrupts: AF, BC, HL
;------------------------------------------------------------------------------
wheel_fill_hl:
.row:   push bc
        push hl
.col:   ld (hl),d
        inc l
        dec c
        jr nz,.col
        pop hl
        ld a,l
        add a,32
        ld l,a
        jr nc,.next
        inc h
.next:  pop bc
        djnz .row
        ret

;------------------------------------------------------------------------------
wheel_on_row0:
        ld a,(wheel_phase)
        or a
        ret z
        ld a,(wheel_y)
        cp 8
        jr c,.xchk
        xor a
        ret
.xchk:  ld hl,(wheel_x)
        ld a,h
        or a
        jr z,.on                ; x is 0..255, so at least one pixel shows
        bit 7,h
        jr z,.off               ; x >= 256: still off the right
        ld de,WHEEL_WIDTH
        add hl,de               ; x + width. Positive means a pixel is on.
        bit 7,h
        jr nz,.off
        ld a,h
        or l
        jr z,.off               ; x + width = 0: the last pixel just left
.on:    ld a,1
        or a
        ret
.off:   xor a
        ret

; --- State -------------------------------------------------------------------
; The five bytes copied from enemy_wheel when a bomb appears. They sit
; together, in the same order as that row. The first bomb is already in
; flight when the tape starts, so these begin as the same numbers.
; game_reset copies them again. Wobble can change the swing and the
; middle afterwards; it does not change the row in the settings.
wheel_swing:    db CFG_WHEEL_BOB
wheel_bob_spd:  db CFG_WHEEL_BOB_SPEED
wheel_wobble:   db CFG_WHEEL_WOBBLE
wheel_kind:     db WHEEL_KIND_DRIFT
wheel_ink:      db CFG_WHEEL_INK
wheel_swing_max: db CFG_WHEEL_BOB * 2

wheel_phase:    db WHEEL_FLY
; Starts just off the right, so the first thing the player sees is it
; sliding in, not popping into existence. The first height is fixed
; (table entry 0). Later heights come from the shift register.
wheel_x:        dw 256
wheel_y:        db 36           ; matches the base; bob[0] is 0
wheel_base:     db 36
wheel_bob_i:    db 0
wheel_frame:    db 0            ; which stored shape is on screen
wheel_step:     db 0            ; where we are in wheel_seq
wheel_spin_n:   db 0
wheel_delay:    db 0
wheel_seed:     db 42
wheel_odd:      db 0            ; 1 = the last nudge may have jumped the rectangle
wheel_haste:    db 0            ; this level's extra speed, /256 of a pixel
wheel_frac:     db 0            ; the fraction it adds up in
wheel_hunt:     db 0            ; MOVE_HOME: the level's hunt, /256 of a pixel
wheel_hfrac:    db 0            ; the fraction the hunt adds up in
wheel_hunting:  db 0            ; 1 until the hunter has passed the diver

; The heights and the sine live with the other tables, above $C000.
; See data.asm.

; Non-zero once a rectangle has been painted. Above the weed the old
; cells are put back as the water colour. A cell of weed, sand or ground
; is put back as that row's own colour. wheel_pc0..wheel_pr1 is the
; rectangle. wheel_shown is the ink byte last written.
wheel_attr_n:   db 0
wheel_shown:    db 0
wheel_pc0:      db 0
wheel_pc1:      db 0
wheel_pr0:      db 0
wheel_pr1:      db 0
; Address and size of that rectangle, so putting the water back does
; not work the address out a second time.
wheel_pat:      dw 0
wheel_prows:    db 0
wheel_pcols:    db 0

; Scratch for the attribute box of the bomb as it is this frame.
wheel_c0:       db 0
wheel_c1:       db 0
wheel_r0:       db 0
wheel_r1:       db 0

; wheel_bg: in bss.asm (zeroed at start-up, not on the tape)
