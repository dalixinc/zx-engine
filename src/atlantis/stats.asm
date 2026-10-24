;==============================================================================
; stats.asm - the debug digits, as an overlay on row 0
;
; The demo printed these on the seabed (rows 22 and 23). Atlantis needs
; those rows for the ground, so the same digits move to row 0, over the
; water. They are off until Symbol Shift + S is pressed. The chord is
; edge-triggered: the moment it goes down, the overlay flips, and holding
; the keys does not flip it again. S on its own is not the chord.
;
; What is on the row, when it is on (one letter, then the hex):
;   F frame    K keys    J joystick    I combined    X diver x
;   Y diver y  M image (facing*3 + kick frame)
; Columns 0..22. The letters are drawn with the same picture-only glyph
; copy as print_hex8. print_char would also write the attribute byte, and
; row 0 is already white ink on blue paper, which is the water.
;
; ORDER, and why a sprite on row 0 does not eat the digits
; The sprite's background record is a photograph of the screen at the
; moment of the save. If the digits are in that photograph, the next
; restore paints them back wherever the sprite has moved, as debris, and
; the water under the overlay is never the water again.
;
; So the photograph is taken with the digits OFF the screen, and the
; digits are put back afterwards, on top of the sprite:
;
;   no sprite on row 0
;       The digits stay up for the whole frame. The beam reads row 0 near
;       the start, long before this loop reaches its end, so wiping them
;       at the start would wipe them before the beam saw them. They are
;       erased and redrawn at the END, after the beam has passed row 0.
;       Nothing saved a background on row 0, so the digits cannot get
;       into a record.
;   a sprite is on row 0 (the diver at the surface, or the fish if its
;       depth is ever up there)
;       The digits are wiped AFTER the old sprite is restored and BEFORE
;       the new one is saved. The photograph is water. The digits are
;       drawn again as soon as that sprite is on screen, so they sit on
;       top of it. Restoring the sprite later puts the water back, which
;       also removes the digits that were on top of it; the wipe then
;       clears the digits the sprite did not cover.
;
; The beam can still catch row 0 while a sprite is up there, between the
; wipe and the redraw. The digits may shimmer on the sprite for that
; frame. They do not get left behind, and turning the overlay off leaves
; row 0 as water. Waiting for the beam would mean holding the sprite
; back until row 0 had been scanned, and the restore already wrote
; that row at the start of the frame, which is when the beam is there.
;==============================================================================

STATS_ROW       equ 0
STATS_LAST      equ 22          ; last column the overlay writes

stats_on:       db 0            ; 1 = draw the digits this frame
stats_dirty:    db 0            ; 1 = digit pixels are on the screen now
stats_chord_prev: db 0          ; last frame's chord, for the edge

;------------------------------------------------------------------------------
; stats_poll - Symbol Shift + S, rising edge, toggles stats_on
; Call once per frame, before the overlay is drawn.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
stats_poll:
        call stats_key_sym      ; A nonzero if Symbol Shift is down
        ld e,a
        call stats_key_s        ; A nonzero if S is down
        and e                   ; both, or neither
        ld hl,stats_chord_prev
        ld b,(hl)
        ld (hl),a               ; remember this frame either way
        or a
        ret z                   ; chord is up: not an edge
        ld a,b
        or a
        ret nz                  ; it was already down: holding does not flip
        ld a,(stats_on)
        xor 1
        ld (stats_on),a
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
; If the digits are up AND a sprite covers row 0, wipe them so the save
; photographs water. If no sprite is there, leave the digits: the beam
; has not been to row 0 yet and this is the picture it is about to show.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
stats_prepare:
        ld a,(stats_dirty)
        or a
        ret z
        call stats_sprite_on_row0
        ret z
        jp stats_erase

;------------------------------------------------------------------------------
; stats_overlay_if_row0 - draw the digits now if a sprite covers row 0
; Call once the fish, and the diver if he is up in the water, are drawn.
; A diver on the seabed is 15 pixels tall and his top is nowhere near
; row 0, so this does not have to wait for that later draw.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
stats_overlay_if_row0:
        call stats_sprite_on_row0
        ret z
        jp stats_finish

