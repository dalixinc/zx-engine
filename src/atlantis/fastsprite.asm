;==============================================================================
; fastsprite.asm - a tighter sprite walker, Atlantis only
;
; The shared routines in src/sprite.asm are written to be clear. Every
; pixel row they look the row address up in the table, save the row
; counter, and then walk the bytes one at a time with a loop. A masked
; byte in that loop is about 57 T-states, and a 16 by 16 wheel pays it
; three times (put the background back, photograph the new background,
; draw). That came to about 60 scanlines. The seabed frame only had 7
; scanlines to spare, so the picture missed the interrupt, the loop ran
; twice per picture, and the bomb flickered.
;
; This file does the same three jobs with less bookkeeping. The 12 by
; 12 wheel below, and the fish and the diver on this build, are what
; brought the frame back inside one interrupt. One seabed frame was
; still short by less than a scanline after that. The time was in the
; scroll rotate (a call and a saved row count on every row), which is
; fixed in scroll.asm. The measured spare is in docs/SCROLLING.md.
;
;   * The next pixel line down, inside one character cell, is one add
;     to the high byte of the screen address. The row-address table is
;     read once per sprite, not once per line. See NEXT_LINE.
;   * Each width (1, 2, 3 or 4 bytes) is written out in full, so there
;     is no per-byte loop.
;   * The fish and the diver on this build use it too. They are on
;     screen every frame, so the time they give back is what leaves
;     spare scanlines once the wheel is drawn as well.
;
; Engine Demo 1 does not include this file. The fish and the diver
; there still call sprite_save_bg, sprite_restore_bg and sprite_draw,
; and that tape is unchanged.
;
; The background record is the same shape as sprite_save_bg writes:
; valid, y, column, height, bytes, then the visible bytes row by row.
; Restore puts back exactly those bytes. A sprite that is half off the
; screen has already had its column and its byte count reduced to the
; part that is visible, so this walker never writes past column 31.
;
; The interrupt handler only saves the accumulator and HL. These
; routines keep the screen pointer in DE. C holds the low byte of that
; address across a row: the byte copy increments E, and copying E back
; from C puts the column back. A push and a pop would do the same and
; costs more. The handler does not touch C or DE.
;==============================================================================

;------------------------------------------------------------------------------
; NEXT_LINE - DE = the next pixel row down, same column
;
; The eight pixel lines of a character cell sit 256 bytes apart, so
; adding 1 to D steps to the next line inside the cell. After the
; eighth line that add also bumps the bit that says which third of the
; screen we are in. That bump is only correct when the character row
; wrapped as well (we really have entered the next third).
;
; If the low three bits of D are not zero, we are still inside the
; cell and there is nothing else to do. If they are zero, we wrapped:
; adding 32 to E steps to the next character row. A carry from that add
; means the character row wrapped too, so the bump of D stays. No carry
; means we are still in the same third, and 8 is subtracted from D to
; undo the bump.
;
; E must be the column we started the row on. The caller copies it to
; C before the byte copy and copies it back before this runs.
; Written out at each row, rather than called: a call and a return are
; most of the cost of the common case, which is the seven lines that
; stay inside the cell. Corrupts: AF.
;------------------------------------------------------------------------------
        MACRO NEXT_LINE
        inc d
        ld a,d
        and 7
        jr nz,.cell@
        ld a,e
        add a,32
        ld e,a
        jr c,.cell@
        ld a,d
        sub 8
        ld d,a
.cell@:
        ENDM

; A full-width wheel is 3 bytes by 12 rows. That is the frame that was
; missing the interrupt: the two-byte shifts already fitted. The fish
; is 3 bytes too, but only 9 rows, so it keeps the counted loop below.
;
; The full-width wheel is written out twelve times, further down. A
; line that stays inside its character cell pays for the next-line test
; and nothing else. A jump into a shared block was tried, and the
; arithmetic to find the entry cost more than the test it removed.
;------------------------------------------------------------------------------
; fast_screen_de - DE = screen address of spr_y, spr_col
; Corrupts: AF, HL, C
;------------------------------------------------------------------------------
fast_screen_de:
        ld a,(spr_y)
        call screen_row_addr    ; HL = leftmost byte of this pixel row
        ld a,(spr_col)
        or l                    ; low five bits are 0; the column fits there
        ld l,a
        ex de,hl
        ret

;------------------------------------------------------------------------------
; fast_buffer_hl - HL = first saved byte of the record IY points at
; Corrupts: DE
;------------------------------------------------------------------------------
fast_buffer_hl:
        push iy
        pop hl
        ld de,BG_DATA
        add hl,de
        ret

