;==============================================================================
; death.asm - the diver's death: the game stops, he flashes, he blows up
;
; A hit (bomb, fish, missile or the black ground) used to cost a life
; and put him back at the left edge on the same step. Now the step
; stops at the hit and the game freezes:
;   - Nothing moves and the seabed does not scroll. main_loop's two
;     jumps (step_jp_shift, step_jp_move) are pointed past the shifts
;     and at death_step instead of the moves, so each step only
;     restores, draws and copies the seabed: the 25 picture frame's
;     work. Every sprite is drawn where it stopped. A burst already
;     going (the bomb's, the fish's) plays out, and so does the border.
;   - A moment later (DEATH_SAVE_AT) his cells flash through four inks,
;     for CFG_DEATH_FLASH 1/50 seconds. The moment lets the colours that
;     were already changing finish: a bomb that hit him clears its cells
;     on the next step, and a fish he touched flashes its own for four.
;     Then his cells hold only colours that stay, and those are the ones
;     kept and put back.
;   - Then they get their own colours back, he is taken off the screen,
;     and a burst goes off where he was.
;   - CFG_DEATH_TIME after the hit, the life is taken. With one left he
;     comes back at the left edge and the game goes on; with none, it is
;     GAME OVER, as before.
; A long, deep rumble (snd_diver_start) plays all through it.
;
; The frozen step runs at 50 at both speeds: step_ticks is 1 and the
; sound gate open while it lasts, and rate_apply puts the speed back at
; the end. So a death looks and sounds the same at 50 and 25. The
; frozen step does less than a game step, so it is never late.
;
; Nothing scores while he is dying, so the LEVEL banner's clock stops
; too: it stays up, and comes down as long after he is back as it had
; left when he was hit. Level 2's message waits for it, so it never
; opens over a death.
;
; All of this is in the cold block: it runs only while the game is
; stopped, and the frozen step has plenty of time to spare.
;==============================================================================

death_t:        db 0            ; 1/50 seconds since the hit; 0 = alive
death_lift:     db 0            ; 1 = he comes back at the starting depth
death_hidden:   db 0            ; 1 = diver_draw_fast is patched out
death_banner:   db 0            ; HUD_BANNER as it was at the hit
death_start:    dw 0            ; frame_count at the hit
death_row:      db 0            ; his cells: the first row and column,
death_col:      db 0
death_rows:     db 0            ; and how many of each
death_cols:     db 0
death_code:     ds 3            ; diver_draw_fast's first instruction
death_attrs:    ds 4 * 3        ; the colours under him, row by row

; The flash: one ink for 4/50 seconds each, round and round. Each cell
; keeps its paper and brightness.
death_inks:     db RED, YELLOW, MAGENTA, CYAN

; His cells go no lower than row 22. Row 23 is the black ground, which
; he never reaches.
DEATH_LAST_ROW  equ BACK_ROW + 1
DEATH_SAVE_AT   equ FISH_FLASHES + 2
DEATH_BOOM_AT   equ DEATH_SAVE_AT + CFG_DEATH_FLASH

        ASSERT CFG_DEATH_FLASH >= 1
        ASSERT CFG_DEATH_TIME > DEATH_BOOM_AT + BOOM_HOLD, "the burst would not finish before he comes back"
        ASSERT CFG_DEATH_TIME <= 255
        ASSERT CFG_DIVER_SND_FRAMES <= CFG_DEATH_TIME, "the rumble would go on after he is back"
        ASSERT diver_draw_fast.patched - diver_draw_fast == 3, "death_hide covers one 3-byte instruction"
        ASSERT DIVER_WIDTH == 24 && DIVER_HEIGHT <= 17, "death_attrs holds 4 by 3 cells"

;------------------------------------------------------------------------------
; death_hit  - main_loop's hit exit at 50, from inside step_move
; death_begin - the same from idle_tick at 25; it returns to main_loop
; Starts the death. Nothing has moved since the hit, so where he is now
; is where he stays.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
death_hit:
        call death_begin
        jp step_moved

death_begin:
        ld a,1
        ld (death_t),a
        call death_freeze
    IFNDEF NO_SOUND
        call snd_diver_start
    ENDIF
        ld hl,(frame_count)
        ld (death_start),hl
        ld hl,hud_dirty         ; stop the banner's clock
        ld a,(hl)
        and 1 << HUD_BANNER
        ld (death_banner),a
        res HUD_BANNER,(hl)

        ; His cells. x and y are where he is drawn from now on.
        ld a,(diver_x)
        ld b,a
        rrca
        rrca
        rrca
        and 31
        ld (death_col),a
        ld a,b
        and 7
        add a,DIVER_WIDTH + 7
        rrca
        rrca
        rrca
        and 31
        ld (death_cols),a       ; 3, or 4 when he is not on a byte
        ld a,(diver_y)
        ld b,a
        rrca
        rrca
        rrca
        and 31
        ld (death_row),a
        ld a,b
        and 7
        add a,DIVER_HEIGHT + 7
        rrca
        rrca
        rrca
        and 31
        ld c,a                  ; 2 or 3 rows
        ld a,(death_row)
        add a,c
        sub DEATH_LAST_ROW + 1  ; rows past row 22
        jr c,.fits
        ld b,a
        ld a,c
        sub b
        ld c,a
.fits:  ld a,c
        ld (death_rows),a
        ret

; The colours under him into death_attrs.
; Corrupts: AF, BC, DE, HL
death_save:
        call death_corner
        ld de,death_attrs
