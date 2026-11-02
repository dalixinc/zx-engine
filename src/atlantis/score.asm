;==============================================================================
; score.asm - the score, the levels, and the line that shows them
;
; Points come only from shots: a fish, a bomb or a missile the torpedo
; hits (CFG_PTS_*). Something that runs into the diver scores nothing.
;
; The score is binary-coded decimal, three bytes, six digits, lowest
; byte first. Adding is ADD and DAA a byte at a time, and each digit is
; a nibble, so drawing it needs no division.
;
; THE LINE. Row 1, with the hearts:
;
;   SCORE 000000  LEVEL 1       ...
;
; Row 0 stays the debug line's. Row 1 is drawn the way the hearts always
; were: straight after the sprite restores, when no sprite is on the
; screen, and only when something on it has changed. A sprite that then
; crosses it photographs the words like water and puts them back. Row 0
; could not work like that: the debug line rewrites its digits under
; sprites every few frames, which is what its wipe-and-redraw machinery
; in stats.asm is for. The explosion and the missiles stop at row 2, so
; nothing else draws on row 1. The cells are the water's colours, so
; there is no clash.
;
; LEVELS. CFG_LEVELS in config.asm is a table: the points each level
; needs, its missile gap, and how much faster its bombs go. Reaching the
; target puts up a "LEVEL n" banner for CFG_BANNER_TIME, plays a jingle,
; and the next row takes over. After the last row, the last row repeats.
; Level 1 is the game as it was, which the soak relies on.
;
; THE BANNER is drawn in attribute cells, not pixels: big block letters,
; one cell to a block, in rows 7-11. A sprite's photograph holds only
; pixels, so nothing a sprite saves or puts back can disturb it. A sprite
; crossing it shows in the banner's colours for a moment.
;==============================================================================

; --- the table, from config.asm -----------------------------------------------
; One row: the points that finish the level (BCD, two bytes, low byte
; first), the shortest missile gap, how many values the gap can take
; (max - min + 1), and the bomb's haste: what is added to a fraction
; each 1/50 second, an extra pixel each time it carries. 0 is the old
; 1 pixel per 1/50 second; 64 is a quarter faster. Then the bomb's kind
; (BOMB_P or BOMB_W).
LEVEL_ROW_BYTES equ 6

level_rows = 0
        MACRO LEVEL_ROW need, gmin, gmax, haste, bomb
        ASSERT need >= 1 && need <= 9999, "a level needs 1 to 9999 points"
        ASSERT gmin <= gmax && gmax <= 255 && gmax - gmin + 1 <= 255
        ASSERT haste >= 0 && haste <= 255
        ASSERT bomb == BOMB_P || bomb == BOMB_W
        IF level_rows == 0
        ; The soak plays level 1 and its frame numbers expect the old game.
        ASSERT haste == 0, "level 1's bombs must keep the old speed"
        ASSERT bomb == BOMB_P, "level 1's bomb is the pulsar"
        ASSERT gmin == CFG_MISSILE_GAP_MIN && gmax == CFG_MISSILE_GAP_MAX, "level 1's missile wait is CFG_MISSILE_GAP_*"
        ENDIF
        db (((need % 100) / 10) << 4) | (need % 10)
        db (((need / 1000) % 10) << 4) | ((need / 100) % 10)
        db gmin, gmax - gmin + 1, haste, bomb
level_rows = level_rows + 1
        ENDM

; Points as one BCD byte.
        MACRO PTS_BCD pts
        ASSERT pts >= 0 && pts <= 99, "points are one BCD byte"
        ld a,((pts / 10) << 4) | (pts % 10)
        ENDM

; Level 2's message stops the game until a key is pressed. Builds
; that run on their own (soak, measure, timing, sled, screenshot) leave
; it out: nobody is there to press the key.
    IFNDEF IDLE_HOLD
    IFNDEF MEASURE
    IFNDEF SOAK
        DEFINE TEASER
    ENDIF
    ENDIF
    ENDIF

