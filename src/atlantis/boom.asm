;==============================================================================
; boom.asm - a short explosion, drawn in place of the bomb or the fish
;
; Four pictures, 16 wide by 12 tall, one copy each. x is snapped to the
; nearest byte, so nothing is pre-shifted. The burst does not scroll.
;
; It is the bottom layer. main_loop's call to stats_prepare, straight
; after the sprite restores, is patched to boom_step while a burst is
; up. Every sprite is off the screen then, so the burst's photograph is
; only the background, and the sprites drawn after it photograph the
; burst. Restores run in the reverse order, so each one puts back what
; was really under it. A burst drawn among the sprites photographed
; the diver; when a hit moved him to the left edge, putting that
; photograph back left a piece of him behind.
;
; It stays between rows 2 and 20. Row 0 is the stat digits and row 1
; the hearts, which are rewritten under it, and the seabed rows are
; copied over it.
;
; Pixels are ink bits. On open water that ink is bright white, the same
; as the sea, so the burst needs no attribute write.
;==============================================================================

BOOM_ROWS       equ 12
BOOM_HOLD       equ 8           ; 4 shapes, 2 draws each

boom_t:         db 0            ; 0 = nothing to draw
boom_left:      db 0            ; draws still to show
boom_got:       db 0            ; 1 = boom_bg holds the screen under it
boom_fish:      db 0            ; 1 = the fish draw was turned off for a burst
fish_busy:      db 0            ; 1 = flashing, waiting, or hidden for a burst
fish_left:      db 0            ; attribute flashes still to show
fish_tint:      db 0            ; 0 = yellow, 1 = red
fish_wait:      db 0            ; steps until the next fish swims in
fish_acol:      db 0
fish_arow:      db 0
FISH_FLASHES    equ 4
FISH_GAP        equ 20          ; game steps, then a new fish from the right
FISH_YEL        equ YELLOW | SEA
FISH_RED        equ RED | SEA
; Where the fish's draw is set (the burst, the flash and the wait below):
; main_loop's call, or in Trigon the jump at the end of the paint that
; runs before it (src/trigon/theme.asm, tp_real).
    IFDEF TRIGON
FISH_DRAW_TO    equ tp_real
    ELSE
FISH_DRAW_TO    equ fish_draw_call + 1
    ENDIF
boom_col:       db 0            ; screen column, 0..30, of the next draw
boom_y:         db 0
boom_addr:      dw 0            ; screen byte of the drawn burst: the restore's place
boom_new:       db 0            ; 1 = armed at a new place since the last draw
boom_shown:     db 0            ; the shape on the screen now
BOOM_TOP        equ 2 * 8       ; below the digits and the hearts
BOOM_LOW        equ (BACK_ROW * 8 - BOOM_ROWS) & $F8 ; above the seabed copy
; boom_bg: in bss.asm (zeroed at start-up, not on the tape)

        COLD
;------------------------------------------------------------------------------
; boom_reset - no burst, and the fish draws itself again
;------------------------------------------------------------------------------
boom_reset:
        xor a
        ld (boom_t),a
        ld (boom_got),a
        ld (boom_new),a
        ld (boom_fish),a
        ld (fish_busy),a
        ld (fish_left),a
        ld (fish_wait),a
        ld hl,fish_draw_fast
        ld (FISH_DRAW_TO),hl
        ld hl,fish_restore_fast
        ld (fish_rest_call+1),hl
        ld hl,stats_prepare
        ld (boom_hook+1),hl
    IFDEF POWERUPS
        ld (pop_pts),a          ; A = 0: no points waiting to show
    ENDIF
        call fish_kind_pick
        jp fish_unhold

        HOT

; The patched call lands here while a fish burst is showing. The restore
; this frame already put the fish's photograph back. Drop it so the next
; frames do not copy those bytes again.
fish_draw_skip:
        ld iy,fish_bg
        ld (iy+BG_VALID),0
        ret

fish_move_skip:
        ret

; Stop the two movement calls. The heavy frame does not come here.
fish_hold:
        ld hl,fish_move_skip
        ld (fish_mv+1),hl
        ld (fish_mv2+1),hl
        ret

fish_unhold:
        ld hl,(fish_mover)      ; the level's: update_fish or fish_wave
    IFDEF FISH_LEAVES
        ld (fish_once.real + 1),hl
        ld hl,fish_once         ; Trigon: it, then has it crossed? (twobomb.asm)
    ENDIF
        ld (fish_mv+1),hl
        ld (fish_mv2+1),hl
        ret

