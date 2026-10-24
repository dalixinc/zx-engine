;==============================================================================
; stats.asm - the debug line, as an overlay on row 0
;
; Off until Symbol Shift + S. The chord is edge-triggered: the moment it
; goes down, the line flips, and holding the keys does not flip it again.
; S on its own is not the chord.
;
; The line is one row of 32 cells, in ordinary decimal, with the words
; left in place and only the digits rewritten:
;
;   scan 12 50/s x160 y090 L3 f65535
;
;   scan   spare scanlines in the last step. How many television lines
;          were left after the work. 99 is the most the two digits show.
;   50/s   the speed, 50 or 25 frames a second
;   x y    the diver, in pixels
;   L      lives left
;   f      television frames since the game started (the interrupt count)
;
; It fits on the one row. A second row is not used.
;
; The words are drawn once, when the line is turned on. The numbers are
; reprinted from the real counters once every eight steps. Seven steps
; leave the digits as they are. The eighth prints the spare count, the
; speed, the diver, the lives and the frame count, and skips a digit
; that has not changed.
;
; That eighth step is a full reprint. It is more time than the frame
; which copies the seaweed has left, so the picture can miss one
; television frame while the line is on. The line is a debug display
; and it starts off. With it off, none of this work runs.
;
; ORDER, and why a sprite on row 0 does not eat the digits
; The sprite's background record is a photograph of the screen at the
; moment of the save. If the digits are in that photograph, the next
; restore paints them back wherever the sprite has moved.
;
; So the photograph is taken with the digits OFF the cells the sprite
; covers. The other cells stay, so the beam can still read them. The
; covered cells are drawn again on top of the sprite.
;
;   no sprite on row 0
;       The digits stay up. Changed digits are rewritten at the END,
;       after the beam has passed row 0.
;   a sprite is on row 0
;       Only that sprite's columns are wiped, after the old sprite is
;       restored and before the new one is saved. Those columns are
;       drawn again as soon as the sprite is on screen.
;
; Turning the line off wipes the row. With a sprite on it, the wipe is
; before the sprite is drawn, so the sprite's own pixels are not wiped.
;==============================================================================

STATS_ROW       equ 0

stats_on:       db 0            ; 1 = the line is in use
stats_dirty:    db 0            ; 1 = digit pixels are on the screen now
stats_template_up: db 0         ; 1 = the words have been drawn this time
stats_chord_prev: db 0          ; last frame's chord, for the edge

; What is actually on each cell. A draw is skipped when the new character
; is the one already stored here. 32 bytes, one per column.
stats_screen:   ds 32

; One bit per column. Set when a sprite wiped that column and it has to
; be drawn again even though the character has not changed. Four bytes
; is 32 bits, and clearing them is four stores, not a walk of the row.
stats_force:    ds 4

; Last value actually written into the digits. 255 means "not yet",
; so the first update after the words are drawn always fills them.
stats_prev_spare: db 255
stats_prev_x:   db 255
stats_prev_y:   db 255
stats_prev_rate: db 255
stats_prev_lives: db 255

; Counts 0 to 7. The numbers are reprinted when this lands on 0.
; It starts at 7 so the first step after the words are drawn fills them.
stats_phase:    db 7

; Remember the chord as it is now, so a key that is already down when
; play starts does not flip the line at once.
stats_arm:
        call stats_key_sym
        ld e,a
        call stats_key_s
        and e
        ld (stats_chord_prev),a
        ret

; Out: A nonzero if that key is down. Corrupts: AF, BC.
; The two keys are on different half-rows, so this is not a ghost.
; Bit 1 of the space row is Symbol Shift. Bit 1 of the A row is S.
; A key reads as 0 when it is down.
stats_key_sym:
    IFDEF SOAK
        ld a,(soak_sym)         ; $FF = really read the keyboard
        cp $FF
        jr z,.hw
        ret                     ; soak passed 0 or 1
.hw:
    ENDIF
        ld bc,ROW_SPC_B * 256 + ULA_PORT
        in a,(c)
        cpl
        and %00000010
        ret

stats_key_s:
    IFDEF SOAK
        ld a,(soak_s)
        cp $FF
        jr z,.hw
        ret
.hw:
    ENDIF
        ld bc,ROW_A_G * 256 + ULA_PORT
        in a,(c)
        cpl
        and %00000010
        ret