; --- state ----------------------------------------------------------------------
score:          ds 3            ; BCD, low byte first
hiscore:        ds 3            ; kept while the machine is on
level:          db 1            ; BCD
level_n:        db 1            ; the same, binary, for the codes
start_level:    db 1            ; binary: where the next game starts (codes.asm)
level_row:      dw 0            ; this level's row of level_tab
level_next:     ds 3            ; the score that finishes this level, BCD
level_bomb:     db BOMB_P       ; this level's bomb (wheel_type)

; What row 1 needs. Bit 0 the hearts, bit 1 the words and numbers, bit 2
; the banner's clock. main_loop tests the byte once a step.
hud_dirty:      db 7
HUD_HEARTS      equ 0
HUD_TEXT        equ 1
HUD_BANNER      equ 2

HUD_SCORE_COL   equ 6
HUD_LEVEL_COL   equ 20
HUD_LEN         equ 22
hud_text:       ds HUD_LEN      ; what each cell shows, 0 = not drawn yet
hud_new:        ds HUD_LEN

banner_until:   dw 0            ; frame_count when the banner comes down
banner_col:     db 0            ; its first column
banner_len:     db 0            ; characters in it
banner_chars:   ds 8            ; "LEVEL" and the number
banner_code:    db 0            ; 1 = code_buf goes under it
teaser_due:     db 0            ; 1 = the level 2 message, once the banner is down

        ASSERT HUD_LEN <= LIVES_COL, "the score line runs into the hearts"

;------------------------------------------------------------------------------
; score_reset - a new game: 0 points, level 1, the line to be drawn
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
score_reset:
        xor a
        ld hl,score
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld hl,level_next
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld hl,hud_text          ; every cell differs from 0: all drawn
        ld b,HUD_LEN
.clr:   ld (hl),a
        inc hl
        djnz .clr
        ld (banner_code),a
        ld (teaser_due),a
        inc a
        ld (level),a
        ld (level_n),a
        ld hl,level_tab
        call level_enter
        ; A code: go up to its level quietly, with the score each level
        ; starts at, so the points to the next level are the usual ones.
        ld a,(start_level)
        dec a
        jr z,.go
        ld b,a
.skip:  push bc
        ld hl,level_next
        ld de,score
        ld bc,3
        ldir
        call level_advance
        pop bc
        djnz .skip
.go:    ld a,(1 << HUD_HEARTS) | (1 << HUD_TEXT)
        ld (hud_dirty),a
        ret

;------------------------------------------------------------------------------
; score_add - points for a shot
; In: A = points, one BCD byte. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
score_add:
        ld hl,score
        add a,(hl)
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        daa
        jr nc,.fits
        ld a,$99                ; 999999 stays 999999
        ld (hl),a
        dec hl
        ld (hl),a
        dec hl
.fits:  ld (hl),a
        ld hl,hud_dirty
        set HUD_TEXT,(hl)
        ; Past the target? Compare from the top byte down: BCD orders
        ; like binary. One shot can pass two targets (a missile is worth
        ; more than a small level), so this goes round until it has not.
.check: ld hl,score + 2
        ld de,level_next + 2
        ld b,3
.cmp:   ld a,(de)
        cp (hl)
        jr c,.up                ; target below the score
        ret nz                  ; target above it
        dec hl
        dec de
        djnz .cmp
.up:    ld hl,level_next        ; a target capped at 999999 cannot be
        ld a,(hl)               ; passed again, or this would go round
        inc hl                  ; for ever
        and (hl)
        inc hl
        and (hl)
        cp $99
        ret z
        call level_up           ; equal, or below: reached
        jr .check

;------------------------------------------------------------------------------
; level_up - the target is reached: the next row, the banner, its code,
;            the jingle. Level 2 also gets the message (teaser).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
level_up:
        call level_advance
        ld hl,hud_dirty
        set HUD_TEXT,(hl)
        bit HUD_BANNER,(hl)     ; a banner still up comes down first,
        call nz,banner_erase    ; with its own code line
        ; The code goes under the banner from level 3. Level 2's is in
        ; the message that follows its banner.
        xor a
        ld (banner_code),a
        ld a,(level_n)
        cp 2
        jr nz,.code
    IFDEF TEASER
        ld (teaser_due),a       ; not 0
    ENDIF
        jr .show
