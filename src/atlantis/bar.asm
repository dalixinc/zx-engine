;==============================================================================
; bar.asm - the level's progress bar on row 0 (Atlantis only: PROGRESS_BAR)
;
; Row 0, the empty row above the score line, holds a small word, DONE,
; and then the bar: a line four pixels tall (two pixels of water above
; it and below it; DONE is six tall, a pixel past it at each end) from
; column 3 to the right-hand edge, 232 pixels, filling from
; the left in the level's border colour as the level's points come in. It
; is full when the level is done; a new level drains it back to empty.
;
;   row 0   DONE ━━━━━━━━━━━━━━━━━━━━━━━                the level, two thirds done
;   row 1   SCORE 000420  LEVEL 3                ♥♥♥
;
; THE COLOURS: the bar's 29 cells have the level's border colour for ink
; on the water's paper, so an empty cell is water and every pixel drawn
; is bar (bar_paint: at a new game, from bar_start, and at each new
; level, from level_up, once level_style has the new colour). A level's
; bar is its border's colour, so each level looks a little different;
; the water's top pixel line keeps the bar off the border itself. DONE
; is in cells 0 to 2, in the water's own white. A sprite crossing the
; bar's cells (the diver can swim up into row 0) shows in that colour
; there for a moment.
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
; THE DRAWING is done like row 1: by hud_draw, straight after the
; sprite restores, when no sprite is on the screen, so a sprite that
; crosses the bar photographs it like water and nothing flickers.
; bar_shown is the length on the screen. Each step it moves towards
; bar_frac's length by at most BAR_RUN pixels, redrawing only the cells
; it passes (4 pixel lines each, at most 2 cells: about 250 T-states),
; and hud_dirty's HUD_BAR stays set until it has got there. So a missile's
; points slide on over a few steps, and a new level's empty bar drains
; away over about half a second, never all in one frame. (24 pixels a
; step cost the heavy seabed case a late step or two more in MEASURE.) On a step
; that redraws the score's digits, the bar waits for the next step
; (hud_draw), so the two costs never fall in one frame.
;
; WHERE IT LIVES. Every block is nearly full, so it is split by how
; often each part runs: bar_level and bar_start (with DONE's picture),
; once a level or a game, in the cold block; bar_add and bar_bin, once a
; shot, bar_paint, and bar_draw's first test, once a step while it has
; news, in the hot code; the rest of the drawing, bar_move, in the data block
; (BAR_CODE, expanded by main.asm), which is not contended either. Its three numbers are in
; bss.asm.
;==============================================================================

BAR_COL         equ 3                   ; the bar's first cell; DONE has 0 to 2
BAR_CELLS       equ 32 - BAR_COL        ; 29
BAR_PIXELS      equ BAR_CELLS * 8       ; 232
BAR_LINE        equ SCREEN + 2 * 256    ; row 0's pixel line 2: the bar's top
BAR_LINES       equ 4                   ; lines 2 to 5; 0, 1, 6 and 7 stay water
WORD_LINE       equ SCREEN + 1 * 256    ; DONE: lines 1 to 6, a line taller
WORD_LINES      equ 6                   ; than the bar at each end
BAR_RUN         equ 8                   ; the most it moves in a step, in pixels
HUD_BAR         equ 3                   ; hud_dirty: the bar has news

        ASSERT BAR_PIXELS <= 255, "the bar's length is one byte"
        ASSERT BAR_PIXELS * 256 <= 65535, "bar_level divides a 16-bit number"
        ASSERT (BAR_LINE & $FF) == 0 && (WORD_LINE & $FF) == 0, "bar_draw takes the cell's column for the low byte"
        ASSERT BAR_RUN <= 8, "bar_draw's notes say a step redraws at most 2 cells"

        COLD
;------------------------------------------------------------------------------
; bar_level - a new level: the bar to drain, and what each point is worth
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
        ; bar_step = BAR_PIXELS * 256 / need, one more if anything is
        ; left over: rounded up, so the bar is full by the target.
        ld a,high (BAR_PIXELS * 256) ; AC = the dividend
        ld c,low (BAR_PIXELS * 256)
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
        ld d,a                  ; DE = the quotient
        ld e,c
        ld a,h
        or l
        jr z,.exact
        inc de                  ; something left over: round up
.exact: ld (bar_step),de
        ld hl,0
        ld (bar_frac),hl        ; empty: bar_draw drains what is shown
        ld hl,hud_dirty
        set HUD_BAR,(hl)
        pop hl
        ret

;------------------------------------------------------------------------------
; bar_start - a cleared screen (a new game): DONE, and the bar's colours
; From game_reset, after draw_scenery has painted the water (row 0 too)
; and before any sprite is drawn, so it can write row 0 at once. The
; bar's pixels are already 0 (cls): it is empty on the screen. (The
; attract demo's label, which was on row 0, is on row 2 with the bar.)
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
bar_start:
        ld hl,bar_word
        ld de,WORD_LINE         ; row 0, line 1, column 0
        ld b,WORD_LINES
.line:  push bc
        ld bc,3
        ldir                    ; one line of the word, three cells
        pop bc
        ld e,0                  ; back to column 0,
        inc d                   ; the next pixel line down
        djnz .line
        call bar_paint          ; the bar's cells: the level's colour
        xor a
        ld (bar_shown),a        ; empty on the screen
        ret

; DONE, four letters four pixels wide, six tall, in row 0's cells 0 to 2
; (lines 1 to 6, as the bar).
bar_word:
        db %01110001, %10010010, %11110000   ; .###...##..#..#.####....
        db %01001010, %01011010, %10000000   ; .#..#.#..#.##.#.#.......
        db %01001010, %01010110, %11100000   ; .#..#.#..#.#.##.###.....
        db %01001010, %01010010, %10000000   ; .#..#.#..#.#..#.#.......
        db %01001010, %01010010, %10000000   ; .#..#.#..#.#..#.#.......
        db %01110001, %10010010, %11110000   ; .###...##..#..#.####....
        HOT

;------------------------------------------------------------------------------
; bar_paint - the bar's 29 cells: the level's border colour for ink, on
; the water. Once a game and once a level (bar_start, level_up). The
; heartbeat's BORDER_BEAT ($FF) would be white; Atlantis has none now.
; Corrupts: AF, B, HL
;------------------------------------------------------------------------------
bar_paint:
        ld a,(level_border)
        and 7
        or SEA                  ; on the water's paper
        ld hl,ATTRS + BAR_COL
        ld b,BAR_CELLS
.cell:  ld (hl),a
        inc l
        djnz .cell
        ret

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

;------------------------------------------------------------------------------
; bar_draw - one step of the bar towards its length, from hud_draw
; Moves bar_shown at most BAR_RUN pixels towards bar_frac's length and
; redraws the cells between the two (bar_move, in the data block, which
; is full but for this first part). HUD_BAR stays set until it is there.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
bar_draw:
        ld a,(bar_shown)
        ld c,a                  ; C = the length on the screen
        ld a,(bar_frac + 1)     ; the length it should be
        sub c                   ; A = how far to go; carry: shorter
        jp nz,bar_move          ; (JP keeps the carry for it)
        ld hl,hud_dirty
        res HUD_BAR,(hl)        ; there: nothing more to do
        ret

        MACRO BAR_CODE

; bar_move - bar_draw's moving and drawing. In: A = how far to go, signed,
; carry set if shorter; C = the length on the screen.
bar_move:
        ; At most BAR_RUN either way.
        jr c,.down
        cp BAR_RUN
        jr c,.go
        ld a,BAR_RUN
        jr .go
.down:  cp (-BAR_RUN) & $FF
        jr nc,.go
        ld a,(-BAR_RUN) & $FF
.go:    add a,c
        ld b,a                  ; B = the new length
        ld (bar_shown),a
        ; The cells from the shorter length's to the cell of the longer
        ; length's last pixel. A = new, C = old.
        cp c
        jr c,.lo
        ld a,c                  ; growing: from the old length
        ld c,b                  ; to the new
.lo:    and $F8
        ld d,a                  ; D = the first cell's first pixel
        rrca
        rrca
        rrca
        add a,BAR_COL
        ld l,a
        ld h,high BAR_LINE      ; HL = its top line on the screen
        ld a,c
        dec a                   ; the longer length's last pixel
        rrca
        rrca
        rrca
        and 31
        add a,BAR_COL
        ld c,a                  ; C = the last cell's column
        ; Each cell: its done pixels, 0 to 8, from the left.
.cell:  ld a,b
        sub d
        jr nc,.some
        xor a                   ; the bar ends before this cell
.some:  cp 8
        jr c,.part
        ld a,$FF                ; all eight
        jr .put
.part:  ld e,a                  ; 0 to 7: that many 1s from the left
        xor a
        inc e
        jr .count
.pixel: scf
        rra
.count: dec e
        jr nz,.pixel
.put:   ld e,BAR_LINES
.line:  ld (hl),a               ; the cell's six lines, top down
        inc h
        dec e
        jr nz,.line
        ld h,high BAR_LINE
        ld a,l
        cp c
        ret z                   ; that was the last
        inc l                   ; the next cell along
        ld a,d
        add a,8
        ld d,a
        jr .cell

        ENDM
