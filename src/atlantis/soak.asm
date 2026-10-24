;==============================================================================
; soak.asm - stray-pixel and background-restore check. Not in the tape.
;
; Built with -DSOAK (build/atlantis-soak.sna). It plays a scripted dive,
; and after every restore it checks:
;
;   * open water (everything above the seabed except the title rows) is
;     blank again, apart from the stat digits when those are meant to be
;     on screen and no sprite is covering them
;   * rows 21-23 match the bytes copied up on the previous frame, which
;     is the ground the sprites photographed
;   * a sprite that was on row 0 photographed water, not the digits
;   * the diver's top y is never below the black column under him
;   * row 22 stays yellow-on-blue, row 23 stays black-on-yellow, row 0
;     stays white-on-blue except where the wheel bomb is painting it
;     (those cells are the bomb's ink), and a set seaweed pixel is
;     never left in a water-coloured cell
;   * the title and the two help lines (rows 2, 4 and 5) still match the
;     copy taken on the first frame. The wheel flies through them. The
;     blank-water check skips those rows, so this is what catches a
;     restore that put the title back in the wrong place.
;
; The script holds Up until he is on row 0 and toggles the overlay on and
; off (including a plain S, which must not toggle). Then it parks the
; fish on row 0 while he has already sunk clear of it, and toggles again.
; Then it holds Down for the rest of the run so he rides the sand and at
; least one silo. Around frame 650 the wheel bomb is at the surface, and
; the chord is pressed twice more so the digits sit on it. 1024 frames.
; Green border and "OK" means every check passed. A red border and a
; reason number means it stopped at the first failure; the frame number
; is next to it.
;
; Reasons:
;   1 open water was not blank
;   2 the seabed bytes did not match the previous copy
;   3 his feet are inside the black
;   4 a sprite on row 0 saved something other than water
;   5 row 21's colours do not match its pixels
;   6 row 22 or row 23 changed colour, or row 0 was a colour it
;     should not be (water, or the bomb's ink on a cell it covers)
;   7 the overlay did not stay on while the chord was held,
;     or plain S toggled it, or it did not end off
;   8 the run never actually rested him on sand and on a silo,
;     or never checked a sprite photograph on row 0
;   9 the wheel was never seen clipped on the right, clipped on the
;     left, crossing the fish, crossing the diver, and under the digits
;  10 the title or a help line changed
;==============================================================================

SOAK_FRAMES     equ 1024

soak_frame:     dw 0
soak_sym:       db $FF          ; $FF = read the keyboard, else 0 or 1
soak_s:         db $FF
soak_input:     db $FF          ; $FF = keep read_input's answer
soak_reason:    db 0
soak_have_snap: db 0
soak_maxh:      db 0
soak_toggles:   db 0
soak_stats_prev: db 0
soak_saw_sand:  db 0
soak_saw_silo:  db 0
soak_saw_diver_bg: db 0
soak_saw_fish_bg: db 0
soak_saw_wheel_right: db 0      ; a pixel of it was off the right edge
soak_saw_wheel_left: db 0
soak_saw_wheel_fish: db 0       ; its box overlapped the fish
soak_saw_wheel_diver: db 0
soak_saw_wheel_stats: db 0      ; on row 0 while the digits were on
soak_have_title: db 0
soak_title_mode: db 0           ; 0 compare, 1 capture
soak_wx:        dw 0            ; scratch for soak_hit
soak_wc0:       db 0            ; wheel columns on row 0, inclusive
soak_wc1:       db 0

; The two photographs are 768 bytes each. Leaving them in the program
; pushed this test build past $C000 (the shipping game does not include
; them, and it still ends at the code_end printed by the tape build).
; $F300 is the first byte the scroll buffers do not use. $F900 is still
; short of the row table at $FA00.
SOAK_SNAP       equ $F300               ; rows 21-23 after the last blit
SOAK_TITLE      equ SOAK_SNAP + 24 * 32 ; rows 2, 4 and 5, taken on frame 1
SOAK_BUF_END    equ SOAK_TITLE + 3 * 8 * 32
soak_ox:        db 0
soak_oy:        db 0
soak_ow:        db 0
soak_oh:        db 0

; Called at the top of the frame, before stats_poll.
; Sets the two chord keys and remembers the input byte to force.
soak_begin:
        ld hl,(soak_frame)
        inc hl
        ld (soak_frame),hl

        xor a
        ld (soak_sym),a
        ld (soak_s),a
        ld (soak_input),a

        ; Frames count from 1 (we incremented first).
        ld a,h
        or a
        jr nz,.late             ; frame >= 256: hold Down, fish at his depth
        ld a,l

        cp 160
        jr nc,.down
        ld a,IN_UP              ; 1..159: climb to row 0 and stay there
        ld (soak_input),a
        jr .chord
.down:  ld a,IN_DOWN
        ld (soak_input),a

; Four rising edges, so the overlay goes on, off, on, off.
;   120 press (on), 121-150 hold, 151 release
;   160 press (off)
;   162 S alone, Symbol Shift up: must not change anything
;   210 press (on), 211-240 hold, 241 release
;   250 press (off)
.chord: ld a,l
        cp 120
        jr z,.both
        cp 121
        jr c,.fish
        cp 151
        jr c,.both              ; 121..150 still held
        cp 160
        jr z,.both
        cp 162
        jr z,.plain_s
        cp 210
        jr z,.both
        cp 211
        jr c,.fish
        cp 241
        jr c,.both              ; 211..240 still held
        cp 250
        jr z,.both
        jr .fish
.both:  ld a,1
        ld (soak_sym),a
        ld (soak_s),a
        jr .fish
.plain_s:
        ld a,1
        ld (soak_s),a           ; Symbol Shift stays 0
        jr .fish

.late:  ld a,IN_DOWN
        ld (soak_input),a
        call soak_surface_chord ; two more edges, once the bomb is up top

; 200..279 the fish sits on row 0. 280 puts him back at his real depth.
; Frame 256 is the point the high byte turns 1, so this is not a one-byte
; compare.
.fish:  ld a,(soak_frame + 1)
        or a
        jr nz,.fish_hi
        ld a,(soak_frame)
        cp 200
        ret c
        xor a
        ld (fish_y),a
        ret
.fish_hi:
        ld a,(soak_frame)       ; frames 256..279 are low byte 0..23
        cp 24                   ; 256+24 = 280
        jr nc,.fish_home
        xor a
        ld (fish_y),a
        ret
.fish_home:
        ld a,FISH_SWIM_Y
        ld (fish_y),a
        ret

; After read_input. $FF would mean "don't override"; the script always sets
; a real value, including 0.
soak_apply_input:
        ld a,(soak_input)
        ld (input_state),a
        ret

; After restore + stats_prepare, before anything is drawn.
soak_after_restore:
        call soak_check_water
        call soak_check_bg
        call soak_check_strips
        call soak_title_check
        ret

; After the blit, before a low diver is drawn over it.
soak_after_blit:
        call soak_check_attrs
        call soak_take_snap
        ret

; After the sprites have moved. The clamp has run.
soak_after_update:
        call soak_check_clamp
        call soak_note_wheel
        call soak_count_toggles
        ld hl,(soak_frame)
        ld a,h
        cp SOAK_FRAMES / 256
        ret nz
        ld a,l
        cp SOAK_FRAMES & 255
        ret nz
        call soak_finish
        ret

; --- checks -------------------------------------------------------------------

; Open water must be blank. Title rows 2, 4 and 5 are the exception.
; Row 0 is also an exception when the digits are up and no sprite is on
; them: prepare left those pixels so the beam can read them.
soak_check_water:
        ld b,0                  ; character row
.row:   ld a,b
        cp 2
        jr z,.next
        cp 4
        jr z,.next
        cp 5
        jr z,.next
        cp BACK_ROW
        jr nc,.done             ; rows 21..23 are the seabed, not water
        ld a,b
        or a
        jr nz,.zero
        call soak_row0_may_hold_digits
        jr z,.next              ; Z: digits are allowed, don't require blank
.zero:  push bc
        call soak_row_is_blank
        pop bc
        ld a,1
        call nz,soak_fail
.next:  inc b
        jr .row
.done:  ret

; Z set if row 0 is allowed to hold digit pixels right now, so the
; blank check should skip it. NZ if row 0 must be entirely water.
; Digits survive prepare only when they are up AND no sprite covers them.
soak_row0_may_hold_digits:
        ld a,(stats_dirty)
        or a
        jr z,.blank             ; overlay is not on the screen
        call stats_sprite_on_row0
        ret z                   ; no sprite: the digits were left for the beam
.blank: ld a,1
        or a                    ; NZ: require a blank row
        ret

; In: B = character row. Out: Z if all 8*32 pixels are 0. Corrupts A, IX, HL, C.
soak_row_is_blank:
        ld a,b
        add a,a
        add a,a
        add a,a                 ; pixel y of the top of the row
        call row_table_entry
        ld c,8
.line:  ld l,(ix+0)
        ld h,(ix+1)
        ld b,32
.byte:  ld a,(hl)
        or a
        ret nz
        inc l
        djnz .byte
        inc ix
        inc ix
        dec c
        jr nz,.line
        xor a                   ; Z
        ret

; A sprite on row 0 must have photographed water, not the digits.
; Draw order is fish, then wheel, then diver. The back-most of those that
; covers row 0 photographed the water. A later one may have photographed
; the sprite behind it, so only the back-most is checked. (The old check
; stepped aside when the fish and the diver were both up there, for the
; same reason.)
soak_check_bg:
        ld a,(fish_bg + BG_VALID)
        or a
        jr z,.try_wheel
        ld a,(fish_bg + BG_Y)
        cp 8
        jr nc,.try_wheel
        ld iy,fish_bg
        call soak_one_bg
        ret z
        ld a,1
        ld (soak_saw_fish_bg),a
        ret
.try_wheel:
        ld a,(wheel_bg + BG_VALID)
        or a
        jr z,.try_diver
        ld a,(wheel_bg + BG_Y)
        cp 8
        jr nc,.try_diver
        ld iy,wheel_bg
        jp soak_one_bg          ; fail inside if a byte is not water
.try_diver:
        ld iy,diver_bg
        call soak_one_bg
        ret z
        ld a,1
        ld (soak_saw_diver_bg),a
        ret

; IY -> a background record.
; Out: Z if this record does not cover row 0 (nothing checked).
;      NZ if it does, and every saved byte of those rows was 0.
; Does not return when a byte is not water: the run stops.
soak_one_bg:
        ld a,(iy + BG_VALID)
        or a
        ret z
        ld a,(iy + BG_Y)
        cp 8
        jr c,.covers
        xor a                   ; Z: entirely below row 0
        ret
.covers:
        ld c,a                  ; screen y of the first saved row
        ld b,(iy + BG_HEIGHT)
        push iy
        pop hl
        ld de,BG_DATA
        add hl,de               ; HL -> saved bytes
.row:   ld a,c
        cp 8
        jr nc,.skip
        push bc
        ld b,(iy + BG_BYTES)
.byte:  ld a,(hl)
        or a
        jr nz,.bad
        inc hl
        djnz .byte
        pop bc
        jr .step
.skip:  ld a,(iy + BG_BYTES)    ; this row is below row 0: step over it
        add a,l
        ld l,a
        ld a,h
        adc a,0
        ld h,a
.step:  inc c
        djnz .row
        ld a,1
        or a                    ; NZ: the photograph of row 0 was water
        ret
.bad:   ld a,4
        jp soak_fail

soak_check_strips:
        ld a,(soak_have_snap)
        or a
        ret z
        ld a,BACK_ROW * 8
        call row_table_entry
        ld hl,SOAK_SNAP
        ld c,24
.line:  ld e,(ix+0)
        ld d,(ix+1)
        ld b,32
.byte:  ld a,(de)
        cp (hl)
        jr nz,.bad
        inc hl
        inc e
        djnz .byte
        inc ix
        inc ix
        dec c
        jr nz,.line
        ret
.bad:   ld a,2
        jp soak_fail

soak_take_snap:
        ld a,1
        ld (soak_have_snap),a
        ld a,BACK_ROW * 8
        call row_table_entry
        ld de,SOAK_SNAP
        ld c,24
.line:  ld l,(ix+0)
        ld h,(ix+1)
        ld b,32
.byte:  ld a,(hl)
        ld (de),a
        inc de
        inc l
        djnz .byte
        inc ix
        inc ix
        dec c
        jr nz,.line
        ret

soak_check_attrs:
        ; Row 0 stays water-coloured, except the columns the wheel bomb
        ; is painting: those are the bomb's ink until it leaves and the
        ; old byte is put back. The digits do not write attributes.
        ; The sand and the ground are not part of this exception. The
        ; bomb's lowest pixel is the last pixel of row 20, so it never
        ; recolours them.
        call wheel_attr_box
        jr z,.row0_water
        ld a,(wheel_r0)
        or a
        jr nz,.row0_water       ; the top of the bomb is below row 0
        ld a,(wheel_c0)
        ld (soak_wc0),a
        ld a,(wheel_c1)
        ld (soak_wc1),a
        ld b,0
        ld c,0
        call attr_addr
        ld c,0
.row0mix:
        ld a,(soak_wc0)
        cp c
        jr z,.row0ink
        jr nc,.row0sea          ; first column is still to the right of c
        ld a,c
        ld e,a
        ld a,(soak_wc1)
        cp e
        jr c,.row0sea           ; c is past the last column
.row0ink:
        ld a,(hl)
        ld e,a
        ld a,(wheel_ink)
        cp e
        jp nz,.bad6
        jr .row0step
.row0sea:
        ld a,(hl)
        cp WATER_ATTR
        jp nz,.bad6
.row0step:
        inc hl
        inc c
        ld a,c
        cp 32
        jr nz,.row0mix
        jr .rows_sand
.row0_water:
        ld b,0
        ld e,WATER_ATTR
        call soak_row_is_attr
        ld a,6
        call nz,soak_fail
.rows_sand:
        ; Sand and ground are painted once and never touched again.
        ld b,SAND_ROW
        ld e,SAND_ATTR
        call soak_row_is_attr
        ld a,6
        call nz,soak_fail
        ld b,GROUND_ROW
        ld e,GROUND_ATTR
        call soak_row_is_attr
        ld a,6
        call nz,soak_fail
        ; Seaweed row: a set pixel must sit in a green cell, a water
        ; cell must be empty, and a green cell must contain a pixel.
        ld b,BACK_ROW
        ld c,0
        call attr_addr          ; HL -> row 21's attributes
        push hl                 ; row_table_entry reuses HL
        ld a,BACK_ROW * 8
        call row_table_entry
        pop hl
        ld c,0                  ; column
.col:   push hl
        ld a,(hl)               ; attribute of this column
        ld e,a
        ; OR the 8 pixel bytes of this column together
        push ix
        ld d,0
        ld b,8
.pix:   ld l,(ix+0)
        ld h,(ix+1)
        ld a,l
        add a,c
        ld l,a
        ld a,(hl)
        or d
        ld d,a
        inc ix
        inc ix
        djnz .pix
        pop ix
        pop hl
        ld a,e
        cp WEED_ATTR
        jr z,.green
        cp WATER_ATTR
        jr nz,.bad              ; some third colour
        ld a,d
        or a
        jr nz,.bad              ; set pixel in a water cell
        jr .step
.green: ld a,d
        or a
        jr z,.bad               ; green cell with no plant pixel
.step:  inc hl
        inc c
        ld a,c
        cp 32
        jr nz,.col
        ret
.bad:   ld a,5
        jp soak_fail
.bad6:  ld a,6
        jp soak_fail

; In: B = row, E = expected attribute. Out: Z if all 32 match.
soak_row_is_attr:
        ld c,0
        push de
        call attr_addr
        pop de
        ld b,32
.cell:  ld a,(hl)
        cp e
        ret nz
        inc hl
        djnz .cell
        xor a
        ret

soak_check_clamp:
        call soak_tallest
        ld a,(soak_maxh)
        ld b,a
        ld a,NEAR_BOTTOM - DIVER_HEIGHT
        sub b
        ld b,a                  ; B = the lowest legal top y
        ld a,(diver_y)
        cp b
        jr z,.on_it
        jr c,.ok                ; higher on the screen than the floor
        ld a,3
        jp soak_fail
.on_it: ld a,(soak_maxh)
        cp SILO_H
        jr c,.sand
        ld a,1
        ld (soak_saw_silo),a
        jr .ok
.sand:  ld a,1
        ld (soak_saw_sand),a
.ok:    ret

; Tallest front_h under the diver. Same columns as clamp_to_terrain,
; written out again so a mistake in one of them has a chance to disagree.
soak_tallest:
        ld a,(diver_x)
        ld hl,front_fine
        add a,(hl)
        ld l,a
        rrca
        rrca
        rrca
        and %00011111
        ld b,a                  ; first column
        ld a,l
        add a,DIVER_BYTES * 8 - 1
        ld c,a
        ld a,0
        adc a,0
        ld h,a
        ld a,c
        rrca
        rrca
        rrca
        and %00011111
        ld c,a
        ld a,h
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        or c
        ld c,a                  ; last column, 0..32
        ld e,0
.scan:  ld a,b
        cp 32
        jr nc,.pending
        ld a,(front_head)
        add a,b
        and 31
        push bc
        ld c,a
        ld b,0
        ld hl,front_h
        add hl,bc
        pop bc
        ld a,(hl)
        cp e
        jr c,.shorter
        ld e,a
.shorter:
        ld a,b
        cp c
        jr z,.apply
        inc b
        jr .scan
.pending:
        ld a,(front_h_pending)
        cp e
        jr c,.apply
        ld e,a
.apply: ld a,e
        ld (soak_maxh),a
        ret

soak_count_toggles:
        ld a,(stats_on)
        ld hl,soak_stats_prev
        cp (hl)
        ret z
        ld (hl),a
        ld hl,soak_toggles
        inc (hl)
        ret

; The surface bomb is on row 0 around frames 650-670. Seed 42, a
; 48-frame pause and 1 pixel a frame put it there; main.asm asserts
; those two numbers. Two rising edges, so the overlay goes on and then
; off again, and the run still ends with it off.
;   650 press (on), 651-669 hold, 670-679 release
;   680 press (off)
soak_surface_chord:
        ld hl,(soak_frame)
        ld de,650
        or a
        sbc hl,de
        ret c                   ; before 650
        ld a,h
        or a
        ret nz                  ; more than 255 frames later
        ld a,l
        cp 20                   ; 650..669
        jr c,.both
        cp 30
        ret c                   ; 670..679, chord up
        cp 31
        ret nc                  ; 681 onwards
.both:  ld a,1                  ; 680 as well: l = 30
        ld (soak_sym),a
        ld (soak_s),a
        ret

; After the move. Records the situations the run has to have seen.
; The positions are the ones the next frame will draw.
soak_note_wheel:
        ld a,(wheel_phase)
        or a
        ret z
        call soak_note_clip
        call soak_note_cross
        ld a,(stats_on)
        or a
        ret z
        call wheel_on_row0
        ret z
        ld a,1
        ld (soak_saw_wheel_stats),a
        ret

; Right-edge clip is x = 241..255 (some of the 16 pixels still off).
; Left-edge clip is x = -15..-1. x = -16 has already switched to the
; pause, and the frame before that was x = -15.
soak_note_clip:
        ld hl,(wheel_x)
        ld a,h
        or a
        jr z,.maybe_right
        bit 7,a
        ret z                   ; x >= 256, fully off the right
        ld de,WHEEL_WIDTH - 1
        add hl,de               ; x + 15. Negative means x < -15.
        bit 7,h
        ret nz
        ld a,1
        ld (soak_saw_wheel_left),a
        ret
.maybe_right:
        ld a,l
        cp 256 - WHEEL_WIDTH + 1
        ret c                   ; 0..240: fully on, or not yet at the edge
        ld a,1
        ld (soak_saw_wheel_right),a
        ret

; Box against the fish, then against the diver. The ranges are half-open
; on the right and the bottom: sharing an edge pixel counts, sitting in
; the next pixel along does not.
soak_note_cross:
        ld hl,(wheel_x)
        ld a,(fish_x)
        ld b,FISH_WIDTH
        ld c,FISH_HEIGHT
        ld d,a
        ld a,(fish_y)
        ld e,a
        call soak_hit
        jr z,.try_diver
        ld a,1
        ld (soak_saw_wheel_fish),a
.try_diver:
        ld hl,(wheel_x)
        ld a,(diver_x)
        ld b,DIVER_WIDTH
        ld c,DIVER_HEIGHT
        ld d,a
        ld a,(diver_y)
        ld e,a
        call soak_hit
        ret z
        ld a,1
        ld (soak_saw_wheel_diver),a
        ret

; In:  HL = wheel x (signed), D = other x, B = other width,
;      E = other y, C = other height. wheel_y is read from memory.
; Out: NZ if the rectangles overlap, Z if not.
; Corrupts: AF, BC, DE, HL
soak_hit:
        ld (soak_wx),hl
        ld a,d
        ld (soak_ox),a
        ld a,e
        ld (soak_oy),a
        ld a,b
        ld (soak_ow),a
        ld a,c
        ld (soak_oh),a

        ; other x < wheel x + width
        ld hl,(soak_wx)
        ld de,WHEEL_WIDTH
        add hl,de
        ld a,(soak_ox)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        jr z,.no
        jr c,.no

        ; wheel x < other x + other width
        ld a,(soak_ox)
        ld e,a
        ld a,(soak_ow)
        add a,e
        ld e,a
        ld a,0
        adc a,0
        ld d,a                  ; DE = other right, may be 256..279
        ld hl,(soak_wx)
        bit 7,h
        jr nz,.vert             ; a negative x is left of any other right
        or a
        sbc hl,de
        jr nc,.no

.vert:  ; wheel y < other y + other height
        ld a,(soak_oy)
        ld e,a
        ld a,(soak_oh)
        add a,e                 ; other bottom. Both heights fit in a byte.
        ld e,a
        ld a,(wheel_y)
        cp e
        jr nc,.no
        ; other y < wheel y + height
        ld a,(wheel_y)
        add a,WHEEL_HEIGHT
        ld e,a
        ld a,(soak_oy)
        cp e
        jr nc,.no
        or 1                    ; NZ
        ret
.no:    xor a
        ret

;------------------------------------------------------------------------------
; Title and help lines. Taken on the first frame, compared after that.
; Rows 2, 4 and 5. The blank-water check does not look at them.
;------------------------------------------------------------------------------
soak_title_check:
        ld a,(soak_have_title)
        or a
        jr nz,.compare
        ld a,1
        ld (soak_have_title),a
        ld (soak_title_mode),a  ; capture
        jr .rows
.compare:
        xor a
        ld (soak_title_mode),a
.rows:  ld hl,SOAK_TITLE
        ld a,2
        call soak_one_title_row
        jr nz,.bad
        ld a,4
        call soak_one_title_row
        jr nz,.bad
        ld a,5
        call soak_one_title_row
        ret z
.bad:   ld a,10
        jp soak_fail

; In:  A = character row, HL -> buffer (advanced by 8*32)
;      soak_title_mode 0 = compare, 1 = capture
; Out: Z if this row matched, or after a capture. HL stepped on.
; Corrupts: AF, BC, DE, IX
soak_one_title_row:
        push hl
        add a,a
        add a,a
        add a,a                 ; pixel y of the top of the row
        call row_table_entry
        pop hl
        ld c,8
.line:  ld e,(ix+0)
        ld d,(ix+1)
        ld b,32
.byte:  ld a,(soak_title_mode)
        or a
        jr z,.cmp
        ld a,(de)
        ld (hl),a
        jr .step
.cmp:   ld a,(de)
        cp (hl)
        ret nz
.step:  inc hl
        inc e                   ; 32 bytes from a 32-aligned row: the last
        djnz .byte              ; inc wraps, and it is not used again
        inc ix
        inc ix
        dec c
        jr nz,.line
        xor a
        ret

soak_finish:
        ld a,(soak_toggles)
        cp 6                    ; the original four, plus on and off at 650/680
        jr nz,.bad_keys
        ld a,(stats_on)
        or a
        jr nz,.bad_keys         ; the last edge turned it off
        ld a,(soak_saw_sand)
        or a
        jr z,.bad_ride
        ld a,(soak_saw_silo)
        or a
        jr z,.bad_ride
        ld a,(soak_saw_diver_bg)
        or a
        jr z,.bad_ride
        ld a,(soak_saw_fish_bg)
        or a
        jr z,.bad_ride
        ld a,(soak_saw_wheel_right)
        or a
        jr z,.bad_wheel
        ld a,(soak_saw_wheel_left)
        or a
        jr z,.bad_wheel
        ld a,(soak_saw_wheel_fish)
        or a
        jr z,.bad_wheel
        ld a,(soak_saw_wheel_diver)
        or a
        jr z,.bad_wheel
        ld a,(soak_saw_wheel_stats)
        or a
        jr z,.bad_wheel
        ld a,GREEN
        call set_border
        ld a,BRIGHT | WHITE | (BLUE << 3)
        ld (text_attr),a
        ld hl,soak_ok
        ld bc,(8 << 8) | 12
        call print_string
        di
.hang:  halt
        jr .hang
.bad_keys:
        ld a,7
        jp soak_fail
.bad_ride:
        ld a,8
        jp soak_fail
.bad_wheel:
        ld a,9
        jp soak_fail

; In: A = reason. Prints it and the frame, red border, stops.
soak_fail:
        ld (soak_reason),a
        push af
        ld a,RED
        call set_border
        ld a,BRIGHT | WHITE | (BLUE << 3)
        ld (text_attr),a
        ld hl,soak_bad
        ld bc,(8 << 8) | 8
        call print_string
        pop af
        ld bc,(8 << 8) | 13
        call print_hex8
        ld hl,(soak_frame)
        ld bc,(8 << 8) | 16
        call print_hex16
        di
.stop:  halt
        jr .stop

soak_ok:        db "OK",0
soak_bad:       db "FAIL",0