.code:  cp CFG_CODE_LEVELS + 1
        jr nc,.show             ; past the last code
        call code_text
        ld a,1
        ld (banner_code),a
.show:  call banner_show
    IFNDEF NO_SOUND
        ld hl,snd_tune_level
        jp snd_tune_start
    ELSE
        ret
    ENDIF

; The next level and its row of the table, without the banner.
; Corrupts: AF, BC, DE, HL
level_advance:
        ld a,(level)
        cp $99
        jr z,.same              ; level 99 is as far as two digits go
        add a,1
        daa
        ld (level),a
        ld hl,level_n
        inc (hl)
.same:  ld hl,(level_row)
        ld de,LEVEL_ROW_BYTES
        add hl,de
        ld de,level_end
        or a
        sbc hl,de
        add hl,de
        jr c,.row
        ld hl,level_end - LEVEL_ROW_BYTES ; past the table: the last row again
.row:   ; fall through

; HL = a row of level_tab. Its target goes on top of the last one, and
; its missile gap and bomb haste take over.
; Corrupts: AF, BC, DE, HL
level_enter:
        ld (level_row),hl
        ld de,level_next
        ld a,(de)
        add a,(hl)
        daa
        ld (de),a
        inc hl
        inc de
        ld a,(de)
        adc a,(hl)
        daa
        ld (de),a
        inc hl
        inc de
        ld a,(de)
        adc a,0
        daa
        ld (de),a
        jr nc,.fits
        ld a,$99                ; a target past 999999 is 999999
        ld (de),a
        dec de
        ld (de),a
        dec de
        ld (de),a
.fits:  ld a,(hl)               ; HL is on the gap after the two need bytes
        ld (msl_gap_min),a
        inc hl
        ld a,(hl)
        ld (msl_gap_span),a
        inc hl
        ld a,(hl)
        ld (wheel_haste),a
        inc hl
        ld a,(hl)
        ld (level_bomb),a
        ret

;------------------------------------------------------------------------------
; score_game_over - the last life: a new high score?
; Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
score_game_over:
        ld hl,score + 2
        ld de,hiscore + 2
        ld b,3
.cmp:   ld a,(de)
        cp (hl)
        jr c,.new
        ret nz
        dec hl
        dec de
        djnz .cmp
        ret
.new:   ld hl,score
        ld de,hiscore
        ld bc,3
        ldir
        ret

;------------------------------------------------------------------------------
; hud_draw - row 1, while no sprite is on the screen
; main_loop calls this only when hud_dirty is not 0, straight after the
; restores. The text redraws only the cells that changed: a shot costs
; one or two digits.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
hud_draw:
        ld hl,hud_dirty
        bit HUD_HEARTS,(hl)
        call nz,lives_draw
        ld hl,hud_dirty
        bit HUD_TEXT,(hl)
        call nz,hud_text_draw
        ld hl,hud_dirty
        bit HUD_BANNER,(hl)
        ret z
        jp banner_tick

hud_text_draw:
        res HUD_TEXT,(hl)
        ; The line as it should be, into hud_new.
        ld hl,str_hud
        ld de,hud_new
        ld bc,HUD_LEN
        ldir
        ld de,hud_new + HUD_SCORE_COL
        ld hl,score + 2
        ld b,3
.sc:    ld a,(hl)
        call hud_bcd_pair
        dec hl
        djnz .sc
        ld de,hud_new + HUD_LEVEL_COL
        ld a,(level)
        cp $10
        jr nc,.two
        add a,'0'               ; one digit, at the column after LEVEL
        ld (de),a
        jr .put
.two:   call hud_bcd_pair
.put:   ; Every cell that differs from what is on the screen.
        ld hl,hud_new
        ld de,hud_text
        ld c,0