;------------------------------------------------------------------------------
; stats_prepare - after the sprite restores, before any sprite save
; If the line is being turned off and a sprite covers row 0, wipe the
; whole line now so the photograph is water and the sprite is drawn
; onto water. If the line stays on, wipe only the sprite's columns.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
stats_prepare:
        ; Hidden, and nothing left on the row: the four force bytes are
        ; already clear. Touching them on that frame was time the seabed
        ; copy does not have.
        ld a,(stats_dirty)
        or a
        ret z
        xor a
        ld hl,stats_force
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld a,(stats_on)
        or a
        jr z,.turning_off
        call stats_sprite_on_row0
        ret z
        jp stats_erase_sprites
.turning_off:
        call stats_sprite_on_row0
        ret z
        call stats_erase_all
        xor a
        ld (stats_template_up),a
        ret

;------------------------------------------------------------------------------
; stats_overlay_if_row0 - draw now if a sprite covers row 0
; Call once the sprites that can stand on row 0 have been drawn.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
stats_overlay_if_row0:
        ld a,(stats_on)
        or a
        jr nz,.look
        ld a,(stats_template_up)
        or a
        ret z                   ; hidden, and the row is already water
.look:  call stats_sprite_on_row0
        ret z
        jp stats_finish

;------------------------------------------------------------------------------
; stats_overlay_if_clear - refresh at the end of the step
; Used when no sprite covered row 0. A digit that is due is overwritten
; after the beam has left the row.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
stats_overlay_if_clear:
        ld a,(stats_on)
        or a
        jr nz,.look
        ld a,(stats_template_up)
        or a
        ret z
.look:  call stats_sprite_on_row0
        ret nz                  ; the early call already drew them
        jp stats_finish

; Draw if the overlay is on, and remember whether pixels were left behind.
stats_finish:
        ld a,(stats_on)
        or a
        jr z,.off
        ld a,(stats_template_up)
        or a
        call z,stats_draw_template
        call stats_update_numbers
        call stats_redraw_forced
        ld a,1
        ld (stats_dirty),a
        ld (stats_template_up),a
        ret
.off:   ld a,(stats_template_up)
        or a
        call nz,stats_erase_all
        xor a
        ld (stats_template_up),a
        ld (stats_dirty),a
        ret

;------------------------------------------------------------------------------
; stats_sprite_on_row0 - Z set if no sprite intersects pixel rows 0..7
; A sprite intersects row 0 when its top y is 0..7. The wheel also has
; to be on screen: during the pause, or while it is still off the right
; edge, its y may be up there without a pixel to photograph.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
stats_sprite_on_row0:
        ld a,(diver_y)
        cp 8
        jr c,.hit
        ld a,(fish_y)
        cp 8
        jr c,.hit
        call wheel_on_row0      ; Z if the bomb is not on row 0
        ret nz
        xor a
        ret
.hit:   ld a,1                  ; Z clear
        or a
        ret

;------------------------------------------------------------------------------
; The digits
;------------------------------------------------------------------------------

; Words once. The zeros are the placeholders stats_update_numbers fills.
stats_draw_template:
        ld hl,stats_template
        ld c,0
.col:   ld a,(hl)
        push hl
        call stats_put_force
        pop hl
        inc hl
        inc c
        ld a,c
        cp STATS_TEMPLATE_LEN
        jr c,.col
        ; The placeholders are on screen. The next update fills them
        ; from the real numbers, instead of trusting a stale copy.
        ld a,255
        ld (stats_prev_spare),a
        ld (stats_prev_x),a
        ld (stats_prev_y),a
        ld (stats_prev_rate),a
        ld (stats_prev_lives),a
        ld a,7
        ld (stats_phase),a
        ret

stats_update_numbers:
        ; Seven steps leave the digits alone. The eighth reprints them
        ; from the real numbers. Doing that every step costs more than
        ; the seaweed-copy frame has left. The line is a debug display,
        ; so the eighth step is allowed to miss a television frame.
        ld a,(stats_phase)
        inc a
        and 7
        ld (stats_phase),a
        ret nz
        ; A digit that already matches the screen is left alone. The
        ; frame counter still has to be worked out, because it moves.
        ld a,(spare_lines)
        ld hl,stats_prev_spare
        cp (hl)
        jr z,.xpos
        ld (hl),a
        call stats_spare_digits
.xpos:  ld a,(diver_x)
        ld hl,stats_prev_x
        cp (hl)
        jr z,.ypos
        ld (hl),a
        ld c,14
        call stats_dec3
.ypos:  ld a,(diver_y)
        ld hl,stats_prev_y
        cp (hl)
        jr z,.rate
        ld (hl),a
        ld c,19
        call stats_dec3
.rate:  ; 50 or 25. Two stores, and only when the speed actually flips.
        ld a,(game_rate)
        ld hl,stats_prev_rate
        cp (hl)
        jr z,.lives
        ld (hl),a
        cp 25
        ld a,'5'
        jr nz,.fifty
        ld a,'2'