;------------------------------------------------------------------------------
; fast_save - photograph the bytes under the sprite
; In:  IY -> background record. spr_y, spr_col, spr_bytes, spr_height
;      already set (sprite_set_pos, or sprite_set_pos_x for a clipped one).
; spr_bytes is the number of bytes actually on screen, not the width of
; the stored picture. A clipped wheel records a shorter row.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
fast_save:
        ld a,(spr_y)
        ld (iy+BG_Y),a
        ld a,(spr_col)
        ld (iy+BG_COL),a
        ld a,(spr_bytes)
        ld (iy+BG_BYTES),a
        ld a,(spr_height)
        ld (iy+BG_HEIGHT),a

        call fast_buffer_hl
        push hl
        call fast_screen_de
        pop hl                  ; HL = record, DE = screen

        ; A full-width wheel is 3 bytes by 12 rows. That copy is written
        ; out in full, further down, because it was the one missing the
        ; interrupt. Every other size stays in the counted loops here,
        ; which are short enough for a relative jump.
        ld a,(spr_bytes)
        cp 3
        jr nz,.width
        ld a,(spr_height)
        cp 12
        jp z,fast_save_wheel3
.width: ld a,(spr_height)
        ld b,a
        ld a,(spr_bytes)
        cp 2
        jr z,.two
        cp 3
        jr z,.three
        cp 4
        jr z,.four

        ; One byte across. A wheel clipped to a single column.
.one:   ld c,e
        ld a,(de)
        ld (hl),a
        inc hl
        inc e
        ld e,c
        NEXT_LINE
        djnz .one
        jr .done

.two:   ld c,e
        dup 2
        ld a,(de)
        ld (hl),a
        inc hl
        inc e
        edup
        ld e,c
        NEXT_LINE
        djnz .two
        jr .done

.three: ld c,e
        dup 3
        ld a,(de)
        ld (hl),a
        inc hl
        inc e
        edup
        ld e,c
        NEXT_LINE
        djnz .three
        jr .done

.four:  ld c,e
        dup 4
        ld a,(de)
        ld (hl),a
        inc hl
        inc e
        edup
        ld e,c
        NEXT_LINE
        djnz .four

.done:  ld (iy+BG_VALID),1
        ret

;------------------------------------------------------------------------------
; fast_restore - put the photograph back, which erases the sprite
; In:  IY -> background record. Does nothing until the first save.
; The column and the byte count are the ones that were saved, not the
; sprite's new position. Call this before the sprite moves on screen.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
fast_restore:
        ld a,(iy+BG_VALID)
        or a
        ret z

        call fast_buffer_hl
        push hl
        ld a,(iy+BG_Y)
        ld (spr_y),a            ; fast_screen_de reads spr_y and spr_col
        ld a,(iy+BG_COL)
        ld (spr_col),a
        call fast_screen_de
        pop hl                  ; HL = record, DE = screen

        ld a,(iy+BG_BYTES)
        cp 3
        jr nz,.width
        ld a,(iy+BG_HEIGHT)
        cp 12
        jp z,fast_restore_wheel3
.width: ld b,(iy+BG_HEIGHT)
        ld a,(iy+BG_BYTES)
        cp 2
        jr z,.two
        cp 3
        jr z,.three
        cp 4
        jr z,.four

.one:   ld c,e
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        ld e,c
        NEXT_LINE
        djnz .one
        ret

.two:   ld c,e
        dup 2
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        edup
        ld e,c
        NEXT_LINE
        djnz .two
        ret

.three: ld c,e
        dup 3
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        edup
        ld e,c
        NEXT_LINE
        djnz .three
        ret

.four:  ld c,e
        dup 4
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        edup
        ld e,c
        NEXT_LINE
        djnz .four
        ret

;------------------------------------------------------------------------------
; fast_pick - HL = the pre-shifted image for spr_shift
; In:  HL -> table of 8 image pointers (from sprite_image)
; Out: HL -> first mask byte of that image
; Corrupts: AF, DE
;------------------------------------------------------------------------------
fast_pick:
        ld a,(spr_shift)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

;------------------------------------------------------------------------------
; fast_draw - draw a masked sprite that is fully stored at spr_bytes
; In:  HL -> first mask byte (shift already chosen). Position from
;      sprite_set_pos. Every stored byte of every row is on screen, so
;      nothing is skipped between rows. The fish and the diver use this.
; Corrupts: AF, BC, DE, HL
;
; A masked byte is: screen = (screen AND mask) OR data. The image has
; to stay in HL because the chip can do AND (HL) and not AND (DE).
;------------------------------------------------------------------------------
fast_draw:
        push hl
        call fast_screen_de
        pop hl
        ld a,(spr_bytes)
        cp 3
        jr nz,.width
        ld a,(spr_height)
        cp 12
        jp z,fast_draw_wheel3
.width: ld a,(spr_height)
        ld b,a
        ld a,(spr_bytes)
        cp 2
        jr z,.two
        cp 3
        jr z,.three
        cp 4
        jr z,.four

.one:   ld c,e
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        ld e,c
        NEXT_LINE
        djnz .one
        ret

.two:   ld c,e
        dup 2
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        ld e,c
        NEXT_LINE
        djnz .two
        ret

.three: ld c,e
        dup 3
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        ld e,c
        NEXT_LINE
        djnz .three
        ret