.cell:  ld a,(de)
        cp (hl)
        jr z,.next
        ld a,(hl)
        ld (de),a
        push bc
        push de
        push hl
        call hud_glyph
        pop hl
        pop de
        pop bc
.next:  inc hl
        inc de
        inc c
        ld a,c
        cp HUD_LEN
        jr c,.cell
        ret

; A = two BCD digits. Both into (DE) as characters. Preserves BC, HL.
hud_bcd_pair:
        push af
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        pop af
        and 15
        add a,'0'
        ld (de),a
        inc de
        ret

; A = character, C = column of row 1. Eight lines straight from the font.
; Corrupts: AF, DE, HL
hud_glyph:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FONT_BASE
        add hl,de
        ex de,hl
        ld a,low (SCREEN + LIVES_ROW * 32)
        add a,c
        ld l,a
        ld h,high (SCREEN + LIVES_ROW * 32)
        DUP 8
        ld a,(de)
        ld (hl),a
        inc de
        inc h
        EDUP
        ret

;------------------------------------------------------------------------------
; The banner. Block letters three cells wide and five high, a gap of one
; cell between them, centred on rows BANNER_ROW to BANNER_ROW + 4.
;------------------------------------------------------------------------------
BANNER_ROW      equ 7

; Build "LEVEL n", paint it, start its clock. Corrupts: AF, BC, DE, HL
banner_show:
        ld a,(hud_dirty)
        bit HUD_BANNER,a
        call nz,banner_erase    ; a banner still up comes down first
        ld hl,banner_chars
        ld de,str_level
        ld b,5
.word:  ld a,(de)
        ld (hl),a
        inc de
        inc hl
        djnz .word
        ld (hl),' '
        inc hl
        ld a,(level)
        ld c,7
        cp $10
        jr c,.units
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (hl),a
        inc hl
        inc c
        ld a,(level)
.units: and 15
        add a,'0'
        ld (hl),a
        ld a,c
        ld (banner_len),a
        add a,a
        add a,a                 ; four columns a character
        dec a                   ; less the last gap
        ld b,a
        ld a,32
        sub b
        srl a
        ld (banner_col),a
        ld a,BANNER_ATTR
        call banner_paint
        ld hl,(frame_count)
        ld de,CFG_BANNER_TIME
        ld a,(banner_code)
        or a
        jr z,.time
        ld de,CFG_BANNER_CODE_TIME ; longer, to read the code
.time:  add hl,de
        ld (banner_until),hl
        ld hl,hud_dirty
        set HUD_BANNER,(hl)
        ret

; Each step while it is up: time to take it down? After level 2's,
; the message, at the end of this step.
banner_tick:
        ld hl,(frame_count)
        ld de,(banner_until)
        or a
        sbc hl,de
        ret c
    IFDEF TEASER
        call banner_erase
        ld a,(teaser_due)
        or a
        ret z
        xor a
        ld (teaser_due),a
        ld hl,teaser
        ld (teaser_hook+1),hl   ; main_loop's call to spare_count
        ret
    ENDIF
        ; fall through

banner_erase:
        ld hl,hud_dirty
        res HUD_BANNER,(hl)
        ld a,WATER_ATTR
        ; fall through

; A = the attribute for every block of the letters. The cells between
; the blocks are not touched. Afterwards the bomb is told to paint its
; own cells again, in case the banner covered them.
; Corrupts: AF, BC, DE, HL
banner_paint:
        ld (banner_ink),a
        ld a,BANNER_ROW
        ld (banner_row),a
        ld a,(banner_col)
        ld c,a
        ld hl,banner_chars
        ld a,(banner_len)
        ld b,a
        call banner_line
        ld a,(banner_code)
        or a
        jr z,banner_bomb
        ld a,BANNER_ROW + 6     ; the code, a row of cells under it
        ld (banner_row),a
        ld c,(32 - CODE_LEN * 4 + 1) / 2
        ld hl,code_buf
        ld b,CODE_LEN
        call banner_line
