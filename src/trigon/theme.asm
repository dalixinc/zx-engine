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
; Cost (measured in docs/TRIGON.md): about 8 scanlines a step at 50.
;==============================================================================

;------------------------------------------------------------------------------
; trigon_paint - main_loop, in the fish's draw place
; Corrupts: AF, BC, DE, HL (and what the fish's draw does)
;------------------------------------------------------------------------------
trigon_paint:
        ld hl,hud_dirty
        bit HUD_BANNER,(hl)
        jp nz,.draw
        ; The fish.
        ld a,(tp_fish_on)
        or a
        jr z,.fish
        ld hl,(tp_fish_at)
        ld bc,(2 << 8) | 3
        ld a,WATER_ATTR
        call tp_box             ; last step's cells water again
        xor a
        ld (tp_fish_on),a
.fish:  ld hl,(tp_real)
        ld de,fish_draw_fast
        or a
        sbc hl,de
        jr nz,.missile          ; bursting, flashing or waiting
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
        ld (tp_fish_at),hl
    IFDEF TWO_FISH
        ld a,(fish_draw_fast.img + 1)
        cp low rfish_images
        ld a,CFG_ANGLER_INK
        jr z,.ink
    ENDIF
        ld a,CFG_PIRANHA_INK
.ink:   ld bc,(2 << 8) | 3      ; FISH_MAX_X keeps the three on the screen
        call tp_box
        ld a,1
        ld (tp_fish_on),a
        ; The missile, up in the water only (not a power-up, not in its
        ; hatch, not down in the seabed's rows).
.missile:
        ld a,(tp_msl_on)
        or a
        jr z,.msl
        ld hl,(tp_msl_at)
        ld bc,(tp_msl_size)
        ld a,WATER_ATTR
        call tp_box
        xor a
        ld (tp_msl_on),a
.msl:   ld a,(msl_phase)
        cp MSL_FLY
        jr nz,.draw
    IFDEF POWERUPS
        ld a,(msl_kind)
        or a
        jr nz,.draw
    ENDIF
        ld a,(msl_y)
        cp BACK_ROW * 8 - MISSILE_HEIGHT + 1
        jr nc,.draw
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
        ld (tp_msl_at),hl
        ld (tp_msl_size),bc
        ld a,CFG_MISSILE_INK
        call tp_box
        ld a,1
        ld (tp_msl_on),a
.draw:  ld hl,(tp_real)
        jp (hl)

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
tp_fish_on:     db 0                    ; 1 = tp_fish_at's cells are painted
tp_fish_at:     dw 0                    ; L column, H row
tp_msl_on:      db 0
tp_msl_at:      dw 0
tp_msl_size:    dw 0                    ; C columns, B rows
        ASSERT MISSILE_HEIGHT == 8 && MISSILE_WIDTH <= 8
        ASSERT FISH_MAX_X / 8 + 3 <= 32, "the fish's three columns would run off the screen"
        ASSERT FISH_HEIGHT == 9, "a 9-row fish covers two rows of cells"