;------------------------------------------------------------------------------
; stats_overlay_if_clear - refresh the digits at the end of the frame
; Used when no sprite covered row 0. Erase + redraw happens after the
; beam has left the row, so the picture does not flicker.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
stats_overlay_if_clear:
        call stats_sprite_on_row0
        ret nz                  ; the early call already drew them
        ld a,(stats_dirty)
        or a
        call nz,stats_erase
        jp stats_finish

; Draw if the overlay is on, and remember whether pixels were left behind.
stats_finish:
        ld a,(stats_on)
        or a
        jr z,.off
        call stats_draw
        ld a,1
        ld (stats_dirty),a
        ret
.off:   xor a
        ld (stats_dirty),a
        ret

;------------------------------------------------------------------------------
; stats_sprite_on_row0 - Z set if neither sprite intersects pixel rows 0..7
; A sprite of any height intersects row 0 when its top y is 0..7.
; Corrupts: AF
;------------------------------------------------------------------------------
stats_sprite_on_row0:
        ld a,(diver_y)
        cp 8
        jr c,.hit
        ld a,(fish_y)
        cp 8
        jr c,.hit
        xor a                   ; Z set: row 0 is clear of sprites
        ret
.hit:   ld a,1                  ; Z clear
        or a
        ret

;------------------------------------------------------------------------------
; stats_erase - zero the overlay's cells back to water pixels
; Row 0 has no title and no scenery pixels. Zero is the water.
; Columns 0..STATS_LAST only; the rest of the row was never written.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
stats_erase:
        xor a
        call row_table_entry    ; IX -> address of pixel row 0
        ld b,8
.row:   ld l,(ix+0)
        ld h,(ix+1)
        push bc
        ld b,STATS_LAST + 1
        xor a
.col:   ld (hl),a
        inc l                   ; row 0 starts at a 32-byte boundary, and
        djnz .col               ; 23 columns do not leave that page
        pop bc
        inc ix
        inc ix
        djnz .row
        ret

;------------------------------------------------------------------------------
; stats_draw - the letters and the hex, picture only
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
stats_draw:
        ld bc,(STATS_ROW << 8) | 0
        ld a,'F'
        call stats_glyph
        ld hl,(frame_count)
        ld bc,(STATS_ROW << 8) | 1
        call print_hex16        ; four digits, columns 1..4

        ld bc,(STATS_ROW << 8) | 5
        ld a,'K'
        call stats_glyph
        ld a,(input_keys)
        ld bc,(STATS_ROW << 8) | 6
        call print_hex8

        ld bc,(STATS_ROW << 8) | 8
        ld a,'J'
        call stats_glyph
        ld a,(input_joy)
        ld bc,(STATS_ROW << 8) | 9
        call print_hex8

        ld bc,(STATS_ROW << 8) | 11
        ld a,'I'
        call stats_glyph
        ld a,(input_state)
        ld bc,(STATS_ROW << 8) | 12
        call print_hex8

        ld bc,(STATS_ROW << 8) | 14
        ld a,'X'
        call stats_glyph
        ld a,(diver_x)
        ld bc,(STATS_ROW << 8) | 15
        call print_hex8

        ld bc,(STATS_ROW << 8) | 17
        ld a,'Y'
        call stats_glyph
        ld a,(diver_y)
        ld bc,(STATS_ROW << 8) | 18
        call print_hex8

        ld bc,(STATS_ROW << 8) | 20
        ld a,'M'
        call stats_glyph
        call diver_image_index  ; A = facing*3 + kick frame
        ld bc,(STATS_ROW << 8) | 21
        jp print_hex8

; One character, picture only. In: A = ASCII, BC = row/col. C advances.
; print_hex8 does this for a digit and also skips the attribute write;
; the letters have to do the same or they would recolour the water.
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
        call char_addr
        dup 8
        ld a,(de)
        ld (hl),a
        inc de
        inc h                   ; next pixel inside this cell
        edup
        pop bc
        inc c
        ret