; The fish stays where it was drawn. Four attribute passes, yellow then
; red, then the fish is gone. It is still restored and drawn every step
; in its usual places, held still. Leaving it on the screen undrawn and
; putting its photograph back at the end did that out of turn: the
; photograph held the diver as he was when the fish touched him, and a
; hit had since moved him to the left edge.
fish_flash_begin:
    IFNDEF NO_SOUND
        call snd_fish_start
    ENDIF
        ld a,(fish_x)
        rrca
        rrca
        rrca
        and 31
        ld (fish_acol),a
        ld a,(fish_y)           ; a 9-row fish always covers two rows
        rrca
        rrca
        rrca
        and 31
        ld (fish_arow),a
        xor a
        ld (fish_tint),a
        ld a,FISH_FLASHES
        ld (fish_left),a
        ld a,1
        ld (fish_busy),a
        ld hl,fish_flash_draw
        ld (FISH_DRAW_TO),hl
        jp fish_hold

; In the fish's draw place. Its restore has just run.
fish_flash_draw:
        ld a,(fish_left)
        or a
        jr z,.gone
        call fish_draw_fast
        ld a,(fish_tint)
        or a
        ld a,FISH_YEL
        jr z,.ink
        ld a,FISH_RED
.ink:   call fish_paint
        ld a,(fish_tint)
        xor 1
        ld (fish_tint),a
        ld hl,fish_left
        dec (hl)
        ret
.gone:  ld iy,fish_bg          ; the restore took the fish away: not drawn again
        ld (iy+BG_VALID),0
        ld a,WATER_ATTR
        call fish_paint
        jp fish_begin_wait

; A = attribute. Three columns, two rows, the fish's footprint.
fish_paint:
        push af
        ld a,(fish_arow)
        ld b,a
        ld a,(fish_acol)
        ld c,a
        call attr_addr
        pop af
        ld c,a
        ld b,2
.row:   push bc
        push hl
        ld b,3
.col:   ld (hl),c
        inc l
        djnz .col
        pop hl
        ld de,32
        add hl,de
        pop bc
        djnz .row
        ret

; The fish is already off the screen. After FISH_GAP steps a new one
; swims in from the right, which is the way it crosses the water.
fish_begin_wait:
        ld a,FISH_GAP
        ld (fish_wait),a
        ld a,1
        ld (fish_busy),a
        ld hl,fish_wait_step
        ld (FISH_DRAW_TO),hl
        jp fish_hold

fish_wait_step:
    IFDEF TWO_BOMBS
        ld a,(b2.wheel_phase)
        or a
        ret nz                  ; the second bomb has the fish's place
    ENDIF
        ld hl,fish_wait
        dec (hl)
        ret nz
    IFDEF TWO_BOMBS
        call tb_launch          ; two bombs this wave, not a fish?
        jr nc,.fish
        ld a,FISH_GAP
        ld (fish_wait),a        ; then a wait again, once it has gone
        ret
.fish:
    ENDIF
        ld a,FISH_MAX_X
        ld (fish_x),a
        ld a,FACE_LEFT
        ld (fish_facing),a
        ld a,FISH_SWIM_Y        ; at its own depth, whatever the last did:
        ld (fish_wave.in + 1),a ; a wave's middle (suction moves it), and
        call fish_set_y         ; a straight fish's height and hit tests
        xor a
        ld (fish_busy),a
        ld (fish_wave_p),a      ; a wave starts again at the middle
        ld hl,fish_draw_fast
        ld (FISH_DRAW_TO),hl
        call fish_kind_pick
        jp fish_unhold

;------------------------------------------------------------------------------
; fish_kind_pick - which fish this one is: from CFG_PIRANHA_LEVEL the
; piranha one time in four, else (and always before it) the round one. Called when a fish appears (a new game, and each
; new fish after one has gone), never while one swims, so the frame does
; not pay for it: it patches the draw's picture table (fish_draw_fast.img),
; and the draw reads the same number of bytes for either. A piranha
; scores twice the level's fish points (torpedo_fish). Its own shift
; register, not wheel_rng: the soak counts on that one's order.
; Without TWO_FISH (the soak, and builds with the stat line) every fish
; is the piranha. Corrupts: AF, HL
;------------------------------------------------------------------------------
fish_kind_pick:
    IFDEF TWO_FISH
        ld a,(fish_seed)
        srl a                   ; the same Galois step as wheel_rng
        jr nc,.keep
        xor $B8