banner_bomb:
        ld a,(wheel_attr_n)
        or a
        ret z
        xor a
        ld (wheel_shown),a      ; not the ink: the bomb repaints its cells
        ret

; HL = characters, B = how many, C = the first column; (banner_row).
banner_line:
.char:  push bc
        push hl
        ld a,(hl)
        call banner_glyph       ; DE -> five rows of three bits
        ld a,(banner_row)
        ld b,a
.row:   push bc
        call attr_addr          ; HL -> the row's first cell of this letter
        ld a,(de)
        inc de
        rlca
        rlca
        rlca
        rlca
        rlca                    ; bit 2 (the left block) into bit 7
        ld b,3
.blk:   rlca
        jr nc,.skip
        push af
        ld a,(banner_ink)
        ld (hl),a
        pop af
.skip:  inc hl
        djnz .blk
        pop bc
        inc b
        ld a,(banner_row)
        add a,5
        cp b
        jr nz,.row
        pop hl
        pop bc
        inc hl
        ld a,c
        add a,4
        ld c,a
        djnz .char
        ret

banner_ink:     db 0
banner_row:     db 0

; A = a capital letter, ' ' or a digit. Out: DE -> its five rows.
; Corrupts: AF, HL
banner_glyph:
        ld de,banner_font_sp
        cp ' '
        ret z
        ld de,banner_font_0
        sub '0'
        cp 10
        jr c,.got
        ld de,banner_font_a
        sub 'A' - '0'
.got:   ld l,a
        add a,a
        add a,a
        add a,l                 ; *5
        ld l,a
        ld h,0
        add hl,de
        ex de,hl
        ret

    IFDEF TEASER
;------------------------------------------------------------------------------
; teaser - level 2's message, until a key is pressed
; banner_tick points main_loop's call to spare_count here for one step,
; once level 2's banner is down. So it comes at the end of a step, with
; the sprites on the screen, and the picture stays still behind the
; panel for as long as the player likes: time for a screenshot. Then
; the panel's rows go back to empty water. Every sprite photographed
; water there this step, so the next restores and draws find what they
; expect. The step after it is late, once.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
TEASE_ROW       equ 6
TEASE_ROWS      equ 9

teaser:
        ld hl,spare_count
        ld (teaser_hook+1),hl   ; this step only
        ld a,TEASE_ATTR
        call teaser_fill
        ld (text_attr),a
        ld hl,str_tease_1
        ld bc,((TEASE_ROW + 1) << 8) | 0
        call print_string
        ld hl,str_tease_2
        ld bc,((TEASE_ROW + 3) << 8) | 3
        call print_string
        ld hl,str_tease_key
        ld bc,((TEASE_ROW + 7) << 8) | 10
        call print_string
        ld a,2
        call code_text          ; before the row goes in B
        ld hl,str_code_word
        ld bc,((TEASE_ROW + 5) << 8) | 10
        call print_string
        ld a,TEASE_CODE_ATTR
        ld (text_attr),a
        ld hl,code_buf
        call print_string
        call keys_up            ; he is holding a direction, or fire
.wait:  call wait_frame
        call any_key
        jr z,.wait
        call keys_up            ; the key that ended it does not fire
        ld a,WATER_ATTR
        call teaser_fill
        call banner_bomb        ; the bomb's ink, if the panel covered it
        jp spare_count

; A = attribute for the panel's rows, whose pixels are cleared.
; Corrupts: F, BC, DE, HL
teaser_fill:
        ld hl,ATTRS + TEASE_ROW * 32
        ld de,ATTRS + TEASE_ROW * 32 + 1
        ld bc,TEASE_ROWS * 32 - 1
        ld (hl),a
        ldir
        push af
        ld b,TEASE_ROW
.row:   push bc
        ld c,0
        call char_addr
        ld c,8
.line:  push hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        push bc
        ld bc,31
        ldir
        pop bc
        pop hl
        inc h
        dec c
        jr nz,.line
        pop bc
        inc b
        ld a,b
        cp TEASE_ROW + TEASE_ROWS
        jr c,.row
        pop af
        ret
    ENDIF