.four:  ld c,e
        dup 4
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        ld e,c
        NEXT_LINE
        djnz .four
        ret

;------------------------------------------------------------------------------
; fast_draw_gap - fast_draw, for a sprite that is clipped at the edge
; In:  HL -> first on-screen mask byte of row 0 (the caller has already
;      stepped over any pairs hanging off the left). spr_bytes is the
;      visible count. spr_gap2 is how many image bytes to skip after
;      each visible row: the pairs off the right of this row, plus the
;      pairs off the left of the next one. sprite_set_pos_x fills both.
; A fully visible wheel does not come through here: adding a gap of
; zero still costs a memory read, and that wheel is the slow one.
; wheel_draw calls fast_draw instead. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
fast_draw_gap:
        push hl
        call fast_screen_de
        pop hl
        ; The gap is the same on every row. Kept in the alternate
        ; accumulator so the copy can use the ordinary one. The
        ; interrupt handler does not touch the alternate pair.
        ; The last row does not step: nothing follows it.
        ld a,(spr_gap2)
        ex af,af'
        ld a,(spr_height)
        ld b,a
        ld a,(spr_bytes)
        cp 2
        jr z,.two
        cp 3
        jr z,.three

.one:   ld c,e
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        ld e,c
        djnz .more1
        ret
.more1: ex af,af'
        add a,l
        ld l,a
        jr nc,.gap1
        inc h
.gap1:  ex af,af'
        NEXT_LINE
        jr .one

.two:   ld c,e
        dup 2
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        ld e,c
        djnz .more2
        ret
.more2: ex af,af'
        add a,l
        ld l,a
        jr nc,.gap2
        inc h
.gap2:  ex af,af'
        NEXT_LINE
        jr .two

.three: ld c,e
        dup 3
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        ld e,c
        djnz .more3
        ret
.more3: ex af,af'
        add a,l
        ld l,a
        jr nc,.gap3
        inc h
.gap3:  ex af,af'
        NEXT_LINE
        jr .three

;------------------------------------------------------------------------------
; Atlantis copies of the fish and diver draw. The originals in fish.asm
; and diver.asm are what Engine Demo 1 calls; those files are not edited.
; fast_extra is not used: both sprites stay fully on screen, so the gap
; between rows is zero and fast_draw is the right walker.
;------------------------------------------------------------------------------
fish_restore_fast:
        ld iy,fish_bg
        jp fast_restore

fish_draw_fast:
        ld a,(fish_y)
        ld b,a
        ld a,(fish_x)
        ld c,a
        ld d,FISH_BYTES
        ld e,FISH_HEIGHT
        call sprite_set_pos

        ld iy,fish_bg
        call fast_save

        call fish_image_index
        ld hl,fish_images
        call sprite_image
        call fast_pick
        jp fast_draw

diver_restore_fast:
        ld iy,diver_bg
        jp fast_restore

diver_draw_fast:
        ld a,(diver_y)
        ld b,a
        ld a,(diver_x)
        ld c,a
        ld d,DIVER_BYTES
        ld e,DIVER_HEIGHT
        call sprite_set_pos

        ld iy,diver_bg
        call fast_save

        call diver_image_index
        ld hl,diver_images
        call sprite_image
        call fast_pick
        jp fast_draw

;------------------------------------------------------------------------------
; The full-width wheel, 3 bytes by 12 rows.
; Reached only when the byte count is 3 and the height is 12. HL is the
; buffer or the image, DE is the screen, IY is the background record
; (the save uses it to mark the photograph valid).
;
; Twelve copies of the row. The next line inside a character cell is one
; added to the high byte, and NEXT_LINE does that add and then checks
; whether the cell was crossed. Writing the rows out costs less than
; finding an entry point in a shared block: that arithmetic was measured
; and the frame missed the interrupt again.
;------------------------------------------------------------------------------
        MACRO WHEEL_SAVE_ROW
        ld c,e
        dup 3
        ld a,(de)
        ld (hl),a
        inc hl
        inc e
        edup
        ld e,c
        ENDM

        MACRO WHEEL_RESTORE_ROW
        ld c,e
        dup 3
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        edup
        ld e,c
        ENDM

        MACRO WHEEL_DRAW_ROW
        ld c,e
        dup 3
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        ld e,c
        ENDM

fast_save_wheel3:
        dup 11
        WHEEL_SAVE_ROW
        NEXT_LINE
        edup
        ; The twelfth line is the last. Stepping past it is wasted:
        ; nothing reads the address afterwards.
        WHEEL_SAVE_ROW
        ld (iy+BG_VALID),1
        ret

fast_restore_wheel3:
        dup 11
        WHEEL_RESTORE_ROW
        NEXT_LINE
        edup
        WHEEL_RESTORE_ROW
        ret

fast_draw_wheel3:
        dup 11
        WHEEL_DRAW_ROW
        NEXT_LINE
        edup
        WHEEL_DRAW_ROW
        ret
