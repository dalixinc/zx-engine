;==============================================================================
; bar.asm - the level's progress bar on row 0 (Atlantis only: PROGRESS_BAR)
;
; Row 0, the empty row above the score line, is the bar: its 32 cells
; fill from the left in CFG_BAR_ATTR's colour as the level's points come
; in, one cell at a time, and the whole row is full when the level is
; done. A new level empties it.
;
;   row 0   ██████████████░░░░░░░░░░░░░░░░░░    the level, nearly half done
;   row 1   SCORE 000420  LEVEL 3         ♥♥♥
;
; It is colour only: each cell's attribute (paper), never its pixels.
; So nothing a sprite photographs or puts back is touched, the score
; line and the hearts are as they were, and a sprite crossing the bar
; shows on its colour for a moment, as on the water. (Test builds put
; the stat line's digits on row 0; they keep showing, in white, over it.)
; The colour is CFG_BAR_ATTR (config.asm): a colour no level's border
; uses, so the bar never runs into the border above it.
;
; THE SUM. Each point of a level is worth BAR_CELLS / need of the bar.
; Dividing on every shot would cost the frame too much, so the division
; is done once a level (bar_level, from level_enter): bar_step is
; BAR_CELLS * 256 / need, rounded up, the cells a point is worth in
; 256ths. A shot then only adds bar_step once per point to bar_frac
; (bar_add, from score_add); bar_frac's high byte is the bar's length.
; Rounding up fills it by the target at the latest; it is clamped at
; BAR_CELLS. The level's next row starts it again from empty.
;
; THE DRAWING is done like row 1: by hud_draw, straight after the
; sprite restores, and only when the bar's length in cells differs from
; what is on the screen (bar_shown). Then only the cells between the old
; length and the new are written: a shot is usually none or one. A new
; level or a new game writes all 32 (bar_shown $FF), the empty ones with
; LDIR (about 700 T-states, once a level). On a step that redraws the
; score's digits, the bar waits for the next step (hud_draw), so the two
; costs never fall in one frame.
;
; WHERE IT LIVES. Every block is nearly full, so it is split by how
; often each part runs: bar_level, once a level, in the cold block;
; bar_add and bar_bin, once a shot, in the hot code; bar_draw in the
; data block (BAR_CODE, expanded by main.asm), which is not contended
; either. Its three numbers are in bss.asm.
;==============================================================================

BAR_CELLS       equ 32                  ; the whole of row 0
BAR_ROW_ATTRS   equ ATTRS               ; row 0's colours: the cell is the low byte
HUD_BAR         equ 3                   ; hud_dirty: the bar has news

        ASSERT (BAR_ROW_ATTRS & $FF) == 0, "bar_draw takes the cell for the attribute's low byte"
        ASSERT CFG_BAR_ATTR != WATER_ATTR, "the bar's colour must differ from the water"

        COLD
;------------------------------------------------------------------------------
; bar_level - a new level: the bar empty, and what each point is worth
; In: HL = the level's row of level_tab (its first two bytes are the
;     points it needs, BCD, low byte first). Called by level_enter, so
;     once a level, and for each level a code skips.
; Out: HL kept. Corrupts: AF, BC, DE
;------------------------------------------------------------------------------
bar_level:
        push hl
        ld a,(hl)               ; tens and units
        call bar_bin
        ld c,a
        inc hl
        ld a,(hl)               ; thousands and hundreds
        call bar_bin
        ld b,a
        ; need = hundreds * 100 + the rest, 1 to 9999
        ld l,c
        ld h,0
        ld de,100
        inc b
        jr .count
.hund:  add hl,de
.count: djnz .hund
        ex de,hl                ; DE = need
        ; bar_step = (BAR_CELLS * 256 + need - 1) / need: rounded up,
        ; so the bar is full by the time the target is reached.
        ld hl,BAR_CELLS * 256 - 1
        add hl,de               ; at most 8191 + 9999: fits
        ld a,h                  ; AC = the dividend
        ld c,l
        ld hl,0                 ; the remainder
        ld b,16
