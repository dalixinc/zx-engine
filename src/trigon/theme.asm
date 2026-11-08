;==============================================================================
; trigon/theme.asm - Trigon's colours
;
; While trigon_on is set (art.asm: from the city to the menu), each new
; level's look is the Atlantis row's (level_style) with Trigon's colours
; over it, from config.asm:
;   - a steady border from the dark set, CFG_TRIGON_BORDER_0 to _3 by the
;     level number, so two levels in a row never share one
;   - the bomb's ink, CFG_TRIGON_INK_0 to _3 the same way (on the sea's
;     paper, as every bomb colour is)
;   - the death's border flash in CFG_TRIGON_HIT_INK and black, as red
;     would hardly show against a red or black border
; The new level's flash (white) and a special bomb's (cyan, yellow) show
; against them all. The diver stays white. The fish and the missile have
; no colour of their own: like the diver, they take the water's ink.
;==============================================================================

;------------------------------------------------------------------------------
; trigon_style - il_level (interlude.asm), on each level change in Trigon
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
trigon_style:
        ld a,(level_n)
        and 3
        ld e,a
        ld d,0
        ld hl,trigon_borders
        add hl,de
        ld a,(hl)
        ld (beat_fixed + 1),a   ; as level_style writes a fixed border
        push de
        ld hl,beat_fixed
        ld de,step_skip.beat
        ld bc,4
        ldir
        pop de
        ld hl,trigon_inks
        add hl,de
        ld a,(hl)
        ld (level_ink),a        ; the next bomb's colour (wheel_type)
        ld a,CFG_TRIGON_HIT_INK
        jr trigon_hit

; trigon_off (art.asm): the death flash red again. Corrupts: AF
trigon_plain:
        ld a,RED
trigon_hit:
        ld (step_skip.hit_ink + 1),a
        ret

trigon_borders: db CFG_TRIGON_BORDER_0, CFG_TRIGON_BORDER_1, CFG_TRIGON_BORDER_2, CFG_TRIGON_BORDER_3
trigon_inks:    db CFG_TRIGON_INK_0, CFG_TRIGON_INK_1, CFG_TRIGON_INK_2, CFG_TRIGON_INK_3
        ASSERT CFG_TRIGON_BORDER_0 != CFG_TRIGON_BORDER_1 && CFG_TRIGON_BORDER_1 != CFG_TRIGON_BORDER_2 && CFG_TRIGON_BORDER_2 != CFG_TRIGON_BORDER_3 && CFG_TRIGON_BORDER_3 != CFG_TRIGON_BORDER_0, "two Trigon levels in a row would share a border"
        ASSERT CFG_TRIGON_BORDER_0 <= 7 && CFG_TRIGON_BORDER_1 <= 7 && CFG_TRIGON_BORDER_2 <= 7 && CFG_TRIGON_BORDER_3 <= 7 && CFG_TRIGON_HIT_INK <= 7

;------------------------------------------------------------------------------
; The fish and the missile in colour. A sprite has no colour of its own:
; it takes its cells'. In Trigon the fish's cells are painted its colour
; (CFG_TRIGON_ANGLER, CFG_TRIGON_PIRANHA) and a missile's up in the water
; CFG_TRIGON_MISSILE, and last step's cells water again, each step. It
; runs in the fish's draw place (main_loop's fish_draw_call), then jumps
; to the fish's own draw, which the burst and the flash code set: while
; Trigon lasts their writes (boom.asm, the five .fdc) go to tp_real. So
; Atlantis does not pay for it, and while the fish bursts, flashes or
; waits it is left its own colours. Under the banner nothing is painted.
; Another sprite in a painted cell takes that colour: the Spectrum's clash.
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
        ld a,CFG_TRIGON_ANGLER
        jr z,.ink
    ENDIF
        ld a,CFG_TRIGON_PIRANHA
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
        ld a,(msl_kind)
        or a
        jr nz,.draw
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
        ld a,CFG_TRIGON_MISSILE
        call tp_box
        ld a,1
        ld (tp_msl_on),a
.draw:  ld hl,(tp_real)
        jp (hl)

; A box of cells in one colour: H = top row, L = left column, B = rows,
; C = columns, A = the colour. Corrupts: F, B, DE, HL
tp_box: ld e,a
        ld a,h
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

;------------------------------------------------------------------------------
; tp_on, tp_off - trigon_art_in and trigon_off: trigon_paint into the
; fish's draw place and the burst's writes after it, or both back.
; Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
tp_on:  ld hl,(fish_draw_call + 1)
        ld (tp_real),hl
        ld hl,trigon_paint
        ld (fish_draw_call + 1),hl
        xor a
        ld (tp_fish_on),a
        ld (tp_msl_on),a
        ld de,tp_real
        jr tp_sites_to
tp_off: ld hl,(tp_real)
        ld (fish_draw_call + 1),hl
        ld de,fish_draw_call + 1
tp_sites_to:
        ld hl,tp_sites
        ld b,TP_SITES
.site:  push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; HL = the operand of one write
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
        inc hl
        inc hl
        djnz .site
        ret

tp_sites:       dw boom_reset.fdc + 1, fish_flash_begin.fdc + 1, fish_begin_wait.fdc + 1
                dw fish_wait_step.fdc + 1, boom_at_fish.fdc + 1
TP_SITES        equ ($ - tp_sites) / 2
tp_real:        dw fish_draw_fast       ; the fish's own draw, in Trigon
tp_fish_on:     db 0                    ; 1 = tp_fish_at's cells are painted
tp_fish_at:     dw 0                    ; L column, H row
tp_msl_on:      db 0
tp_msl_at:      dw 0
tp_msl_size:    dw 0                    ; C columns, B rows
        ASSERT MISSILE_HEIGHT == 8 && MISSILE_WIDTH <= 8
        ASSERT FISH_MAX_X / 8 + 3 <= 32, "the fish's three columns would run off the screen"
        ASSERT FISH_HEIGHT == 9, "a 9-row fish covers two rows of cells"
