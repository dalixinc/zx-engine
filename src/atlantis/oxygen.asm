;==============================================================================
; oxygen.asm - the oxygen pill (Atlantis only: O2_PILL)
;
; A sixth power-up, after the nuke (MSL_KIND_O2), from CFG_O2_LEVEL with
; its share CFG_O2_ODDS of the roll (power_tab). It sinks in the
; missile's slot like the others, in CFG_FALL_O2_INK (ink_tab). Taken,
; nothing hurts the diver for CFG_O2_TIME seconds: diver_hurt asks
; o2_hurt first, which says "no hit" while it lasts, so the bomb, the
; fish and the missile pass through him (and stay, and score nothing),
; and the black ground only holds him up. Another pill starts the time
; again.
;
; HOW IT SHOWS: the border. Atlantis's border is the level's colour,
; written into main_loop's heartbeat (step_skip.beat + 1, by
; level_style). The pill writes CFG_O2_BORDER there instead, every
; 1/50 second it lasts, and for the last CFG_O2_WARN it blinks between
; that and the level's colour, four frames each. At the end the level's
; colour goes back and the double shot's falling jingle plays. A hit's
; red flash and the special bombs' flashes still win, as before. The
; diver himself is drawn as ever: no flashing.
;
; ITS CLOCK: o2_left counts 1/50 seconds down in o2_tick, which main_loop's
; two missile_update calls go through while it lasts (msl_calls_set, here
; now: the special bombs' sp_tick first, then the pill, then the double
; shot's double_tick; each chains on to the next). Moves are not run under
; a level's banner (freeze.asm) or in the quake (it blocks), so its time
; stands still there with no pushing; also while a special bomb moves
; things (sp_tick goes straight to the double shot or the missile), at
; most CFG_SPECIAL_TIME.
;
; WHERE IT LIVES: all in the data block (O2_CODE, expanded by main.asm),
; with its picture: the UDG area, where the other kinds' cells are, is
; full, and a pill is never carried, so it needs no cell on row 1.
; power_build (cold) ends by jumping to o2_build for its sinking
; picture. Elsewhere only jumps: diver_hurt's first instruction,
; power_take's last test (o2_take_if), and special_reset clears o2_on.
;==============================================================================

O2_ATTR         equ CFG_FALL_O2_INK | SEA
        ASSERT O2_ATTR != WATER_ATTR, "the pill's ink is the water's (white)"
        ASSERT CFG_O2_TIME >= 1 && CFG_O2_TIME * 50 <= 65535, "CFG_O2_TIME: seconds, 1 to 1310"
        ASSERT CFG_O2_WARN >= 1 && CFG_O2_WARN <= 255 && CFG_O2_WARN < CFG_O2_TIME * 50, "CFG_O2_WARN: 1/50 seconds, under 256 and the pill's time"
        ASSERT CFG_O2_BORDER >= 0 && CFG_O2_BORDER <= 7

        MACRO O2_CODE

;------------------------------------------------------------------------------
; o2_hurt - diver_hurt's start: every hit asks here first. While a pill
; lasts, no hit (and ground_hit's lift after a death is not needed);
; otherwise on to the hit, as before.
; Out: carry set (a hit) or clear. Corrupts: AF
;------------------------------------------------------------------------------
o2_hurt:
        xor a
        ld (diver_touch),a
        ld a,(o2_on)
        or a
        jp z,diver_hurt.hurt    ; no pill: a hit
        xor a
        ld (death_lift),a
        ret                     ; carry clear (XOR): no hit

;------------------------------------------------------------------------------
; o2_take_if - power_take, a kind past the bubble: A = the kind less
; MSL_KIND_DOUBLE. The pill: it starts (or starts again); else a special
; bomb, as before. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
o2_take_if:
        cp MSL_KIND_O2 - MSL_KIND_DOUBLE
        jp nz,special_take
        ld a,1
        ld (o2_on),a
        ld hl,CFG_O2_TIME * 50
        ld (o2_left),hl
        ld a,CFG_O2_BORDER
        ld (step_skip.beat + 1),a ; the border, from this step
        call msl_calls_set      ; its clock
        jp power_done           ; gone, with the power-up's jingle

;------------------------------------------------------------------------------
; o2_tick - main_loop's missile_update calls while a pill lasts, once a
; 1/50 second: its time, the border, then the double shot's clock or the
; missile. Corrupts: AF, BC, DE, HL (as missile_update)
;------------------------------------------------------------------------------
o2_tick:
        ld hl,(o2_left)
        dec hl
        ld (o2_left),hl
        ld a,h
        or l
        jr z,o2_end
        ld a,h
        or a
        ld a,CFG_O2_BORDER
        jr nz,o2_border         ; plenty left
        ld a,l
        cp CFG_O2_WARN
        ld a,CFG_O2_BORDER
        jr nc,o2_border
        bit 2,l                 ; the last moments: four frames each
        jr z,o2_border
        ld a,(level_border)
        and 7
o2_border:
        ld (step_skip.beat + 1),a ; the heartbeat's LD A,colour (level_style)
o2_chain:
        ld a,(double_on)
        or a
        jp nz,double_tick
        jp missile_update
o2_end:                         ; A = 0
        ld (o2_on),a
        ld a,(level_border)
        and 7
        ld (step_skip.beat + 1),a ; the level's border again
        call msl_calls_set      ; the calls without the pill
    IFNDEF NO_SOUND
        ld hl,snd_tune_down
        call snd_tune_start     ; the double shot's falling jingle
    ENDIF
        jr o2_chain

;------------------------------------------------------------------------------
; msl_calls_set - main_loop's two missile_update calls (.msl_uc1, .msl_uc2)
; to sp_tick while a bomb moves things, else to o2_tick while a pill
; lasts, else to double_tick while the double shot lasts, else to
; missile_update itself. (special.asm's, cold, without the pill.)
; Corrupts: AF, HL
;------------------------------------------------------------------------------
msl_calls_set:
        ld hl,sp_tick
        ld a,(sp_left)
        or a
        jr nz,o2_set
        ld hl,o2_tick
        ld a,(o2_on)
        or a
        jr nz,o2_set
        ld hl,double_tick
        ld a,(double_on)
        or a
        jr nz,o2_set
        ld hl,missile_update
o2_set: ld (fish_mv.msl_uc1 + 1),hl
        ld (fish_mv2.msl_uc2 + 1),hl
        ret

;------------------------------------------------------------------------------
; o2_build - power_build's end: the pill's sinking picture after the
; other kinds', mask then ink a row, as theirs.
; In: DE = its place in POWER_PICS. Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
o2_build:
        ld hl,o2_glyph
        ld b,8
o2_brow:
        ld a,(hl)
        inc hl
        cpl
        ld (de),a
        inc de
        cpl
        ld (de),a
        inc de
        djnz o2_brow
        ret

; The pill: a capsule, half hollow. Ink only, as row 1's cells.
o2_glyph:
        db %00000000  ; ........
        db %00000000  ; ........
        db %01111110  ; .######.
        db %10001111  ; #...####
        db %10001111  ; #...####
        db %10001111  ; #...####
        db %01111110  ; .######.
        db %00000000  ; ........

        ASSERT ({step_skip.beat} & $FF) == $2A, "the heartbeat does not start LD HL,(nn): level_style's fixed border goes over it"

        ENDM
