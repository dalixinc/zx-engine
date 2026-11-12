;==============================================================================
; trigon/theme.asm - the fish and the missile in colour
;
; A sprite has no colour of its own: it takes its cells'. Atlantis's fish
; and missile take the water's white; Trigon's enemies are in the dark
; inks (config.asm), so each step the fish's cells are painted its colour
; (CFG_ANGLER_INK, CFG_PIRANHA_INK) and a missile's up in the water
; CFG_MISSILE_INK, and last step's cells are given back to the water.
; The bombs already paint theirs (wheel_colours), from CFG_LEVELS.
;
; trigon_paint is main_loop's fish draw (fish_draw_call), and ends by
; jumping to the fish's own draw, tp_real, which the burst, the flash and
; the wait set (boom.asm writes FISH_DRAW_TO, which is tp_real here).
; While the fish bursts, flashes or waits it keeps its own colours, and
; under the "LEVEL n" banner nothing is painted. Another sprite in a
; painted cell takes that colour: the Spectrum's clash.
;
; Cost (measured in docs/TRIGON.md): next to nothing on the heavy step,
; about 3 scanlines on another where nothing it paints has changed, and
; about 11 where something has.
;==============================================================================

;------------------------------------------------------------------------------
; trigon_paint - main_loop, in the fish's draw place
;
; Most steps nothing it paints has changed: the fish crosses a cell in 8
; steps, a missile in 4, and the bomb's box stays put as often. So it
; works out this step's cells first (the fish's, and its colour, the
; missile's, and the bomb's box, which it paints round), and if they are
; last step's, the cells are already right and it paints nothing (about
; 3 scanlines). Otherwise last step's cells are given back to the water
; and this step's painted. After the banner, and twice in 32 1/50
; seconds as a safety net, it paints whatever.
; At 50 it does nothing on the step that rotates the slow buffer, the
; heaviest: a change waits one step, so a cell can be the water's
; colour for a 1/50 second. (Repainting only the fish or only the
; missile, when only one moved, was tried and measured the same, for
; 285 bytes more.)
; Corrupts: AF, BC, DE, HL (and what the fish's draw does)
;------------------------------------------------------------------------------
trigon_paint:
        ld hl,hud_dirty
        bit HUD_BANNER,(hl)
        jr z,.go
        ld a,1
        ld (tp_force),a         ; the banner's cells: paint again after it
        jp .draw
.go:    ; At 50, the step that rotates the slow buffer after its copy
        ; (slow_phase 0 here, before scroll_blit) is the heaviest:
        ; leave the cells to the next step, one 1/50 second later. At 25
        ; the picture frame has the time.
        ld a,(step_ticks)
        dec a
        jr nz,.when
        ld a,(slow_phase)
        or a
        jp z,.draw
.when:  ; E: bit 0 the fish's cells changed, bit 1 the missile's, bit 2
        ; paint both whatever (the bomb's box moved, after the banner,
        ; or the every-32-frames safety net).
        ld e,0
        ld a,(tp_force)
        or a
        jr nz,.all
        ld a,(frame_count)
        and 30                  ; two 1/50 seconds in 32: one is not skipped
        jr nz,.fish
.all:   set 2,e
        ; The fish: drawing (not bursting, flashing or waiting)?
.fish:  ld hl,(tp_real)
        push de
        ld de,fish_draw_fast
        or a
        sbc hl,de
        pop de
        ld a,0
        jr nz,.fnone
        ld a,(fish_x)
        rrca
        rrca
        rrca
        and 31
        ld l,a
        ld a,(fish_y)           ; a 9-row fish always covers two rows
        rrca
        rrca
        rrca
        and 31
        ld h,a
        ld (tp_new_fat),hl
    IFDEF TWO_FISH
        ld a,(fish_draw_fast.img + 1)
        cp low rfish_images
        ld a,CFG_ANGLER_INK
        jr z,.fnone
    ENDIF
        ld a,CFG_PIRANHA_INK
.fnone: ld (tp_new_fink),a      ; 0 = no fish painted
        ld hl,tp_fish_ink
        cp (hl)
        jr nz,.fdiff
        or a
        jr z,.msl               ; none then, none now
        ld hl,(tp_new_fat)
        ld bc,(tp_fish_at)
        or a
        sbc hl,bc
        jr z,.msl
.fdiff: set 0,e
        ; The missile, up in the water only (not in its hatch, not down
        ; in the seabed's rows), and a falling power-up in its kind's
        ; colour. tp_new_mon is the colour: a new one repaints as a move does.
.msl:   xor a
        ld (tp_new_mon),a
    IFDEF POWERUPS
        ; Flying, it is the missile (kind 0); sinking, a power-up. Its
        ; colour by kind (tp_kinds), the bubble none. Inline: this runs
        ; every step, and a call cost late steps at level 6.
        ld a,(msl_phase)
        cp MSL_FLY
        jr c,.mcmp              ; waiting, or in its hatch
        ld a,(msl_kind)
        add a,low tp_kinds
        ld l,a
        ld h,high tp_kinds
        ld a,(hl)
        or a
        jr z,.mcmp
        ld (.mink + 1),a
        ; A sinking power-up covers other cells only at y & 7 = 0 or 1
        ; (power_sink moves it a pixel at a time, so a paint every other
        ; 1/50 second still sees one of them). Between, its box is the
        ; one last worked out: keep its colour and skip the work.
        ld c,a
        ld a,l
        cp low tp_kinds
        jr z,.mbox              ; the missile: its box each step
        ld a,c
        ld hl,tp_msl_on
        cp (hl)
        jr nz,.mbox             ; a new power-up: its box now
        ld a,(msl_y)
        and 6
        jr z,.mbox
        ld a,c
        ld (tp_new_mon),a       ; the same cells, the same colour
        jr .bomb
.mbox:
    ELSE
        ld a,(msl_phase)
        cp MSL_FLY
        jr nz,.mcmp
    ENDIF
        ld a,(msl_y)
        cp BACK_ROW * 8 - MISSILE_HEIGHT + 1
        jr nc,.mcmp
        ld c,a
        rrca
        rrca
        rrca
        and 31
        ld h,a                  ; its top row
        ld a,c
        and 7
        ld b,1
        jr z,.rows
        inc b                   ; off a row's top: two rows
.rows:  ld a,(msl_x)
        ld l,a
        and 7
        ld c,1
        cp 8 - MISSILE_WIDTH + 1
        jr c,.cols
        inc c                   ; across a column's edge: two columns
.cols:  ld a,l
        rrca
        rrca
        rrca
        and 31
        ld l,a
        ld (tp_new_mat),hl
        ld (tp_new_msize),bc
    IFDEF POWERUPS
.mink:  ld a,0                  ; its colour, written above
    ELSE
        ld a,CFG_MISSILE_INK
    ENDIF
        ld (tp_new_mon),a
.mcmp:  ld a,(tp_new_mon)
        ld hl,tp_msl_on
        cp (hl)
        jr nz,.mdiff
        or a
        jr z,.bomb
        ld hl,(tp_new_mat)
        ld bc,(tp_msl_at)
        or a
        sbc hl,bc
        jr nz,.mdiff
        ld hl,(tp_new_msize)
        ld bc,(tp_msl_size)
        sbc hl,bc               ; carry is clear
        jr z,.bomb
.mdiff: set 1,e
        ; The bomb's painted box: when it moves, it may have put water
        ; on a cell of ours, or left one we passed over.
.bomb:  ld hl,(wheel_pc0)       ; and wheel_pc1
        ld bc,(tp_wpc)
        or a
        sbc hl,bc
        jr nz,.bdiff
        ld hl,(wheel_pr0)       ; and wheel_pr1
        ld bc,(tp_wpr)
        sbc hl,bc
        jr nz,.bdiff
        ld a,(wheel_attr_n)
        ld hl,tp_wn
        cp (hl)
    IFDEF TWO_BOMBS
        jr z,.bomb2
.bdiff: set 2,e
        ; The second bomb's box the same way (src/trigon/twobomb.asm).
.bomb2: ld hl,(b2.wheel_pc0)
        ld bc,(tp_w2pc)
        or a
        sbc hl,bc
        jr nz,.b2diff
        ld hl,(b2.wheel_pr0)
        ld bc,(tp_w2pr)
        sbc hl,bc
        jr nz,.b2diff
        ld a,(b2.wheel_attr_n)
        ld hl,tp_w2n
        cp (hl)
        jr z,.decide
.b2diff:
        set 3,e
    ELSE
        jr z,.decide
.bdiff: set 2,e
    ENDIF
.decide:
        ld a,e
        or a
        jp z,.draw              ; the cells are as they should be
.both:
        ld a,(tp_fish_on)
        or a
        call nz,tp_fish_water
        ld a,(tp_msl_on)
        or a
        call nz,tp_msl_water
        call tp_fish_new
        call tp_msl_new
        jr .p4
.p4:    ld hl,(wheel_pc0)
        ld (tp_wpc),hl
        ld hl,(wheel_pr0)
        ld (tp_wpr),hl
        ld a,(wheel_attr_n)
        ld (tp_wn),a
    IFDEF TWO_BOMBS
        ld hl,(b2.wheel_pc0)
        ld (tp_w2pc),hl
        ld hl,(b2.wheel_pr0)
        ld (tp_w2pr),hl
        ld a,(b2.wheel_attr_n)
        ld (tp_w2n),a
    ENDIF
        xor a
        ld (tp_force),a
.draw:  ld hl,(tp_real)
        jp (hl)
        ASSERT wheel_pc1 == wheel_pc0 + 1 && wheel_pr1 == wheel_pr0 + 1

; The fish's cells (2 rows, 3 columns at tp_fish_at) and the missile's
; (tp_msl_at, tp_msl_size): water, their colour, or this step's taken on
; (tp_new_* into the record) and painted. Corrupt: AF, BC, DE, HL
tp_fish_water:
        ld a,WATER_ATTR
        jr tp_fish_box
tp_fish_paint:
        ld a,(tp_fish_ink)
tp_fish_box:
        ld hl,(tp_fish_at)
        ld bc,(2 << 8) | 3
        jp tp_box
tp_fish_new:
        ld a,(tp_new_fink)
        ld (tp_fish_ink),a
        ld (tp_fish_on),a       ; not 0 = painted
        or a
        ret z
        ld hl,(tp_new_fat)
        ld (tp_fish_at),hl
        jr tp_fish_paint

; tp_box and tp_cells are in the data block (TP_DATA, main.asm), where
; Trigon has room and the code is as fast: a byte there costs the tape
; one byte, a byte of hot code two.
    IFDEF POWERUPS
        COLD                    ; once a level
;------------------------------------------------------------------------------
; tp_banner_end - banner_tick, as the "LEVEL n" banner comes down: the
; speed's jumps back (rate_apply: a death meanwhile keeps its freeze;
; with nothing frozen it changes nothing). Corrupts: AF
;------------------------------------------------------------------------------
tp_banner_end:
        ld a,(game_rate)
        jp rate_apply
        HOT
    ENDIF

        MACRO TP_DATA
    IFDEF POWERUPS
;------------------------------------------------------------------------------
; tp_level_new - level_up, after the banner: nothing moves while it is up
; (the death's freeze: each step only draws, at 50, with the border,
; sound, bursts and pop-ups going on; tp_banner_end thaws it).
; Corrupts: AF, HL
;------------------------------------------------------------------------------
tp_level_new:
        call death_freeze
        ld hl,step_moved        ; no death_step: only the drawing
        ld (step_jp_move+1),hl
        ret


    ENDIF
;------------------------------------------------------------------------------
; tp_banner_heal - banner_tick, each step the "LEVEL n" banner is up: every
; 16 television frames, its blocks painted again. The bomb's colours and
; the fish's flash write cells under it, and leave holes as they pass;
; this fills them within a third of a second. banner_paint also has the
; bomb paint its own cells again, so one still on the banner keeps them.
; About 25 scanlines, then. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
tp_banner_heal:
        ld a,(frame_count)
        and 15
        ret nz
        ld a,(banner_ink)
        jp banner_paint

; The missile's cells (as the fish's, above).
tp_msl_water:
        ld a,WATER_ATTR
        jr tp_msl_box