.fifty: ld c,8
        call stats_put
        ld a,(game_rate)
        cp 25
        ld a,'0'
        jr nz,.runits
        ld a,'5'
.runits:ld c,9
        call stats_put
.lives: ; One digit. CFG_LIVES is at most 9.
        ld a,(lives)
        ld hl,stats_prev_lives
        cp (hl)
        jr z,.frame
        ld (hl),a
        add a,'0'
        ld c,24
        call stats_put
.frame: ; The real counter. Digits that already match the screen are
        ; left alone, so this usually redraws one digit of the count.
        ld hl,(frame_count)
        ld c,27
        jp stats_dec5

; A = spare count, 0..99. Both digits, columns 5 and 6.
; Used on the sand frame, which has the time for an ordinary call.
stats_spare_digits:
        ld b,0
.tens:  cp 10
        jr c,.ones
        sub 10
        inc b
        jr .tens
.ones:  push af
        ld a,b
        add a,'0'
        ld c,5
        call stats_digit9
        pop af
        add a,'0'
        ld c,6
        jp stats_digit9

; A = character (a digit), C = column. Store the mirror and draw row 0.
; The eight pixel bytes go on with the short increment: a digit's bytes
; sit inside one 256-byte page of the font, so the low byte is enough.
; Corrupts AF, DE, HL. BC kept.
stats_digit9:
        push bc
        ld b,0
        ld hl,stats_screen
        add hl,bc
        ld (hl),a
        sub '0'
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FONT_BASE + '0' * 8
        add hl,de
        ex de,hl
        ld h,high SCREEN
        ld l,c
        dup 8
        ld a,(de)
        ld (hl),a
        inc e
        inc h
        edup
        pop bc
        ret

; A = 0..99, C = column of the tens digit.
stats_dec2:
        ld b,0
.tens:  cp 10
        jr c,.ones
        sub 10
        inc b
        jr .tens
.ones:  push af
        ld a,b
        add a,'0'
        call stats_put
        pop af
        add a,'0'
        inc c
        jp stats_put

; A = 0..255, C = column of the hundreds digit.
stats_dec3:
        ld b,0
.hund:  cp 100
        jr c,.rest
        sub 100
        inc b
        jr .hund
.rest:  push af
        push bc
        ld a,b
        add a,'0'
        call stats_put
        pop bc
        pop af
        inc c
        jr stats_dec2

; HL = value, C = column of the first of five digits.
stats_dec5:
        ld de,10000
        call .digit
        ld de,1000
        call .digit
        ld de,100
        call .digit
        ld de,10
        call .digit
        ld a,l
        add a,'0'
        jp stats_put
.digit: ld a,'0'
.sub:   or a
        sbc hl,de
        jr c,.undo
        inc a
        jr .sub
.undo:  add hl,de
        push hl
        push de
        push bc
        call stats_put
        pop bc
        pop de
        pop hl
        inc c
        ret

; Draw A at column C if that cell is not already showing it.
; Picture only: the cell is already the water colour, and writing the
; attribute again is wasted time. A sprite that wiped the cell is drawn
; again afterwards by stats_redraw_forced, so this does not look at the
; force bits. Doing that here, on all fifteen digits, was most of the
; cost of the line. Corrupts AF, DE, HL. BC kept.
stats_put:
        push bc
        ld b,0
        ld hl,stats_screen
        add hl,bc
        cp (hl)
        jr z,.same
        ld (hl),a
        pop bc
        push bc
        ld b,STATS_ROW
        call stats_glyph
        pop bc
        ret
.same:  pop bc
        ret

; The template pass. The screen was blank, whatever the mirror remembers.
stats_put_force:
        push bc
        ld b,0
        ld hl,stats_screen
        add hl,bc
        ld (hl),a
        pop bc
        push bc
        ld b,STATS_ROW
        call stats_glyph
        pop bc
        ret

; In: A = ASCII, BC = row/column. Does not advance C.
stats_glyph:
        push bc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; *8, bytes per glyph
        ld de,FONT_BASE
        add hl,de
        ex de,hl
        ; Row 0 only. Its first pixel line is $4000 plus the column, and
        ; the next line is 256 bytes on. char_addr works that out for any
        ; row; doing it here saves the call on the digit that changes
        ; every frame.
        ld h,high SCREEN
        ld l,c
        dup 8
        ld a,(de)
        ld (hl),a
        inc de
        inc h                   ; next pixel inside this cell
        edup
        pop bc
        ret

; Z clear if column C was wiped by a sprite this step.
stats_col_forced:
        push af
        ld a,c
        and 7
        ld b,a
        ld a,1
        jr z,.bit