.div:   sla c                   ; AC one bit left, its top bit into HL
        rla
        adc hl,hl               ; never carries: HL < 2 * need
        sbc hl,de
        jr nc,.one
        add hl,de               ; it did not go: put it back
        jr .next
.one:   inc c                   ; it went: a 1 in the quotient
.next:  djnz .div
        ld h,a
        ld l,c
        ld (bar_step),hl
        ld hl,0
        ld (bar_frac),hl        ; empty
        ld a,$FF                ; not what the screen shows: all 32 cells
        ld (bar_shown),a
        ld hl,hud_dirty
        set HUD_BAR,(hl)
        pop hl
        ret
        HOT

;------------------------------------------------------------------------------
; bar_add - a shot's points: their share of the bar
; In: A = the points, one BCD byte. Called by score_add, before it adds
;     them (a target passed then starts the bar again: level_enter).
; Out: A kept. Corrupts: F, BC, DE, HL
;------------------------------------------------------------------------------
bar_add:
        push af
        call bar_bin
        or a
        jr z,.none
        ld b,a                  ; points, binary
        ld hl,(bar_frac)
        ld de,(bar_step)
.add:   add hl,de               ; a point's worth, in 256ths of a cell
        jr c,.full
        djnz .add
        ld a,h
        cp BAR_CELLS
        jr c,.keep
.full:  ld hl,BAR_CELLS * 256   ; full, and no further
.keep:  ld (bar_frac),hl
        ld hl,hud_dirty
        set HUD_BAR,(hl)        ; bar_draw works out whether it shows
.none:  pop af
        ret

;------------------------------------------------------------------------------
; bar_bin - A = a BCD byte (0 to 99) as binary: 16t + u - 6t = 10t + u
; Corrupts: F, D, E
;------------------------------------------------------------------------------
bar_bin:
        ld d,a
        and $F0                 ; 16t
        rrca
        rrca
        ld e,a                  ; 4t
        rrca                    ; 2t
        add a,e                 ; 6t
        ld e,a
        ld a,d
        sub e
        ret

        MACRO BAR_CODE

;------------------------------------------------------------------------------
; bar_draw - the bar on row 0, from hud_draw
; Colours only the cells between the length on the screen and the new
; one: below the new length CFG_BAR_ATTR, from it on the water's.
; Nothing at all if the length in cells is unchanged.
; In: HL = hud_dirty. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
bar_draw:
        res HUD_BAR,(hl)
        ld a,(bar_frac + 1)     ; the length it should be, 0 to BAR_CELLS
        ld hl,bar_shown
        ld c,(hl)               ; the length on the screen ($FF: unknown)
        cp c
        ret z                   ; the same cell: nothing to do
        ld (hl),a
        ld b,a                  ; B = new length
        ; Unknown ($FF: a new level or game): the whole row.
        inc c
        jr nz,.known
        xor a
        ld c,BAR_CELLS
        jr .from
        ; Otherwise from the shorter length (A) to the longer (C).
.known: dec c
        cp c
        jr c,.from
        ld a,c
        ld c,b
.from:  ld l,a
        ld h,high BAR_ROW_ATTRS ; HL = the first cell's colour
        ld a,c
        cp BAR_CELLS
        jr c,.to
        ld a,BAR_CELLS
.to:    sub l
        ret z
        ld c,a                  ; C = how many cells
        ; The done cells, up to the new length...
.done:  ld a,l
        cp b
        jr nc,.rest
        ld (hl),CFG_BAR_ATTR
        inc l
        dec c
        jr nz,.done
        ret
        ; ...and the rest water: the first, then LDIR the others along.
.rest:  ld (hl),WATER_ATTR
        dec c
        ret z
        ld b,0
        ld d,h
        ld e,l
        inc e
        ldir
        ret

        ENDM