tp_msl_paint:
        ld a,(tp_msl_on)        ; its colour (trigon_paint, .msl)
tp_msl_box:
        ld hl,(tp_msl_at)
        ld bc,(tp_msl_size)
        jp tp_box
tp_msl_new:
        ld a,(tp_new_mon)
        ld (tp_msl_on),a
        or a
        ret z
        ld hl,(tp_new_mat)
        ld (tp_msl_at),hl
        ld hl,(tp_new_msize)
        ld (tp_msl_size),hl
        jr tp_msl_paint

    IFDEF POWERUPS
; The slot's colours by kind: the missile's, then the power-ups' (the
; bubble's 0: unpainted). trigon_paint reads it within one page.
tp_kinds:       db CFG_MISSILE_INK, CFG_HEART_INK | SEA, 0, CFG_FALL_SUCTION_INK | SEA, CFG_FALL_SHOVE_INK | SEA, CFG_FALL_NUKE_INK | SEA
        ASSERT MSL_KIND_MISSILE == 0 && MSL_KIND_HEART == 1 && MSL_KIND_DOUBLE == 2 && MSL_KIND_SUCTION == 3 && MSL_KIND_SHOVE == 4 && MSL_KIND_NUKE == 5, "tp_kinds is in kind order"
        ASSERT high tp_kinds == high (tp_kinds + 5), "tp_kinds crosses a page"
        ASSERT CFG_MISSILE_INK != 0
        ; trigon_paint tells a new power-up by its colour: no missile's.
        ASSERT CFG_MISSILE_INK != CFG_HEART_INK | SEA && CFG_MISSILE_INK != CFG_FALL_SUCTION_INK | SEA
        ASSERT CFG_MISSILE_INK != CFG_FALL_SHOVE_INK | SEA && CFG_MISSILE_INK != CFG_FALL_NUKE_INK | SEA
        ASSERT CFG_POWER_SPEED <= 256, "power_sink: a pixel a 1/50 second at most"
      IF CFG_HELD_INK