.rot:   add a,a
        djnz .rot
.bit:   ld b,a
        ld a,c
        rrca
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,stats_force
        add hl,de
        ld a,(hl)
        and b
        pop de                  ; drop the saved character; the flag stays
        ret

; Any column whose force bit is set is drawn from the mirror. Skipped
; entirely when no sprite wiped a column, which is the ordinary frame.
stats_redraw_forced:
        ld a,(stats_force)
        ld hl,stats_force+1
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        ret z
        ld c,0
.col:   push bc
        call stats_col_forced
        jr z,.next
        ld hl,stats_screen
        ld b,0
        add hl,bc
        ld a,(hl)
        ld b,STATS_ROW
        call stats_glyph
.next:  pop bc
        inc c
        ld a,c
        cp 32
        jr c,.col
        ret

;------------------------------------------------------------------------------
; Wiping pixels. Zero is the water on row 0.
;------------------------------------------------------------------------------

stats_erase_all:
        xor a
        call row_table_entry
        ld b,8
.row:   ld l,(ix+0)
        ld h,(ix+1)
        push bc
        ld b,32
        xor a
.col:   ld (hl),a
        inc l
        djnz .col
        pop bc
        inc ix
        inc ix
        djnz .row
        ; The mirror no longer matches the screen.
        ld hl,stats_screen
        ld b,32
        xor a
.mir:   ld (hl),a
        inc hl
        djnz .mir
        ret

; Columns a sprite on row 0 is about to photograph.
; The photograph is wider than the picture. A shifted row keeps a spare
; byte, so the fish (16 pixels) is stored as 3 bytes and the diver (24
; pixels) as 4. Wiping only the visible pixels leaves that spare byte
; holding a digit, and the next restore paints the digit somewhere else.
stats_erase_sprites:
        ld a,(diver_y)
        cp 8
        jr nc,.fish
        ld a,(diver_x)
        ld c,a
        ld b,DIVER_BYTES
        call stats_erase_bytes
.fish:  ld a,(fish_y)
        cp 8
        jr nc,.wheel
        ld a,(fish_x)
        ld c,a
        ld b,FISH_BYTES
        call stats_erase_bytes
.wheel: ld a,(wheel_phase)
        or a
        ret z
        ld a,(wheel_y)
        cp 8
        ret nc
        ld hl,(wheel_x)
        bit 7,h
        jr nz,.wneg
        ld a,h
        or a
        ret nz                  ; still off the right
        ld a,l
        ld c,a
        ld b,WHEEL_BYTES
        jp stats_erase_bytes
.wneg:  ; Hanging off the left. The stored bytes are the ones still on
        ; the screen, starting at column 0. Three is the widest the
        ; picture gets, and wiping a water column costs nothing.
        ld de,WHEEL_WIDTH
        add hl,de
        bit 7,h
        ret nz                  ; fully off the left
        ld a,h
        or l
        ret z
        ld c,0
        ld b,WHEEL_BYTES
        jp stats_erase_bytes

; C = pixel x, B = how many bytes the photograph stores.
; The first column is x divided by 8. The last is that plus the byte
; count, and it is held at column 31.
stats_erase_bytes:
        ld a,c
        rrca
        rrca
        rrca
        and 31
        ld c,a
        add a,b
        dec a
        cp 32
        jr c,.last
        ld a,31
.last:  ld b,a
        jp stats_erase_range

; C = first column, B = last column, inclusive.
stats_erase_range:
        ld a,c
        cp b
        jr z,.one
        jr c,.go
        ret                     ; first past last: nothing
.go:    call stats_mark
        call stats_erase_col
        inc c
        jr stats_erase_range
.one:   call stats_mark
        ; fall through

; C = column. Eight pixel bytes, the height of the row.
; The caller is walking columns, and it keeps the last column in B.
; The eight-row count needs a counter too, so B is put aside and put
; back. Dropping it made the walk stop after the first column, and the
; fish then photographed the digit in the column it had just swum into.
stats_erase_col:
        push bc
        xor a
        call row_table_entry
        ld b,8
.row:   ld l,(ix+0)
        ld h,(ix+1)
        ld a,l
        add a,c
        ld l,a
        xor a
        ld (hl),a
        inc ix
        inc ix
        djnz .row
        pop bc
        ret

; Set the force bit for column C.
stats_mark:
        push bc
        ld a,c
        and 7
        ld b,a
        ld a,1
        jr z,.bit
.rot:   add a,a
        djnz .rot
.bit:   ld b,a
        ld a,c
        rrca
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,stats_force
        add hl,de
        ld a,b
        or (hl)
        ld (hl),a
        pop bc
        ret