.keep:  ld (fish_seed),a
        and 3                   ; 0: a piranha, one time in four
        jr nz,.round
        ld a,(level_n)
        ld hl,pw_piranha_lvl    ; and only from CFG_PIRANHA_LEVEL
        cp (hl)
        jr c,.round
        ld hl,fish_images
        ld a,1
        jr .got
.round: ld hl,rfish_images
        xor a
.got:   ld (fish_draw_fast.img + 1),hl
        ld (fish_piranha),a
    ENDIF
        ret

    IFDEF TWO_FISH
fish_seed:      db 99           ; not 0: an LFSR at 0 stays there
fish_piranha:   db 1            ; 1 = this fish is the piranha
    ENDIF

;------------------------------------------------------------------------------
; boom_at_bomb - the bomb has just been removed. Burst where it was.
; boom_at_fish - the fish. Hide its draw until the burst ends.
; boom_at_missile - a silo's missile, shot or on the diver.
;------------------------------------------------------------------------------
boom_at_bomb:
    IFNDEF NO_SOUND
        call snd_boom_start
    ENDIF
        call boom_show_fish
        ld hl,(wheel_x)
        ld a,(wheel_y)
        jr boom_arm

; Over the missile's middle. In the hatch, boom_arm lifts it clear of
; the seabed rows.
boom_at_missile:
    IFNDEF NO_SOUND
        call snd_missile_start
    ENDIF
        call boom_show_fish
        ld a,(msl_x)
        ld l,a
        ld h,0
        ld de,(MISSILE_WIDTH - 16) / 2
        add hl,de               ; it can be left of the screen: boom_arm clips
        ld a,(msl_y)
        add a,(MISSILE_HEIGHT - BOOM_ROWS) / 2
        jr boom_arm

; The diver: the burst over his middle. boom_arm keeps it above the
; seabed rows, so on the bottom it shows just above him.
boom_at_diver:
        call boom_show_fish
        ld a,(diver_x)
        add a,(DIVER_WIDTH - 16) / 2
        ld l,a
        ld h,0
        ld a,(diver_y)
        add a,(DIVER_HEIGHT - BOOM_ROWS) / 2
        jr boom_arm

boom_at_fish:
    IFNDEF NO_SOUND
        call snd_fish_start
    ENDIF
        ld a,(boom_fish)
        or a
        jr nz,.arm
        ld a,1
        ld (boom_fish),a
        ld (fish_busy),a
        ld hl,fish_draw_skip
        ld (FISH_DRAW_TO),hl
        call fish_hold
.arm:   ld a,(fish_x)
        ld l,a
        ld h,0
        ld a,(fish_y)

; In: HL = pixel x (may be off the left), A = pixel y
; This runs while the sprites are on the screen, so it draws nothing and
; puts nothing back. A burst already showing is put back by the next
; boom_step, from where it was drawn, before the new one is painted.
boom_arm:
    IFDEF POWERUPS
        call boom_place
        jr boom_armed

