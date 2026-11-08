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
        jr z,.decide
.bdiff: set 2,e
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
        jr z,.all
        ld a,(wheel_pr1)
        cp h
        jr c,.all               ; the bomb's box ends above this one
        ld a,h
        add a,b
        ld d,a                  ; one past this box's last row
        ld a,(wheel_pr0)
        cp d
        jr nc,.all              ; it starts below
        ld a,(wheel_pc1)
        cp l
        jr c,.all               ; it ends to the left
        ld a,l
        add a,c
        ld d,a
        ld a,(wheel_pc0)
        cp d
        jr c,tp_cells           ; they overlap
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
; colour; a cell inside the bomb's box is passed over.
tp_cells:
.row:   push bc
        push hl
.cell:  ld a,(wheel_pr0)
        ld d,a
        ld a,h
        cp d
        jr c,.put               ; above the bomb's box
        ld a,(wheel_pr1)
        cp h
        jr c,.put               ; below it
        ld a,(wheel_pc0)
        ld d,a
        ld a,l
        cp d
        jr c,.put               ; left of it
        ld a,(wheel_pc1)
        cp l
        jr nc,.next             ; inside: the bomb's
.put:   push hl
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
.next:  inc l
        dec c
        jr nz,.cell
        pop hl
        pop bc
        inc h
        djnz .row
        ret

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
