;==============================================================================
; trigon/moves.asm - the bombs' new movements, and the level's settings
; for them (Trigon only)
;
; Assembled twice: in the data block for the first bomb, and in module
; b2 for the second (twobomb.asm), which keeps the bob, the wave and the
; hunter: the zigzag, stop-start and the zinger are the first bomb's
; only, for room. The level's settings and the waves' tables are the
; first copy's alone (@mv_*).
;
; From level CFG_MV_FIRST each level has a row of CFG_MOVES (config.asm);
; the levels before it share row 0, the old game's:
;   alt     a second movement: each bomb takes it instead of its own,
;           at random, half the time (the second bomb only if it is the
;           bob, the wave or the hunter). MV_NONE: always its own.
;   amp     the wave's height (MOVE_WAVE, and the zigzag's): 16 is the
;           old wave's.
;   speed   how far along the wave each 1/50 second goes (the old: 2).
;   flags   MV_RANDOM: a waving bomb starts anywhere on its wave.
;
; Up or down, no bomb moves more than a pixel a 1/50 second, so its
; colour keeps the one-pixel path (wheel_colours); a wave too steep for
; that is followed a pixel at a time, which flattens it into straight
; runs (the zigzag is just that). None turns back to the right: the
; colour path only goes left.
;==============================================================================

    IFNDEF B2_PASS
; The level's (mv_level, in this order: one copy from its row). mv_amp
; starts at 0, so the first level makes the tables.
mv_alt:         db MV_NONE      ; the second movement, or MV_NONE
mv_amp:         db 0            ; the wave's height
mv_wspd:        db CFG_BOMB_WAVE_SPEED
mv_flags:       db 0
mv_wtop:        db WAVE_TOP_BASE ; a wave's middle stays between these,
mv_wlow:        db WAVE_LOW_BASE ; so its whole height is in the water
        ASSERT mv_flags == mv_alt + 3 && mv_wlow == mv_wtop + 1

; The waves' 128 heights, made by wave_make: the bomb's for this level,
; and the fish's (CFG_FISH_WAVE_AMP), in the free room between the
; run-time buffers and the row table, not on the tape.
MV_WAVE_TAB     equ BSS_LIMIT
fish_wave_tab   equ BSS_LIMIT + 128 ; level.asm's fish_wave reads it
        ASSERT (MV_WAVE_TAB & $FF) == 0 && MV_WAVE_TAB + 256 <= ROW_TABLE, "the waves' tables do not fit at BSS_LIMIT"
        ASSERT WAVE_TOP_BASE == WHEEL_TOP_Y + 16 && WAVE_LOW_BASE == BACK_ROW * 8 - WHEEL_HEIGHT - 16, "row 0's wave is not the old one"