; tp_held - lives_draw: A = the carried bomb's kind (0 = none): its cell
; on row 1 in its colour, or the water's. Keeps A. Corrupts: F, HL
tp_held:
        push af
        or a
        jr z,tp_held_none       ; none (tp_kinds' 0 is the missile)
        add a,low tp_kinds
        ld l,a
        ld h,high tp_kinds
        ld a,(hl)
        jr tp_held_set
tp_held_none:
        ld a,WATER_ATTR
tp_held_set:
        ld (ATTRS + LIVES_ROW * 32 + LIVES_COL - 4),a
        pop af
        ret
      ENDIF
    ENDIF



; A box of cells in one colour: H = top row, L = left column, B = rows,
; C = columns, A = the colour. The bomb's painted cells (wheel_pc0-pc1,
; wheel_pr0-pr1, while wheel_attr_n is set) are left alone: the bomb's
; colour wins over the fish's, and giving the water back must not take
; it (the bomb puts water back itself as it leaves a cell, and would not
; paint a cell again that it still holds). Only when the two boxes
; overlap is it done cell by cell. Corrupts: AF, B, DE, HL
tp_box: ld e,a
        ld a,(wheel_attr_n)
        or a
        jr z,.box2
        ld a,(wheel_pr1)
        cp h
        jr c,.box2              ; the bomb's box ends above this one
        ld a,h
        add a,b
        ld d,a                  ; one past this box's last row
        ld a,(wheel_pr0)
        cp d
        jr nc,.box2             ; it starts below
        ld a,(wheel_pc1)
        cp l
        jr c,.box2              ; it ends to the left
        ld a,l
        add a,c
        ld d,a
        ld a,(wheel_pc0)
        cp d
        jr c,tp_cells           ; they overlap