.row:   push bc
        push hl
        ld a,(death_cols)
        ld b,a
.cell:  ld a,(hl)
        ld (de),a
        inc de
        inc hl
        djnz .cell
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        djnz .row
        ret

; Out: HL = the attribute of his top-left cell, B = rows. Corrupts: AF, C
death_corner:
        ld a,(death_row)
        ld b,a
        ld a,(death_col)
        ld c,a
        call attr_addr
        ld a,(death_rows)
        ld b,a
        ret

;------------------------------------------------------------------------------
; death_paint - C = an ink for each of his cells, or $FF for the colours
;               they had at the hit
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
death_paint:
        push bc
        call death_corner
        pop de
        ld a,e
        ld c,a                  ; C = the ink again
        ld de,death_attrs
.row:   push bc
        push hl
        ld a,(death_cols)
        ld b,a
.cell:  ld a,c
        cp $FF
        ld a,(de)
        jr z,.put               ; the saved colour as it was
        and %11111000           ; its paper and brightness, a new ink
        or c
.put:   ld (hl),a
        inc de
        inc hl
        djnz .cell
        pop hl
        push bc
        ld bc,32
        add hl,bc
        pop bc
        pop bc
        djnz .row
        ret

;------------------------------------------------------------------------------
; death_freeze - every step from now on only draws, at 50
; death_begin calls it, and rate_apply again if the speed is changed
; during the death.
; Corrupts: AF, HL
;------------------------------------------------------------------------------
death_freeze:
        ld a,1
        ld (step_ticks),a
    IFNDEF NO_SOUND
        ld (snd_gate),a
    ENDIF
        ld hl,step_skip
        ld (step_jp_shift+1),hl
        ld hl,death_step
        ld (step_jp_move+1),hl
        ret

;------------------------------------------------------------------------------
; death_step - main_loop's jump in place of the moves, while he dies
; Every sprite has been drawn for this step.
;------------------------------------------------------------------------------
death_step:
    IFNDEF NO_SOUND
        ; At 25 main_loop shut the gate after the idle frame that held
        ; the hit. Every frozen step is a 50 step: open.
        ld a,1
        ld (snd_gate),a
    ENDIF
        ld a,(death_t)
        cp DEATH_SAVE_AT
        jr c,.next              ; the other colours settle first
        call z,death_save
        ld a,(death_t)
        cp DEATH_BOOM_AT
        jr c,.flash
        jr z,.boom
        cp CFG_DEATH_TIME
        jr nc,death_end
.next:  inc a
        ld (death_t),a
        jp step_moved

.flash: rrca
        rrca
        and 3                   ; a new ink every 4 steps
        ld e,a
        ld d,0
        ld hl,death_inks
        add hl,de
        ld c,(hl)
        call death_paint
        ld a,(death_t)
        jr .next

        ; His colours back, and he goes. The next restore takes him off
        ; the screen with the rest, and the burst is drawn on the water
        ; under the sprites, as every burst is (boom.asm).
.boom:  ld c,$FF
        call death_paint
        call death_hide
        call boom_at_diver
        ld a,(death_t)
        jr .next

; The life is taken. Jumped to from main_loop, so game_over can be too.
death_end:
        call death_reset        ; his draw back, the speed's own jumps
        ld a,DIVER_HIT_X        ; one column in from the left edge
        ld (diver_x),a
        ld a,(death_lift)
        or a
        jr z,.depth
        xor a
        ld (death_lift),a
        ld a,DIVER_START_Y      ; off the black ground
        ld (diver_y),a
.depth: ld a,(death_banner)
        or a
        jr z,.lives
        ; The banner's clock goes on from where it stopped.
        ld hl,(frame_count)
        ld de,(death_start)
        or a
        sbc hl,de               ; how long he took to die
        ld de,(banner_until)
        add hl,de
        ld (banner_until),hl
        ld hl,hud_dirty
        set HUD_BANNER,(hl)
.lives: ld hl,hud_dirty
        set HUD_HEARTS,(hl)     ; the hearts on row 1 need drawing again
        ld hl,lives
        dec (hl)
        jp z,game_over
        jp step_moved

;------------------------------------------------------------------------------
; death_hide - diver_draw_fast does nothing but drop his photograph
; death_reset - his draw back, no death, and main_loop's jumps and
;               step_ticks as the speed has them. game_reset calls it
;               too, so Symbol Shift + P in the middle of a death does
;               not leave the next game frozen.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
death_hide:
        ld hl,diver_draw_fast
        ld de,death_code
        ld bc,3
        ldir                    ; its first instruction, kept
        ld a,$C3                ; JP diver_draw_none
        ld (diver_draw_fast),a
        ld hl,diver_draw_none
        ld (diver_draw_fast + 1),hl
        ld a,1
        ld (death_hidden),a
        ret

death_reset:
        xor a
        ld (death_t),a          ; before rate_apply, which reads it
        ld a,(death_hidden)
        or a
        jr z,.rate
        xor a
        ld (death_hidden),a
        ld hl,death_code
        ld de,diver_draw_fast
        ld bc,3
        ldir
.rate:  ld a,(game_rate)
        jp rate_apply

; In diver_draw_fast's place while he is gone. The restore before it
; has just taken him off the screen: drop the photograph, so the next
; restores do not paint him back over the burst.
diver_draw_none:
        ld iy,diver_bg
        ld (iy+BG_VALID),0
        ret
