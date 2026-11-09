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
        ; The missile, up in the water only (not a power-up, not in its
        ; hatch, not down in the seabed's rows).
.msl:   xor a
        ld (tp_new_mon),a
        ld a,(msl_phase)
        cp MSL_FLY
        jr nz,.mcmp
    IFDEF POWERUPS
        ld a,(msl_kind)
        or a
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
        ld a,1
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
.bomb:  call tp_diver            ; his belt's cells, on their own (TP_DATA)
        ld hl,(wheel_pc0)       ; and wheel_pc1
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
; A belt's byte: its ink on the sea, or 0 for white (CFG_BELTS).
        MACRO BELT ink?
    IF ink? == WHITE
        db 0                    ; the sea's own ink: nothing painted
    ELSE
        db ink? | SEA
    ENDIF
        ENDM

        COLD                    ; once a level
; tb_level, each level: his belt (CFG_BELTS), and everything painted
; again, so a new ink shows at once. Corrupts: AF, DE, HL
tp_belt_level:
        ld a,(level_n)
        cp CFG_ENDING_LEVEL + 1
        jr c,.blvl
        ld a,CFG_ENDING_LEVEL
.blvl:  ld e,a
        ld d,0
        ld hl,tp_belts - 1
        add hl,de
        ld a,(hl)
        ld (tp_belt),a
        ld a,1
        ld (tp_force),a
        ret

tp_belts:
        CFG_BELTS
        ASSERT $ - tp_belts == CFG_ENDING_LEVEL, "CFG_BELTS: one belt a level"
        HOT

        MACRO TP_DATA
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
        ld a,CFG_MISSILE_INK
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

;------------------------------------------------------------------------------
; The diver's belt (CFG_BELTS): from the level whose belt is not white,
; his cells are painted its ink, as the fish's are its own. White is the
; sea's own ink, so a white belt paints nothing. His box is 3 or 4
; columns (by his x) and 2 or 3 rows (by his y), kept off the seabed's
; rows, and not painted up by the score's. tp_diver works out this
; step's box and, if it is not last step's (or E's bit 2 says paint
; everything), gives last step's cells back to the water (tp_d_water)
; and paints this step's (tp_d_new): his own box only, as he moves far
; more often than the fish or the missile changes a cell, and they only
; share his cells when they are killing him.
; Corrupt: AF, BC, HL (and tp_box's)
;------------------------------------------------------------------------------
tp_diver:
        xor a
        ld (tp_new_don),a
        ld a,(tp_belt)
        or a
        jr z,.dcmp              ; white: nothing to paint
        ld a,(diver_y)
        ld c,a
        rrca
        rrca
        rrca
        and 31
        ld h,a                  ; his top row
        ld a,c
        and 7
        cp 2                    ; 15 rows: 2 cell rows from a row's top 2
        ld b,2
        jr c,.drows
        inc b
.drows: ld a,h
        cp 2
        jr c,.dcmp              ; up by the score's rows: not painted there
        ld a,BACK_ROW
        sub h                   ; rows down to the seabed's
        jr c,.dcmp
        jr z,.dcmp
        cp b
        jr nc,.dfit
        ld b,a
.dfit:  ld a,(diver_x)
        ld l,a
        and 6                   ; drawn at even x
        ld c,3
        jr z,.dcols
        inc c
.dcols: ld a,l
        rrca
        rrca
        rrca
        and 31
        ld l,a
        ld a,32
        sub l                   ; to the right edge
        cp c
        jr nc,.dok
        ld c,a
.dok:   ld (tp_new_dat),hl
        ld (tp_new_dsize),bc
        ld a,1
        ld (tp_new_don),a
        ; This step's record against last step's, 5 bytes each. Off, the
        ; box is not written, so it stays as last painted (bss: 0 at first).
.dcmp:  push de
        bit 2,e
        jr nz,.ddiff            ; everything painted again
        ld hl,tp_new_don
        ld de,tp_d_on
        ld b,5
.dc:    ld a,(de)
        cp (hl)
        inc hl
        inc de
        jr nz,.ddiff
        djnz .dc
        pop de
        ret
.ddiff: call tp_d_water
        call tp_d_new
        pop de
        ret
        ASSERT tp_d_at == tp_d_on + 1 && tp_d_size == tp_d_on + 3 && tp_new_dat == tp_new_don + 1 && tp_new_dsize == tp_new_don + 3

tp_d_water:
        ld a,(tp_d_on)
        or a
        ret z
        ld a,WATER_ATTR
        jr tp_d_box
tp_d_new:
        ld a,(tp_new_don)
        ld (tp_d_on),a
        or a
        ret z
        ld hl,(tp_new_dat)
        ld (tp_d_at),hl
        ld hl,(tp_new_dsize)
        ld (tp_d_size),hl
        ld a,(tp_belt)
tp_d_box:
        ld hl,(tp_d_at)
        ld bc,(tp_d_size)
        jp tp_box


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
; What is painted now (the soak reads tp_fish_on and tp_fish_at).
tp_fish_on:     db 0                    ; not 0 = tp_fish_at's cells are painted
tp_fish_at:     dw 0                    ; L column, H row
tp_fish_ink:    db 0                    ; their colour, 0 = none
tp_msl_on:      db 0
tp_msl_at:      dw 0
tp_msl_size:    dw 0                    ; C columns, B rows
tp_wpc:         dw 0                    ; the bomb's box when they were painted
tp_wpr:         dw 0
tp_wn:          db 0
    IFDEF TWO_BOMBS
tp_w2pc:        dw 0                    ; the second bomb's, the same
tp_w2pr:        dw 0
tp_w2n:         db 0
    ENDIF
tp_force:       db 1                    ; paint on the next step whatever
; What this step wants.
tp_new_fat:     dw 0
tp_new_fink:    db 0
tp_new_mon:     db 0
tp_new_mat:     dw 0
tp_new_msize:   dw 0
        ASSERT MISSILE_HEIGHT == 8 && MISSILE_WIDTH <= 8
        ASSERT FISH_MAX_X / 8 + 3 <= 32, "the fish's three columns would run off the screen"
        ASSERT FISH_HEIGHT == 9, "a 9-row fish covers two rows of cells"
