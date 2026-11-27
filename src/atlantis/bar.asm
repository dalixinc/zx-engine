;==============================================================================
; bar.asm - row 1's level progress bar (Atlantis only: PROGRESS_BAR)
;
; A one-pixel line under the score line, as long as its 22 cells
; (176 pixels), filling from the left as the level's points come in:
;
;   SCORE 000420  LEVEL 3
;   ━━━━━━━━━━━━━━                 two thirds of the way: the line
;                                    reaches the level's number at the end
;
; The part still to get is left empty: dotted, it read as full stops
; between the words.
;
; It is the bottom pixel line of row 1's text cells, which the ROM font
; leaves empty in its capitals, digits and space, so nothing on the line
; moves and no colour changes: the bar is in the text's own white ink.
; hud_glyph draws only the top seven lines of a letter, so a changing
; digit leaves the bar alone. An empty bar is what the font has there
; (nothing), so the soak, which scores nothing, checks row 1 unchanged.
;
; THE SUM. Each point of a level is worth BAR_PIXELS / need of the bar.
; Dividing on every shot would cost the frame too much, so the division
; is done once a level (bar_level, from level_enter): bar_step is
; BAR_PIXELS * 256 / need, rounded up, the pixels a point is worth in
; 256ths. A shot then only adds bar_step once per point to bar_frac
; (bar_add, from score_add); bar_frac's high byte is the bar's length.
; Rounding up fills it by the target at the latest; it is clamped at
; BAR_PIXELS. The level's next row starts it again from empty.
;
; THE DRAWING is done like the rest of row 1: by hud_draw, straight
; after the sprite restores, when no sprite is on the screen, so a
; sprite crossing it photographs it like water and nothing flickers;
; and only when bar_frac's length differs from what is on the screen
; (bar_shown). Then only the cells between the old length and the new
; are written: a shot's points are one cell, or two. A new level or a
; new game redraws all 22 (bar_shown $FF). On a step that redraws the
; score's digits, the bar waits for the next step (hud_draw), so the
; two costs never fall in one frame.
;
; WHERE IT LIVES. Every block is nearly full, so it is split by how
; often each part runs: bar_level, once a level, in the cold block;
; bar_add and bar_bin, once a shot, in the hot code; bar_draw and its
; table in the data block (BAR_CODE, expanded by main.asm), which is
; not contended either. Its three numbers are in bss.asm.
;==============================================================================

BAR_CELLS       equ HUD_LEN             ; under the score line's cells, 0 to 21
BAR_PIXELS      equ BAR_CELLS * 8       ; 176
; The bottom pixel line (7) of row 1, column 0.
BAR_LINE        equ SCREEN + 7 * 256 + LIVES_ROW * 32
HUD_BAR         equ 3                   ; hud_dirty: the bar has news

        ASSERT BAR_PIXELS <= 255, "the bar's length is one byte"
        ASSERT LIVES_ROW < 8, "the bar's line is worked out for the screen's top third"

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
        ; bar_step = (BAR_PIXELS * 256 + need - 1) / need: rounded up,
        ; so the bar is full by the time the target is reached.
        ld hl,BAR_PIXELS * 256 - 1
        add hl,de               ; at most 45055 + 9999: fits
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
        ld a,$FF                ; not what the screen shows: all 22 cells
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
.add:   add hl,de               ; a point's worth, in 256ths of a pixel
        jr c,.full
        djnz .add
        ld a,h
        cp BAR_PIXELS
        jr c,.keep
.full:  ld hl,BAR_PIXELS * 256  ; full, and no further
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
; bar_draw - the bar on row 1, from hud_draw (no sprite on the screen)
; Writes only the cells between the length on the screen and the new
; one: one or two for a shot (about 100 T-states a cell). A new level or
; a new game empties it: all 22 cells cleared in a quick loop (about 530
; T-states, once a level). Nothing at all if the length is unchanged.
; In: HL = hud_dirty. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
bar_draw:
        res HUD_BAR,(hl)
        ld a,(bar_frac + 1)     ; the length it should be, 0 to BAR_PIXELS
        ld hl,bar_shown
        ld c,(hl)               ; the length on the screen ($FF: unknown)
        cp c
        ret z                   ; the same pixel: nothing to do
        ld (hl),a
        ld b,a                  ; B = new length
        ; The first cell: the shorter length's.
        cp c
        jr c,.lo
        ld a,c
.lo:    and $F8
        ld d,a                  ; D = that cell's first pixel
        rrca
        rrca
        rrca
        add a,low BAR_LINE
        ld l,a
        ld h,high BAR_LINE      ; HL = its byte on the screen
        ; The last cell: the longer length's, but not past the line.
        ld a,b
        cp c
        jr nc,.hi
        ld a,c
.hi:    rrca
        rrca
        rrca
        and 31
        cp BAR_CELLS
        jr c,.end
        ld a,BAR_CELLS - 1
.end:   add a,low BAR_LINE
        ld c,a                  ; C = its byte's low address
        ; Empty (a new level): those cells cleared, quickly.
        ld a,b
        or a
        jr nz,.cell
        ld a,c
        sub l
        inc a
        ld b,a                  ; how many
        xor a
.clear: ld (hl),a
        inc l
        djnz .clear
        ret
        ; Otherwise each cell by how many of its 8 pixels are done.
.cell:  ld a,b
        sub d                   ; done pixels from this cell's start
        jr nc,.some
        xor a                   ; the bar ends before this cell
.some:  cp 8
        jr c,.part
        ld a,$FF                ; all eight
        jr .put
.part:  ld e,a                  ; 0 to 7: that many pixels from the left
        xor a
        inc e
        jr .count
.pixel: scf
        rra
.count: dec e
        jr nz,.pixel
.put:   ld (hl),a
        ld a,l
        cp c
        ret z                   ; that was the last
        inc l                   ; the next cell along
        ld a,d
        add a,8
        ld d,a
        jr .cell

        ENDM