.box2:
    IFDEF TWO_BOMBS
        ld a,(b2.wheel_attr_n)  ; and the second bomb's
        or a
        jr z,.all
        ld a,(b2.wheel_pr1)
        cp h
        jr c,.all
        ld a,h
        add a,b
        ld d,a
        ld a,(b2.wheel_pr0)
        cp d
        jr nc,.all
        ld a,(b2.wheel_pc1)
        cp l
        jr c,.all
        ld a,l
        add a,c
        ld d,a
        ld a,(b2.wheel_pc0)
        cp d
        jr c,tp_cells
    ENDIF
.all:   ld a,h
        rrca
        rrca
        rrca
        ld h,a
        and $E0
        or l
        ld l,a
        ld a,h
        and 3
        or high ATTRS
        ld h,a                  ; HL = the top left cell
        ld a,e
.row:   push hl
        ld d,c
.col:   ld (hl),a
        inc l
        dec d
        jr nz,.col
        pop hl
        ld de,32
        add hl,de
        djnz .row
        ret

; tp_box's cell by cell: H = row, L = column, B rows, C columns, E = the
; colour; a cell inside a bomb's box is passed over.
tp_cells:
.crow:   push bc
        push hl
.ccell:  ld a,(wheel_attr_n)
        or a
        jr z,.ccell2
        ld a,(wheel_pr0)
        ld d,a
        ld a,h
        cp d
        jr c,.ccell2             ; above the bomb's box
        ld a,(wheel_pr1)
        cp h
        jr c,.ccell2             ; below it
        ld a,(wheel_pc0)
        ld d,a
        ld a,l
        cp d
        jr c,.ccell2             ; left of it
        ld a,(wheel_pc1)
        cp l
        jr nc,.cnext             ; inside: the bomb's