; boom_place - where boom_arm puts it: boom_col and boom_y from HL, A
; (a power's points with no burst use it: pop_here). Corrupts: AF, DE, HL
boom_place:
    ENDIF
        ld (boom_y),a
        ld de,4                 ; nearest byte
        add hl,de
        bit 7,h
        jr z,.xpos
        ld hl,0
.xpos:  ld a,h
        or a
        jr z,.div
        ld a,30
        jr .stcol
.div:   ld a,l
        rrca
        rrca
        rrca
        and 31
        cp 31
        jr c,.stcol
        ld a,30
.stcol: ld (boom_col),a
        ld a,(boom_y)
        add a,4                 ; the nearest character row: it is drawn
        and $F8                 ; cell by cell, with INC H
        cp BOOM_TOP
        jr nc,.low
        ld a,BOOM_TOP
.low:   cp BOOM_LOW + 1
        jr c,.sty
        ld a,BOOM_LOW
.sty:   ld (boom_y),a
    IFDEF POWERUPS
        ret
boom_armed:
    ENDIF
        ld hl,boom_step
        ld (boom_hook+1),hl
        ld a,BOOM_HOLD
        ld (boom_left),a
        ld a,1
        ld (boom_t),a
        ld (boom_new),a
        or a                    ; not a lost life
        ret

boom_show_fish:
        ld a,(boom_fish)
        or a
        ret z
        xor a
        ld (boom_fish),a
        jp fish_begin_wait

;------------------------------------------------------------------------------
; fish_hit - the fish against the diver, bomb away. Costs a life.
; fish_cheap - the same touch while a bomb is showing. Costs a life.
; fish_aside - the bomb already hit him; only the fish dies.
; torpedo_fish - a shot. The fish dies and he does not.
;------------------------------------------------------------------------------
fish_hit:
        ld a,(fish_busy)
        or a
        ret nz
        ld a,(boom_t)
        or a
        ret nz
        call fish_touch
        ret nc
        call boom_at_fish
        jp diver_hurt

; Out: carry set if the diver overlaps the fish. Corrupts AF, B.
; The three FISH_SWIM_Y operands below are the fish's height for the
; hit tests. fish_wave (level.asm) writes its height into them as it
; moves; level_style puts FISH_SWIM_Y back for a straight fish.
fish_touch:
        ld a,(diver_y)
fish_touch_y:
        sub FISH_SWIM_Y
        add a,14                ; -14..8 overlaps the two heights
        cp 23
        ret nc
        ld a,(fish_x)
        ld b,a
        ld a,(diver_x)
        sub b
        add a,23                ; -23..15 overlaps the two widths
        cp 39
        ret

fish_cheap:
        call fish_aside
        ret nc
        jp diver_hurt

; Out: carry set if a fish was flashing. Carry clear if not touching.
fish_aside:
        ld a,(diver_y)
fish_aside_y:
        cp FISH_SWIM_Y + FISH_HEIGHT
        ret nc                  ; he is below the fish; the usual heavy frame
        ld a,(fish_busy)
        or a
        ret nz
        call fish_touch
        ret nc
        call fish_flash_begin
        scf
        ret

torpedo_fish:
        ld a,(fish_busy)
        or a
        ret nz
        ld a,(torp_y)
torpedo_fish_y:
        sub FISH_SWIM_Y
        add a,TORPEDO_HEIGHT - 1
        cp FISH_HEIGHT + TORPEDO_HEIGHT - 1 ; torpedo is 2 rows tall
        ret nc
        ld hl,(torp_x)
        ld a,(fish_x)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld de,15                ; -(FISH_WIDTH-1)
        add hl,de
        ld a,h
        or a
        ret nz
        ld a,l
        cp 22                   ; 15 + TORPEDO_WIDTH
        ret nc
        call torpedo_spent
    IFDEF TWO_FISH
        ld a,(fish_piranha)
        or a
        ld a,(level_pts_fish)
        jr z,.pts
        add a,a                 ; a piranha scores twice (BCD; LEVEL_ROW keeps it under 50)
        daa
.pts:
    ELSE
        ld a,(level_pts_fish)
    ENDIF
        call score_add          ; a shot fish scores; one that bumps him does not
        ld a,(wheel_phase)
        or a
        jp z,boom_at_fish       ; bomb is away: the full burst
        jp fish_flash_begin

;------------------------------------------------------------------------------
; boom_step - main_loop's stats_prepare call while a burst is up. The
; sprites have all been restored, so the screen under them is the burst
; as it was drawn.
;
; Each shape is shown for two steps. The photograph only has to be taken
; when the burst is new or has been moved; a new shape in the same place
; is written over the old one, and a step whose shape has not changed
; does nothing. So it costs on every other step, about 3 scanlines, and
; once at the start and the end. Erasing, photographing and drawing it
; again on every step, through the row table, cost about 10 scanlines a
; step. With the diver on the seabed that made 187 of 512 steps late.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
boom_step:
        call stats_prepare
boom_service:
        ld a,(boom_left)
        or a
        jr z,boom_end
        dec a
        ld (boom_left),a
        ld b,a
        ld a,BOOM_HOLD - 1
        sub b
        srl a                   ; which of the four shapes
        ld c,a
        ld a,(boom_new)
        or a
        jr nz,.fresh
        ld a,(boom_shown)
        cp c
        ret z                   ; the same shape in the same place
        ld a,c
        ld (boom_shown),a
        call boom_shape
        ld hl,(boom_addr)
        jr boom_write           ; the photograph is still the one underneath

.fresh: xor a
        ld (boom_new),a
        ld a,c
        ld (boom_shown),a
        ld a,(boom_got)
        or a
        call nz,boom_restore    ; the last burst, from where it was drawn
    IFDEF POWERUPS
        call boom_photo
        jr boom_photo_done

; boom_photo - boom_addr from boom_col and boom_y, and the screen there
; into boom_bg (boom_got = 1). Corrupts: AF, B, DE, HL
boom_photo:
    ENDIF
        ld a,1
        ld (boom_got),a
        ; The screen byte of the top-left corner. Its row is a whole
        ; character row: H = 010 RR 000, L = rrr CCCCC.
        ld a,(boom_y)
        and $C0
        rrca
        rrca
        rrca
        or $40
        ld h,a
        ld a,(boom_y)
        add a,a
        add a,a                 ; rrr into the top 3 bits
        and $E0
        ld l,a
        ld a,(boom_col)
        or l
        ld l,a
        ld (boom_addr),hl
        ld de,boom_bg
    IFDEF POWERUPS
        jp boom_read            ; the photograph
boom_photo_done:
    ELSE
        call boom_read          ; the photograph
    ENDIF
        call boom_shape
        ld hl,(boom_addr)
        jr boom_write

boom_end:
        ld a,(boom_got)
        or a
        call nz,boom_restore
        xor a
        ld (boom_t),a
        ld (boom_got),a
    IFDEF POWERUPS
        ld a,(pop_pts)
        or a
        jp nz,pop_show          ; a power's points take the burst's place
    ENDIF
        ld hl,stats_prepare
        ld (boom_hook+1),hl
        jp boom_show_fish

; DE = the 24 bytes of shape (boom_shown). Corrupts: AF, DE, HL
boom_shape:
        ld a,(boom_shown)
        ld l,a
        ld h,0
        add hl,hl               ; *2
        add hl,hl               ; *4
        add hl,hl               ; *8
        ld e,l
        ld d,h
        add hl,hl               ; *16
        add hl,de               ; *24
        ld de,boom_shapes
        add hl,de
        ex de,hl
        ret

; Copy boom_bg back onto the screen.
boom_restore:
        ld hl,(boom_addr)
        ld de,boom_bg
        ; fall through

;------------------------------------------------------------------------------
; boom_write - DE = 24 bytes onto the screen at HL (a character row's top)
; boom_read  - the 24 screen bytes at HL into DE
; Two bytes a row, 8 rows down the first cell, then 4 down the next.
; Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
boom_write:
        push hl
        ld b,8
        call .rows
        pop hl
        call boom_next_cell
        ld b,BOOM_ROWS - 8
.rows:  ld a,(de)
        ld (hl),a
        inc de
        inc l
        ld a,(de)
        ld (hl),a
        inc de
        dec l
        inc h
        djnz .rows
        ret

boom_read:
        push hl
        ld b,8
        call .rows
        pop hl
        call boom_next_cell
        ld b,BOOM_ROWS - 8
.rows:  ld a,(hl)
        ld (de),a
        inc de
        inc l
        ld a,(hl)
        ld (de),a
        inc de
        dec l
        inc h
        djnz .rows
        ret

; HL = the same column one character row down.
boom_next_cell:
        ld a,l
        add a,32
        ld l,a
        ret nc
        ld a,h
        add a,8
        ld h,a
        ret

    IFDEF POWERUPS
;------------------------------------------------------------------------------
; A power's points: the pop-up. What a power clears adds up in pop_pts,
; and when the burst ends (boom_end) the total is drawn in its place, in
; 3x5 figures ("+20", "+150"), for CFG_POP_TIME television frames. It is
; the burst's last shape, so it lives as the burst does: drawn and wiped
; at boom_hook, while no sprite is on the screen, from the burst's
; photograph, and a new burst puts that photograph back first. It is
; not part of the burst: boom_t is 0 meanwhile, so nothing waits for it.
; With no burst (suction, or a missile taken away), pop_here arms an
; empty one where it should show. Each step costs only the clock's test.
;------------------------------------------------------------------------------
pop_pts:        db 0            ; binary: points still to show, 0 = none
pop_until:      dw 0            ; frame_count when the pop-up comes down
POP_ROW         equ 3           ; its top pixel row in the burst's 12

; pop_add - A = points (0 to 99, binary) onto the score and the pop-up.
; Corrupts: AF, BC, DE, HL
pop_add:
        ld hl,pop_pts
        ld c,a
        add a,(hl)
        jr nc,.sum
        ld a,255
.sum:   ld (hl),a
        ld a,c
        ld b,-1
.ten:   inc b
        sub 10
        jr nc,.ten
        add a,10
        ld c,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        or c                    ; BCD
        jp score_add

; pop_here - HL = pixel x, A = pixel y: show the points there, unless a
; burst is coming or up (its end shows them). Corrupts: AF, B, DE, HL
pop_here:
        ld b,a
        ld a,(boom_t)
        or a
        ret nz
        ld a,b
        call boom_place
        xor a
        ld (boom_left),a        ; no shapes: boom_step goes to boom_end
        ld hl,boom_step
        ld (boom_hook+1),hl
        ret

; The burst has ended and its photograph is back: draw the points.
; In: A = pop_pts. Corrupts: AF, BC, DE, HL
pop_show:
        ld c,a
        xor a
        ld (pop_pts),a
        push bc
        call boom_photo
        pop bc
        ld a,c                  ; hundreds, tens, units
        ld d,-1
.hun:   inc d
        sub 100
        jr nc,.hun
        add a,100
        ld e,-1
.ten:   inc e
        sub 10
        jr nc,.ten
        add a,10 + POP_DIGIT
        ld hl,pop_glyph + 3
        ld (hl),a
        dec hl
        ld a,e
        add a,POP_DIGIT
        ld (hl),a
        dec hl
        ld a,d
        or a
        ld b,POP_PLUS
        jr z,.small             ; " +20"
        add a,POP_DIGIT
        ld b,a                  ; "+150"
        ld a,POP_PLUS
.small: ld (hl),b
        dec hl
        ld (hl),a
        ld hl,(boom_addr)
        ld a,h
        add a,POP_ROW
        ld h,a
        ld b,0                  ; the glyphs' row
.row:   ld a,(pop_glyph)
        call pop_nib
        ld c,a
        ld a,(pop_glyph + 1)
        call pop_nib
        call pop_pair
        inc l
        ld a,(pop_glyph + 2)
        call pop_nib
        ld c,a
        ld a,(pop_glyph + 3)
        call pop_nib
        call pop_pair
        dec l
        inc h
        inc b
        ld a,b
        cp 5
        jr c,.row
        ld hl,(frame_count)
        ld de,CFG_POP_TIME
        add hl,de
        ld (pop_until),hl
        ld hl,pop_step
        ld (boom_hook+1),hl
        jp boom_show_fish

; C = the left glyph's row, A = the right's (both in the top nibble):
; one byte onto (HL). Corrupts: AF
pop_pair:
        rrca
        rrca
        rrca
        rrca
        or c
        ld (hl),a
        ret

; A = a glyph's number, B = its row: A = that row. Corrupts: DE
pop_nib:
        ld e,a
        add a,a
        add a,a
        add a,e                 ; five bytes a glyph
        add a,b
        add a,low pop_font
        ld e,a
        adc a,high pop_font
        sub e
        ld d,a
        ld a,(de)
        ret

; boom_hook while the points show: their clock, then the burst's end
; wipes them (and shows any new ones).
pop_step:
        call stats_prepare
        ld hl,(frame_count)
        ld de,(pop_until)
        or a
        sbc hl,de
        ret c
        jp boom_end
    ENDIF

; Four shapes, 12 rows, 2 bytes each. A bit set is ink.
boom_shapes:
        db $00,$00, $03,$C0, $07,$E0, $0F,$F0, $1F,$F8, $1F,$F8
        db $1F,$F8, $0F,$F0, $07,$E0, $03,$C0, $01,$80, $00,$00
        db $01,$80, $07,$E0, $1F,$F8, $3F,$FC, $7F,$FE, $7E,$FE
        db $7F,$FE, $3F,$FC, $1F,$F8, $07,$E0, $01,$80, $00,$00
        db $0F,$F0, $38,$1C, $60,$06, $C0,$03, $80,$01, $80,$01
        db $C0,$03, $60,$06, $38,$1C, $0F,$F0, $01,$80, $00,$00
        db $01,$00, $20,$08, $04,$20, $40,$04, $02,$80, $80,$01
        db $02,$80, $40,$04, $04,$20, $20,$08, $01,$00, $00,$00
