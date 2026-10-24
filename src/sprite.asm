;==============================================================================
; sprite.asm - masked, pre-shifted software sprites of any width
;
; TECHNIQUE (full walk-through in docs/SPRITES.md)
;
; 1. Pre-shifted images. A sprite at pixel x starts in screen column x/8 and
;    is offset x AND 7 pixels into that byte. tools/gfx2asm.py stores 8 copies
;    of every frame, already shifted by 0..7. Drawing is then a plain byte
;    copy: no bit-shifting at run time.
;
;    Width: a sprite W pixels wide is W/8 + 1 bytes wide in every copy.
;    The extra byte is there because shifting right by 1..7 pushes the
;    rightmost pixels into the next byte along. (At shift 0 that byte is
;    empty, but every copy is kept the same size so the loops below don't
;    care which shift they are drawing.) The fish: 16 px -> 3 bytes. The
;    diver: 24 px -> 4 bytes. The routines here take that byte count as a
;    parameter ("bytes per row"), so one set of routines serves both.
;
; 2. Masking. Each image byte comes as a pair (mask, data):
;        screen = (screen AND mask) OR data
;    Mask bits are 1 where the background must survive, 0 where the sprite
;    is solid.
;
; 3. Save / restore background. Before drawing we copy the screen bytes the
;    sprite is about to cover into that sprite's own "background record"
;    (see below). Next frame we copy them back, which erases the sprite and
;    repairs the scenery in one go.
;
; PER FRAME, for one sprite, straight after HALT:
;        sprite_restore_bg  -> sprite_set_pos -> sprite_save_bg -> sprite_draw
; With several sprites: restore ALL of them first, in the REVERSE order they
; were drawn, then save+draw each in turn (see main_loop). Reverse order
; matters when they overlap: the one drawn last saved a background that
; contained the earlier sprites, so it must be put back first.
;
; The scrolling strips are copied onto the screen after every restore
; (main_loop). The far strip's copy is skipped on a prepare frame: the
; buffer was not rotated after the last copy, so the screen already
; matches it. A sprite that overlaps a strip is saved and drawn AFTER the
; copy, so the record holds this frame's ground and not the sprite itself
; (saving while it is still drawn would put its own pixels back next frame).
; A sprite that stays in the water is drawn BEFORE the copy: the copy does
; not touch those rows, and drawing it earlier keeps the beam from catching
; it. docs/SCROLLING.md has the order written out.
;
; BACKGROUND RECORD - one per sprite, pointed to by IY:
;        IY+BG_VALID   0 until the first save (so the first restore is skipped)
;        IY+BG_Y       pixel row it was saved from
;        IY+BG_COL     screen column (0-31)
;        IY+BG_HEIGHT  rows saved
;        IY+BG_BYTES   bytes per row saved
;        IY+BG_DATA... the saved screen bytes, BG_BYTES x BG_HEIGHT of them
; Declare one with   my_bg: ds BG_DATA + bytes * height   (ds fills with 0,
; so BG_VALID starts at 0). IY is used because (iy+n) lets us reach each
; field by name without disturbing HL/DE, which do the copying.
;
; LIMITS (for now): the caller must keep the sprite fully on screen: x no more
; than 256 - bytes*8 + 7 so all bytes of a row stay on the same screen line,
; and y within 0..192-height. Partial clipping comes later.
;==============================================================================

BG_VALID        equ 0
BG_Y            equ 1
BG_COL          equ 2
BG_HEIGHT       equ 3
BG_BYTES        equ 4
BG_DATA         equ 5           ; size of the header; saved bytes follow

;------------------------------------------------------------------------------
; sprite_set_pos - work out where the next sprite goes
; In:  B = y (top pixel row), C = x, D = bytes per row (e.g. FISH_BYTES),
;      E = height in pixel rows
; Out: spr_y, spr_col (x / 8), spr_shift (x AND 7), spr_bytes, spr_height
; Corrupts: AF
;------------------------------------------------------------------------------
sprite_set_pos:
        ld a,b
        ld (spr_y),a
        ld a,d
        ld (spr_bytes),a
        ld a,e
        ld (spr_height),a

        ld a,c
        and %00000111           ; pixel offset inside the byte -> which copy
        ld (spr_shift),a

        ld a,c
        rrca                    ; x / 8 = screen column. RRCA x3 then mask
        rrca                    ; off the 3 bits that rotated round to the
        rrca                    ; top (Z80 has no single "shift by 3").
        and %00011111
        ld (spr_col),a
        ret