;------------------------------------------------------------------------------
; mv_level - level_style, each level: this level's row. A new wave
; height makes the tables again (about a television frame, once, while
; the level's banner goes up). Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
mv_level:
        ld a,(level_n)
        sub CFG_MV_FIRST - 1    ; 1 for the first level with a row of its own
        jr nc,mv_lrow
        xor a                   ; before it: row 0, the old game's
mv_lrow:
        cp MV_ROWS
        jr c,mv_lin
        ld a,MV_ROWS - 1        ; past the table: its last row again
mv_lin:
        add a,a
        add a,a                 ; 4 bytes a row
        ld e,a
        ld d,0
        ld hl,mv_table
        add hl,de
        ld a,(mv_amp)
        ld de,mv_alt
        ld bc,4
        ldir
        ld hl,mv_amp
        cp (hl)
        ret z                   ; the same wave: its tables are made
        ld c,(hl)
        ld a,c
        add a,WHEEL_TOP_Y
        ld (mv_wtop),a
        ld a,BACK_ROW * 8 - WHEEL_HEIGHT
        sub c
        ld (mv_wlow),a
        ld hl,MV_WAVE_TAB
        call wave_make
        ld c,CFG_FISH_WAVE_AMP
        ld hl,fish_wave_tab
        ; fall through

;------------------------------------------------------------------------------
; wave_make - HL = a table of 128 (its low byte 0 or 128), C = the height
; (1 to 48): a whole sine, rounded to the nearest pixel exactly as
; data.asm's WAVE_TABLE makes Atlantis's, from its first 33 sines
; (wave_q). The rest are those mirrored, then negated.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wave_make:
        push hl
        ld de,wave_q
wm_q:   ld a,(de)               ; this sine times the height, plus 63,
        push de
        push hl
        ld e,a
        ld d,0
        ld hl,63
        ld b,c
wm_mul: add hl,de
        djnz wm_mul
        ld de,127
        ld b,255
wm_div: inc b                   ; over 127
        or a
        sbc hl,de
        jr nc,wm_div
        pop hl
        ld (hl),b
        inc l
        pop de
        inc de
        ld a,l
        and 63
        cp 33
        jr nz,wm_q
        ld d,h                  ; 33 to 63 are 31 down to 1
        ld e,l
        dec e
        dec e
wm_mirror:
        ld a,(de)
        ld (hl),a
        inc l
        dec e
        ld a,l
        and 63
        jr nz,wm_mirror
        pop de                  ; 64 to 127 are 0 to 63 negated
wm_neg: ld a,(de)
        neg
        ld (hl),a
        inc l
        inc e
        ld a,l
        and 127
        jr nz,wm_neg
        ret

; The first quarter and a sine, scaled to 127 (data.asm's WAVE_TABLE).
wave_q: db 0, 6, 12, 19, 25, 31, 37, 43, 49, 54, 60, 65, 71, 76, 81, 85
        db 90, 94, 98, 102, 106, 109, 112, 115, 117, 120, 122, 123, 125, 126, 126, 127
        db 127

        MACRO MV_ROW alt?, amp?, speed?, flags?
        ASSERT alt? == MV_NONE || alt? <= MOVE_ZING, "CFG_MOVES: alt is a movement, or MV_NONE"
        ASSERT amp? >= 4 && amp? <= 48, "CFG_MOVES: a wave's height is 4 to 48"
        ASSERT speed? >= 1 && speed? <= 16
        ASSERT flags? >= 0 && flags? <= MV_RANDOM
        db alt?, amp?, speed?, flags?
        ENDM
        COLD                    ; read once a level
mv_table:
        MV_ROW  MV_NONE, 16, CFG_BOMB_WAVE_SPEED, 0     ; row 0: the old game
        CFG_MOVES
MV_ROWS         equ ($ - mv_table) / 4
        HOT
        ASSERT CFG_BOMB_WAVE_AMP == 16 && CFG_MV_FIRST >= 1 && CFG_MV_FIRST <= 255
    ENDIF

;------------------------------------------------------------------------------
; mv_pick - wheel_type, a new bomb: the level's second movement instead
; of its own, half the time (this bomb's shift register). A hunter that
; had no hunt of its own gets CFG_ALT_HUNT. With MV_NONE (or, for the
; second bomb, a movement it does not have) the shift register is not
; touched, so the levels before CFG_MV_FIRST go as before.
; Corrupts: AF, HL
;------------------------------------------------------------------------------
mv_pick:
        ld a,(@mv_alt)
    IFDEF B2_PASS
        cp MOVE_HOME + 1        ; the bob, the wave or the hunter only
        ret nc
    ELSE
        cp MV_NONE
        ret z
    ENDIF
        call wheel_rng
        rrca
        ret nc                  ; its own, this time
        ld a,(@mv_alt)
        ld (wheel_kind),a
        cp MOVE_HOME
        ret nz
        ld hl,wheel_hunt
        ld a,(hl)
        or a
        ret nz
        ld (hl),CFG_ALT_HUNT
        ret

;------------------------------------------------------------------------------
; mv_wave_new - wheel_wave, a new bomb: the start of its wave (anywhere
; on it with MV_RANDOM), and a middle the level's wave fits round. The
; bomb is still off the right edge, so a middle that moves here was
; never seen. Corrupts: AF
;------------------------------------------------------------------------------
mv_wave_new:
        ld a,(@mv_flags)
        and MV_RANDOM
        jr z,mv_wstart
        call wheel_rng
mv_wstart:
        ld (wheel_wave_p),a
        push hl
        ld hl,@mv_wtop
        ld a,(wheel_base)
        cp (hl)
        jr nc,mv_mtop
        ld a,(hl)
mv_mtop:
        inc hl                  ; mv_wlow
        cp (hl)
        jr c,mv_mlow
        ld a,(hl)
mv_mlow:
        ld (wheel_base),a
        pop hl
        ret

    IFNDEF B2_PASS
;------------------------------------------------------------------------------
; wheel_ss - update_wheel's MOVE_STOP: stop-start. In time with the
; clock it dashes for CFG_SS_BEAT 1/50 seconds, every 1/50 second's
; pixel doubled when the level's haste is above 0 (the drift's own
; two-pixel step, its fraction made to carry, so the colour keeps its
; path), then stops dead, bob and spin and all, for as long. A stop
; costs almost nothing. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_ss:
        ld a,(wheel_phase)
        or a
        jp z,wheel_drift.waiting
        ld a,(frame_count)
        and CFG_SS_BEAT
        ret nz                  ; stopped
        dec a
        ld (wheel_frac),a       ; 255: the haste carries
        jp wheel_drift

;------------------------------------------------------------------------------
; wheel_zing - update_wheel's MOVE_ZING: the zinger. It cruises on the
; bob until it is CFG_ZING_DIST pixels right of the diver, then darts
; to his depth a pixel each 1/50 second (MOVE_HOME's hunt, at nearly
; every step), until it has passed him.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_zing:
        ld a,(wheel_phase)
        or a
        jp z,wheel_drift.waiting
        ld a,(wheel_x + 1)
        or a
        jp nz,wheel_drift       ; off the right edge: cruising
        ld a,(diver_x)
        ld b,a
        ld a,(wheel_x)
        sub b
        jp c,wheel_home         ; passed him: wheel_home lets go
        cp CFG_ZING_DIST
        jp nc,wheel_drift       ; still far: cruising
        ld a,255
        ld (wheel_hunt),a       ; dart
        jp wheel_home
    ENDIF