.ccell2:
    IFDEF TWO_BOMBS
        ld a,(b2.wheel_attr_n)
        or a
        jr z,.cput
        ld a,(b2.wheel_pr0)
        ld d,a
        ld a,h
        cp d
        jr c,.cput
        ld a,(b2.wheel_pr1)
        cp h
        jr c,.cput
        ld a,(b2.wheel_pc0)
        ld d,a
        ld a,l
        cp d
        jr c,.cput
        ld a,(b2.wheel_pc1)
        cp l
        jr nc,.cnext             ; inside: the second bomb's
    ENDIF
.cput:   push hl
        ld a,h
        rrca
        rrca
        rrca
        ld d,a
        and $E0
        or l
        ld l,a
        ld a,d
        and 3
        or high ATTRS
        ld h,a
        ld (hl),e
        pop hl
.cnext:  inc l
        dec c
        jr nz,.ccell
        pop hl
        pop bc
        inc h
        djnz .crow
        ret
        ENDM

tp_real:        dw fish_draw_fast       ; the fish's own draw (FISH_DRAW_TO)
tp_force:       db 1                    ; paint on the next step whatever
; The records of what is painted now and what this step wants
; (tp_fish_on to tp_new_msize) are run-time buffers (bss.asm).
        ASSERT MISSILE_HEIGHT == 8 && MISSILE_WIDTH <= 8
        ASSERT FISH_MAX_X / 8 + 3 <= 32, "the fish's three columns would run off the screen"
        ASSERT FISH_HEIGHT == 9, "a 9-row fish covers two rows of cells"

;------------------------------------------------------------------------------
; Trigon's tables and once-in-a-while code, in the hot code. They were
; in the data and cold blocks while a byte of hot code cost the tape
; two; since the tape check counts the code once (tape.asm, WHERE), the
; hot code has the room, and the data and cold blocks keep theirs for
; what only fits there. All only read, or run once a level or less.
;------------------------------------------------------------------------------
; The levels (config.asm, CFG_LEVELS; score.asm reads them).
level_tab:
        CFG_LEVELS
level_end:
LEVEL_COUNT_ROWS equ level_rows

; The level codes and the key map (codes.asm).
        LEVEL_CODES


; The end of the game (TRIGON_END).
        INCLUDE "ending.asm"