;------------------------------------------------------------------------------
; sprite_save_bg - copy the screen bytes under the sprite into a record
; In:  IY -> this sprite's background record; position from sprite_set_pos
; Corrupts: AF, BC, DE, HL, IX
;
; Loop shape (also used by restore and draw):
;   outer loop: one pass per pixel row, B counts rows, C = column
;   inner loop: one pass per byte across, B counts bytes
; Both loops want B for DJNZ, so the outer B/C are PUSHed at the start of
; each row and POPped at the end. That is the standard Z80 way to nest two
; DJNZ loops; it costs 21 T-states per row.
;------------------------------------------------------------------------------
sprite_save_bg:
        ; note where this background came from, for the restore
        ld a,(spr_y)
        ld (iy+BG_Y),a
        call row_table_entry    ; IX -> address of the top row
        ld a,(spr_col)
        ld (iy+BG_COL),a
        ld c,a                  ; C = column, added to every row address
        ld a,(spr_bytes)
        ld (iy+BG_BYTES),a
        ld a,(spr_height)
        ld (iy+BG_HEIGHT),a
        ld b,a                  ; B = rows to do

        push iy                 ; DE = IY + BG_DATA, where the bytes go.
        pop de                  ; (no "LD DE,IY": go via the stack)
        ld hl,BG_DATA
        add hl,de
        ex de,hl

.row:   ld a,(ix+0)             ; HL = row address + column
        add a,c                 ; (can't carry: low 5 bits of a row address
        ld l,a                  ;  are 0 and the column fits in them)
        ld h,(ix+1)

        push bc                 ; keep row count + column
        ld a,(iy+BG_BYTES)
        ld b,a
.byte:  ld a,(hl)               ; screen -> buffer
        ld (de),a
        inc de
        inc l                   ; next byte along (same row: L never wraps
        djnz .byte              ;  because the sprite stays on screen)
        pop bc

        inc ix                  ; next table entry = next pixel row
        inc ix
        djnz .row

        ld (iy+BG_VALID),1
        ret

;------------------------------------------------------------------------------
; sprite_restore_bg - put back what sprite_save_bg saved (erases the sprite)
; In:  IY -> this sprite's background record
; Does nothing until the record has been saved once.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
sprite_restore_bg:
        ld a,(iy+BG_VALID)
        or a
        ret z

        ld a,(iy+BG_Y)
        call row_table_entry    ; IX -> table entry for the saved top row
        ld c,(iy+BG_COL)
        ld b,(iy+BG_HEIGHT)

        push iy                 ; HL = IY + BG_DATA, where the bytes are
        pop de
        ld hl,BG_DATA
        add hl,de

.row:   ld a,(ix+0)             ; DE = row address + column
        add a,c
        ld e,a
        ld d,(ix+1)

        push bc
        ld b,(iy+BG_BYTES)
.byte:  ld a,(hl)               ; buffer -> screen
        ld (de),a
        inc hl
        inc e
        djnz .byte
        pop bc

        inc ix
        inc ix
        djnz .row
        ret

;------------------------------------------------------------------------------
; sprite_image - pick an image from a sprite's image table
; In:  HL -> images table (e.g. diver_images), A = index into it
;      (gfx2asm.py orders it facing*FRAMES + frame)
; Out: HL -> that image's table of 8 shift pointers, ready for sprite_draw
; Corrupts: AF, DE
;------------------------------------------------------------------------------
sprite_image:
        add a,a                 ; entries are 16-bit words
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)               ; read the word (low byte first)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

;------------------------------------------------------------------------------
; sprite_draw - draw a masked sprite at the position from sprite_set_pos
; In:  HL -> table of 8 image pointers (one per shift), from sprite_image
; Corrupts: AF, BC, DE, HL, IX
;
; Register plan inside the loop:
;   HL -> image bytes (mask, data, mask, data, ...)
;   DE -> screen byte being drawn
;   IX -> row table entry,  B = rows left (outer) / bytes left (inner),
;   C = column
; The screen pointer is in DE (not HL) because the Z80 can only do
; AND (HL) / OR (HL), not AND (DE): the image is what we AND and OR with.
;------------------------------------------------------------------------------
sprite_draw:
        ; pick the copy for this shift: HL = word at HL + shift*2
        ld a,(spr_shift)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL -> image for this shift

        ld a,(spr_y)
        push hl
        call row_table_entry    ; (corrupts HL and DE, so keep HL safe)
        pop hl
        ld a,(spr_col)
        ld c,a
        ld a,(spr_height)
        ld b,a

.row:   ld a,(ix+0)             ; DE = row address + column
        add a,c
        ld e,a
        ld d,(ix+1)

        push bc
        ld a,(spr_bytes)
        ld b,a
.byte:  ld a,(de)               ; background
        and (hl)                ; mask: clear where the sprite is solid
        inc hl
        or (hl)                 ; data: set the ink pixels
        inc hl
        ld (de),a
        inc e
        djnz .byte
        pop bc

        inc ix
        inc ix
        djnz .row
        ret

; --- Where the next sprite goes (set by sprite_set_pos) -----------------------
spr_y:          db 0
spr_col:        db 0
spr_shift:      db 0
spr_bytes:      db 0
spr_height:     db 0
