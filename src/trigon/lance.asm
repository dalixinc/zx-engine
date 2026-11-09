;==============================================================================
; trigon/lance.asm - the Lance laser (LANCEGUN: Trigon with power-ups)
;
; From CFG_LANCE_LEVEL (or level 1 with the testers' switch) fire does
; two things. A tap shoots a torpedo, as ever. Held, it charges the
; Lance: the gauge on row 1 (a lance over a bar, column LANCE_COL)
; fills in eighths, and letting go after CFG_LANCE_MIN 1/50 seconds
; throws a beam from his gun the way he faces, a byte longer for each
; CFG_LANCE_FULL / 32 of charge, up to the whole width. It stays still
; for CFG_LANCE_TIME 1/50 seconds and blows up what it touches: the
; bomb, the second bomb, the fish, a silo's missile (not a power-up),
; each for CFG_PTS_LANCE, shown as a power's points are (pop_add).
; Then it rests CFG_LANCE_REST before the next.
;
; How it costs nothing before then: main_loop's two "CALL NZ,
; torpedo_fire" (fish_mv.lf1, fish_mv2.lf2) become "CALL NZ,lance_input"
; only when it is his (lance_level), and plain CALLs only from a press
; until the beam and its rest are over (lance_calls).
; Measured (level 3, the diver on the seabed, held and let go every 2
; seconds, the press's torpedo left out): 17 late steps in 512 at 50
; against 9, two bombs 197 against 161, no frame lost; at 25 none late
; (29 scanlines spare, two bombs 14).
;
; The beam is two pixel rows of ink at the gun's height, whole bytes,
; both in one row of cells, and the sea is empty pixels, so it needs no
; photograph: it is drawn once and wiped once (zeros), at the HUD's
; place in the step (lance_hud), when no sprite is on the screen, so the
; sprites photograph it as water. Its colour (CFG_LANCE_INK) goes on
; the cells it crosses that are the water's, and comes off the ones
; still its own when it goes (lance_tint), so the bombs', the fish's and
; the banner's colours are left alone; a sprite crossing it meanwhile
; takes its colour, for the moment it is up.
; The burst is the one other thing drawn there: a burst that
; photographed the beam has those bytes zeroed in its photograph when
; the beam is wiped (lance_unphoto), or its end would put the beam back.
; It is kept out of the seabed's rows and the score's.
;==============================================================================

    IFDEF LANCEGUN

LANCE_COL       equ LIVES_COL - 5   ; row 1: left of the special bomb's cell
LANCE_SCREEN    equ SCREEN + LIVES_ROW * 32 + LANCE_COL
LANCE_STEP      equ CFG_LANCE_FULL / 32     ; charge for each byte of beam
LANCE_EIGHTH    equ CFG_LANCE_FULL / 8      ; charge for each eighth of the gauge
HUD_LANCE       equ 3                       ; hud_dirty: the gauge or the beam
LANCE_TOP       equ 2 * 8                   ; below the score line
LANCE_LOW       equ BACK_ROW * 8 - 2        ; its top row, above the seabed
        ASSERT LANCE_COL >= HUD_LEN, "the Lance's cell would cover the score line"
        ASSERT CFG_LANCE_FULL % 32 == 0 && CFG_LANCE_FULL >= 32 && CFG_LANCE_FULL <= 255
        ASSERT CFG_LANCE_MIN >= 1 && CFG_LANCE_MIN < CFG_LANCE_FULL
        ASSERT CFG_LANCE_TIME >= 2 && CFG_PTS_LANCE <= 99
        ASSERT ({fish_mv.lf1} & $FF) == $C4 && {fish_mv.lf1 + 1} == torpedo_fire, ".lf1 is not CALL NZ,torpedo_fire"
        ASSERT ({fish_mv2.lf2} & $FF) == $C4 && {fish_mv2.lf2 + 1} == torpedo_fire, ".lf2 is not CALL NZ,torpedo_fire"

ln_on:          db 0            ; 1 = his (the calls point here)
ln_charge:      db 0            ; 1 = fire is held (since ln_start)
ln_shown:       db 0            ; the gauge's eighths, 0-8
ln_clock:       db 0            ; 1/50 seconds of beam (ln_beam) or rest left
ln_beam:        db 0            ; 1 = the beam is out
ln_draw:        db 0            ; 1 = draw it at the next lance_hud
ln_wipe:        db 0            ; 1 = wipe it at the next lance_hud
ln_cell:        db 0            ; 1 = draw the gauge at the next lance_hud
ln_y:           db 0            ; the beam's top pixel row
ln_c0:          db 0            ; its first column
ln_n:           db 0            ; its bytes (ln_c0 + 1: lance_unphoto)
ln_a0:          dw 0            ; screen byte of its first column, top row
ln_x0:          dw 0            ; its first pixel column
ln_x1:          dw 0            ; its last
ln_start:       dw 0            ; frame_count when fire went down
ln_at:          dw 0            ; the colour byte of its first cell
LANCE_ATTR      equ CFG_LANCE_INK | SEA
        ASSERT ln_n == ln_c0 + 1

;------------------------------------------------------------------------------
; lance_level - level_style (through tb_level), each level and a new game:
; is the Lance his now? From CFG_LANCE_LEVEL, or with the testers'
; switch. Corrupts: AF, HL
;------------------------------------------------------------------------------
lance_level:
        ld a,(cheat_on)
        or a
        jr nz,.his
        ld a,(level_n)
        cp CFG_LANCE_LEVEL
        jr nc,.his
        ; not yet (a new game): the plain fire, an empty cell
        xor a
        ld (ln_on),a
        ld a,$C4                ; CALL NZ,torpedo_fire
        ld hl,torpedo_fire
        jr .calls
.his:   ld a,(ln_on)
        or a
        ret nz                  ; his already: a charge goes on
        inc a
        ld (ln_on),a
        ld a,$C4                ; CALL NZ,lance_input: when fire is down
        ld hl,lance_input
.calls: ld (fish_mv.lf1),a
        ld (fish_mv.lf1 + 1),hl
        ld (fish_mv2.lf2),a
        ld (fish_mv2.lf2 + 1),hl
        ; fall through: nothing charged, nothing out
lance_reset:
        ld hl,ln_charge
        ld b,ln_cell - ln_charge
.clr:   ld (hl),0
        inc hl
        djnz .clr
        ; fall through
lance_dirty:
        ld a,1
        ld (ln_cell),a
        ld hl,hud_dirty
        set HUD_LANCE,(hl)
        ret

    IFDEF TEASER
        COLD                    ; once a level
; level_up, after the banner: on reaching CFG_LANCE_LEVEL, the message
; (teaser, score.asm, hands over to lance_teaser). Not with the testers'
; switch, which gave it at level 1. Corrupts: AF
lance_news:
        ld a,(cheat_on)
        or a
        ret nz
        ld a,(level_n)
        cp CFG_LANCE_LEVEL
        ret nz
        ld (teaser_due),a       ; not 0
        ret

; The message's two lines (teaser, score.asm), under "WELL DONE, YOU
; REACHED LEVEL n."
str_lance_1:    db "LANCE LASER:",0
LANCE_1_LEN     equ $ - 1 - str_lance_1
str_lance_2:    db "HOLD FIRE, LET GO",0
LANCE_2_LEN     equ $ - 1 - str_lance_2
        HOT
    ENDIF

;------------------------------------------------------------------------------
; lance_input - fish_mv's and fish_mv2's fire call once the Lance is his.
; It is CALL NZ (only while fire is down) until fire goes down, then
; CALL (every 1/50 second, Z = fire up) until fire is up again and the
; beam and its rest are over (lance_calls): so a Lance at rest costs
; the step nothing. The charge is frame_count since the press, so a held
; fire costs about 85 T-states a 1/50 second, as torpedo_fire's own
; test does without the Lance; the gauge is looked at every 8th.
; Corrupts: AF, BC, DE, HL (and what torpedo_fire and the hits do)
;------------------------------------------------------------------------------
lance_input:
        jr nz,.down
        ld a,(ln_charge)
        or a
        jr nz,.release
.clock: ld a,(ln_clock)
        or a
        jr z,.idle
        dec a
        ld (ln_clock),a
        ld b,a
        ld a,(ln_beam)
        or a
        ret z                   ; resting
        ld a,b
        or a
        jp nz,lance_hits
        ; the beam's time is up: wiped at the next lance_hud, then a rest
        ld (ln_beam),a
        ld a,CFG_LANCE_REST
        ld (ln_clock),a
        ld a,1
        ld (ln_wipe),a
        ld hl,hud_dirty
        set HUD_LANCE,(hl)
        ret
.idle:  ld a,(ln_charge)
        or a
        ret nz                  ; held
        ld a,$C4                ; all over: called only on fire again
        jr lance_calls

.down:  ld a,(ln_charge)
        or a
        jr nz,.held
        inc a
        ld (ln_charge),a        ; the press: a tap's torpedo, at once
        ld hl,(frame_count)
        ld (ln_start),hl
        ld a,$CD                ; and every 1/50 second until it is over
        call lance_calls
        call torpedo_fire
        jr .clock
.held:  ld a,(frame_count)
        and 6
        jr nz,.clock            ; the gauge: two 1/50 seconds in 8
        ld a,(step_ticks)
        dec a
        jr nz,.gauge            ; at 25 there is time
        ld a,(slow_phase)
        or a
        jr nz,.clock            ; at 50, not after the heaviest step's rotate
.gauge: call lance_held
        ld b,-1
.e:     inc b
        sub LANCE_EIGHTH
        jr nc,.e
        ld a,b
        ld hl,ln_shown
        cp (hl)
        jr z,.clock
        ld (hl),a
        call lance_dirty
        jr .clock

.release:
        xor a
        ld (ln_charge),a
        call lance_held
        ld b,a                  ; how long it was held
        xor a
        ld (ln_shown),a
        call lance_dirty        ; the gauge empties (keeps B)
        ld a,b
        cp CFG_LANCE_MIN
        jp c,.clock             ; a tap
        ld a,(ln_clock)
        or a
        jp nz,.clock            ; one out, or resting: nothing
        ld a,(ln_wipe)
        or a
        ret nz                  ; the last one still to wipe (next step)
        ld a,b
        jr lance_fire

; A = the opcode for both fire calls: $CD CALL, $C4 CALL NZ.
; Corrupts: nothing else
lance_calls:
    IFDEF MEAS_LANCE
        ld a,$CD                ; measuring: its script holds fire itself
    ENDIF
        ld (fish_mv.lf1),a
        ld (fish_mv2.lf2),a
        ret

; A = 1/50 seconds since fire went down, at most CFG_LANCE_FULL.
; Corrupts: F, DE, HL
lance_held:
        ld hl,(frame_count)
        ld de,(ln_start)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.full
        ld a,l
        cp CFG_LANCE_FULL
        ret c
.full:  ld a,CFG_LANCE_FULL
        ret

;------------------------------------------------------------------------------
; lance_fire - A = the charge: the beam's place, then drawn at the next
; lance_hud. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
lance_fire:
        ld b,0                  ; bytes: a byte for each LANCE_STEP
.len:   sub LANCE_STEP
        jr c,.lenok
        inc b
        jr .len
.lenok: ld a,b
        or a
        ret z
        ld c,a                  ; C = its length in bytes
        ; The row: the gun's, out of the score's and the seabed's rows.
        ld a,(diver_y)
        add a,TORP_MOUTH_Y
        cp LANCE_TOP
        jr nc,.low
        ld a,LANCE_TOP
.low:   cp LANCE_LOW + 1
        jr c,.y
        ld a,LANCE_LOW
.y:     and $FE                 ; even: both rows in one row of cells
        ld (ln_y),a
        ; The columns, from the gun out.
        ld a,(diver_facing)
        or a                    ; FACE_RIGHT is 0
        jr nz,.left
        ld a,(diver_x)
        add a,DIVER_WIDTH + 7   ; the first whole byte past his nose
        ret c                   ; past the right edge: no room
        rrca
        rrca
        rrca
        and 31
        ld b,a                  ; B = first column
        ld a,32
        sub b                   ; room to the edge
        cp c
        jr nc,.put
        ld c,a
        jr .put
.left:  ld a,(diver_x)
        rrca
        rrca
        rrca
        and 31                  ; his first column
        or a
        ret z                   ; at the left edge: no room
        cp c
        jr nc,.lroom
        ld c,a                  ; as far as the edge
.lroom: sub c
        ld b,a                  ; first column
.put:   ld a,b
        ld (ln_c0),a
        ld a,c
        ld (ln_n),a
        ; Pixel columns for the hit tests.
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ln_x0),hl
        ld a,b
        add a,c
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        dec hl
        ld (ln_x1),hl
        ; The screen byte of its top row, from the row table (the row
        ; below is 256 on: ln_y is even, so both are in one cell's row).
        ld a,(ln_y)
        ld l,a
        ld h,0
        add hl,hl
        ld de,ROW_TABLE
        add hl,de
        ld a,(hl)
        add a,b                 ; a row's 32 bytes share their high byte
        ld e,a
        inc hl
        ld d,(hl)
        ld (ln_a0),de
        ld a,(ln_y)             ; the colour bytes' row: (y / 8) * 32
        and $F8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld a,l
        add a,b                 ; a row of 32 starts on a multiple of 32
        ld l,a
        ld de,ATTRS
        add hl,de
        ld (ln_at),hl
        ld a,1
        ld (ln_beam),a
        ld (ln_draw),a
        ld a,CFG_LANCE_TIME
        ld (ln_clock),a
        ld hl,hud_dirty
        set HUD_LANCE,(hl)
    IFNDEF NO_SOUND
        ld hl,snd_lance         ; the pew, over whatever was playing
        jp snd_tune_start
    ELSE
        ret
    ENDIF

;------------------------------------------------------------------------------
; lance_hits - each 1/50 second the beam is out: what it touches goes up,
; for CFG_PTS_LANCE each. One burst at a time, as for shove: a later one
; moves it, and a fish while a burst is up or the bomb is there flashes.
; Not before it is drawn: a burst would photograph the water under it,
; and put that back over the beam when it ended.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
lance_hits:
        ld a,(ln_draw)
        or a
        ret nz
        ; At 50, not on the step that rotated the slow buffer (slow_phase
        ; is 1 after it), the heaviest: every other 1/50 second is enough,
        ; as nothing moves 2 rows past a 2-row beam in one.
        ld a,(step_ticks)
        dec a
        jr nz,.go
        ld a,(slow_phase)
        or a
        ret nz
.go:
        ld a,(wheel_phase)
        or a
        jr z,.b2
        ld hl,(wheel_x)
        ld a,(wheel_y)
        ld bc,(WHEEL_HEIGHT << 8) | WHEEL_WIDTH
        call lance_box
        jr nc,.b2
        call wheel_remove
        call boom_at_bomb
        call lance_pts
.b2:
    IFDEF TWO_BOMBS
        ld a,(b2.wheel_phase)
        or a
        jr z,.fish
        ld hl,(b2.wheel_x)
        ld a,(b2.wheel_y)
        ld bc,(WHEEL_HEIGHT << 8) | WHEEL_WIDTH
        call lance_box
        jr nc,.fish
        call b2.wheel_remove
        call tb_boom
        call lance_pts
    ENDIF
.fish:  ld a,(fish_busy)
        or a
        jr nz,.msl
        ld a,(fish_x)
        ld l,a
        ld h,0
        ld a,(fish_y)
        ld bc,(FISH_HEIGHT << 8) | FISH_WIDTH
        call lance_box
        jr nc,.msl
        call lance_pts
        ld a,(boom_t)
        ld hl,wheel_phase
        or (hl)
        jr nz,.flash
        call boom_at_fish
        jr .msl
.flash: call fish_flash_begin
.msl:   ld a,(msl_phase)
        or a
        ret z
        ld a,(msl_kind)
        or a
        ret nz                  ; a power-up: not his to burn
        ld a,(msl_x)
        ld l,a
        ld h,0
        ld a,(msl_y)
        ld bc,(MISSILE_HEIGHT << 8) | MISSILE_WIDTH
        call lance_box
        ret nc
        call boom_at_missile
        call lance_pts
        jp missile_gone

lance_pts:
        ld a,CFG_PTS_LANCE
        jp pop_add

; lance_box - HL = a thing's left pixel (may be off the left), A = its
; top row, B = its height, C = its width. Out: carry = the beam touches
; it. Corrupts: AF, DE, HL
lance_box:
        ld d,a
        ld a,(ln_y)
        inc a                   ; the beam's bottom row
        sub d
        jr c,.no                ; it starts below the beam
        cp b
        jr z,.rows              ; its bottom row is the beam's top
        jr nc,.no               ; it ends above the beam
.rows:  ex de,hl                ; DE = its left
        ld hl,(ln_x1)
        or a
        sbc hl,de               ; the beam's right - its left: >= 0
        bit 7,h
        jr nz,.no
        ld l,c
        ld h,0
        add hl,de               ; its right + 1
        ld de,(ln_x0)
        or a
        sbc hl,de               ; > 0
        jr z,.no
        bit 7,h
        jr nz,.no
        scf
        ret
.no:    or a
        ret

;------------------------------------------------------------------------------
; lance_hud - hud_draw, while hud_dirty's HUD_LANCE is set: no sprite is
; on the screen. The gauge, a wipe, a draw. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
lance_hud:
        ; At 50, never on the heaviest step (slow_phase 0 here, before
        ; the copy): the next one, with HUD_LANCE still set.
        ld a,(step_ticks)
        dec a
        jr nz,.go
        ld a,(slow_phase)
        or a
        ret z
.go:    res HUD_LANCE,(hl)
        ld a,(ln_cell)
        or a
        call nz,lance_cell_draw
        ld a,(ln_wipe)
        or a
        call nz,lance_wipe
        ld a,(ln_draw)
        or a
        ret z
        xor a
        ld (ln_draw),a
        ld a,$FF
        call lance_rows
        ld de,(LANCE_ATTR << 8) | WATER_ATTR
        jr lance_tint

lance_wipe:
        xor a
        ld (ln_wipe),a
        ld de,(WATER_ATTR << 8) | LANCE_ATTR
        call lance_tint
        call lance_unphoto
        xor a
        ; fall through
; A = the byte for both rows of the beam. Corrupts: AF, BC, DE, HL
lance_rows:
        ld c,a
        ld hl,(ln_a0)
        call .one
        ld hl,(ln_a0)
        inc h                   ; the row below, in the same cell
.one:   ld a,(ln_n)
        ld b,a
        ld a,c
        ; fall through
; HL = the first screen byte, B = 1 to 32 bytes, A = what goes in them.
; 24 T-states a byte: a whole-width beam is about 7 scanlines, on the
; step it is drawn and the step it is wiped only. Corrupts: B, HL
lance_fill:
        ld (hl),a
        inc l
        djnz lance_fill
        ret

; The beam's cells that are colour E become colour D.
; Corrupts: AF, B, HL
lance_tint:
        ld hl,(ln_at)
        ld a,(ln_n)
        ld b,a
.cell:  ld a,(hl)
        cp e
        jr nz,.next
        ld (hl),d
.next:  inc l
        djnz .cell
        ret
        ASSERT LANCE_ATTR != WATER_ATTR

; A burst's photograph (boom_bg, 2 bytes x BOOM_ROWS from boom_col,
; boom_y) holds the beam's bytes if it was taken while the beam was up:
; those go back to water there too. Corrupts: AF, DE, HL
lance_unphoto:
        ld a,(boom_got)
        or a
        ret z
        ld a,(ln_y)
        call .row
        ld a,(ln_y)
        inc a
.row:   ld hl,boom_y
        sub (hl)
        ret c
        cp BOOM_ROWS
        ret nc
        add a,a
        ld e,a
        ld d,0
        ld hl,boom_bg
        add hl,de
        ld a,(boom_col)
        call .col
        inc hl
        ld a,(boom_col)
        inc a
.col:   push hl
        ld hl,ln_c0
        sub (hl)                ; its column - the beam's first
        inc hl
        cp (hl)                 ; inside if below ln_n (a wrap is not)
        pop hl
        ret nc
        ld (hl),0
        ret

; Row 1's cell: the lance over the gauge, or water before it is his.
; Also from lives_draw (hit.asm), which redraws row 1's cells.
; Corrupts: AF, B, DE, HL
lance_cell_draw:
        xor a
        ld (ln_cell),a
        ld hl,LANCE_SCREEN
        ld a,(ln_on)
        or a
        jr nz,.his
        ld b,8
.water: ld (hl),a
        inc h
        djnz .water
        ret
.his:   ld de,lance_pic
        ld b,6
.pic:   ld a,(de)
        ld (hl),a
        inc de
        inc h
        djnz .pic
        ld a,(ln_shown)         ; eighths: that many pixels from the left
        or a
        jr z,.got
        ld b,a
        xor a
.fill:  scf
        rra
        djnz .fill
.got:   ld (hl),a               ; the bar's two rows
        inc h
        or a
        jr nz,.bar
        ld a,%10000001          ; empty: its two ends
.bar:   ld (hl),a
        ret

    IFNDEF NO_SOUND
snd_lance:
        db 1, 1                 ; the lead-in, never heard (as snd_laser's)
        CFG_LANCE_PEW
        db 0
    ENDIF

lance_pic:      db %00000000
                db %00000100
                db %11111110
                db %00000100
                db %00000000
                db %00000000

    ENDIF
