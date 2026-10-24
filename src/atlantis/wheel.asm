;==============================================================================
; wheel.asm - the first Trigon enemy, the wheel bomb
;
; One at a time. It slides in from the right edge, a pixel a frame, bobs
; up and down, and leaves through the left edge. After a short pause
; another one appears at a different height.
;
; The legs spin. The T does not: that mark is on every Trigon enemy,
; and it stays upright. The art is gfx/wheel.txt, 12 by 12, four frames,
; the wide leg stepping a quarter turn counter-clockwise (the way a
; wheel rolls when it travels left). There is a one-pixel gap of water
; between the T and the rim. The picture is a placeholder.
;
; It is drawn by the walker in fastsprite.asm, not by the shared sprite
; loop. A 16 by 16 wheel on that loop cost about 60 scanlines, and the
; frame only had 7 to spare, so the picture missed the interrupt and
; flickered. Twelve pixels is the size asked for. Shifted by 0 to 4 it
; is two bytes wide; shifted by 5 to 7 it is three. The walker writes
; the row in a straight line, and the fish and the diver on this build
; use the same walker, which is where the spare scanlines come from.
;
; Each bomb has its own ink colour. The paper stays the blue of the
; water. wheel_colour is an index into wheel_palette, so a later level
; can point a bomb at another entry, and a homing bomb can use a
; different index from a drifting one. The default is bright red.
; White is the diver, the fish and the water ink, so a white bomb
; would not read.
;
; Colour clash: an 8 by 8 cell has one ink. Any cell the bomb covers
; (the title, the diver, the fish, the stat digits) is drawn in the
; bomb's ink until the bomb moves on and the old attribute byte is put
; back. The sand and the seaweed are not recoloured. The lowest pixel
; of the lowest bob is pixel 167, the last pixel of character row 20,
; and the attribute walk stops there. Row 21 is the seaweed.
;
; Movement is a type byte and a table of routines, so a later bomb that
; homes in on the diver is another entry in the table and another
; routine. That routine is not written here.
;
; It stays in the open water. The top of the bob is pixel row 0 (the stat
; digits may sit on it). The bottom of the bob is the last pixel of row
; 20, one above the seaweed.
;==============================================================================

; Kind values. wheel_kind picks a row of wheel_kind_tab.
WHEEL_KIND_DRIFT equ 0          ; the only kind so far: straight left

; --- Tuning. Names are the knobs. -------------------------------------------
; One pixel a frame, the same speed as the diver, so this first bomb is
; something he can swim away from and something the eye can follow while
; it clips at the edge. 50 pixels a second.
WHEEL_SPEED     equ 1

; Half the height of the bob, in pixels. The table below is a rounded
; sine of this size, not a triangle: a triangle is a couple of adds and
; no table, but it turns around in one frame at the top and looks like a
; bounce. The sine slows down as it reaches the top. 6 pixels is enough
; to read as a bob and small enough that a spawn near the surface still
; fits under the seaweed.
WHEEL_BOB       equ 6

; How many video frames each rotation frame is held. Four frames make one
; turn, so a turn takes 4*8 = 32 frames. In that time the bomb travels 32
; pixels. The rim sits about 5 pixels from the centre, and a wheel of that
; radius rolls one turn in about 31 pixels, so the spin is about right.
; Lower it to slow the spin; it does not have to match the roll.
WHEEL_SPIN      equ 8

; Frames to wait after one bomb has gone, before the next appears.
; 48 frames is just under a second.
WHEEL_GAP       equ 48

; Legal bases. The bob is added to the base, so the base itself stays this
; far from the top and from the seaweed:
;   top:    base - WHEEL_BOB >= 0
;   bottom: base + WHEEL_BOB + WHEEL_HEIGHT <= row 21
WHEEL_TOP_BASE  equ WHEEL_BOB
WHEEL_LOW_BASE  equ BACK_ROW * 8 - WHEEL_HEIGHT - WHEEL_BOB

; Phase of the one bomb. Not the same thing as the kind: drifting covers
; both the flight and the pause between flights.
WHEEL_FLY       equ 1
WHEEL_WAIT      equ 0

;------------------------------------------------------------------------------
; update_wheel - one frame of movement, via the kind table
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
update_wheel:
        ld a,(wheel_kind)
        add a,a                 ; entries are words
        ld e,a
        ld d,0
        ld hl,wheel_kind_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jp (hl)

; One entry today. A homing bomb is a second dw, and wheel_kind = 1.
; Nothing here jumps to a routine that has not been written.
wheel_kind_tab:
        dw wheel_drift

;------------------------------------------------------------------------------
; wheel_drift - the straight-left bomb
; Flying: bob, spin, move left, and when it has gone past the left edge,
; start the pause. Waiting: count down, then spawn the next one.
;------------------------------------------------------------------------------
wheel_drift:
        ld a,(wheel_phase)
        or a
        jr z,.waiting

        ; Bob index steps every frame, round a 32-entry table.
        ld a,(wheel_bob_i)
        inc a
        and 31
        ld (wheel_bob_i),a
        ld hl,wheel_bob
        ld e,a
        ld d,0
        add hl,de
        ld a,(wheel_base)
        add a,(hl)              ; the table entry is a signed offset
        ld (wheel_y),a

        ; Spin. WHEEL_FRAMES is 4, so the frame number is two bits.
        ld hl,wheel_spin_n
        inc (hl)
        ld a,(hl)
        cp WHEEL_SPIN
        jr c,.moved
        ld (hl),0
        ld a,(wheel_frame)
        inc a
        and WHEEL_FRAMES - 1
        ld (wheel_frame),a

.moved: ld hl,(wheel_x)
        ld de,-WHEEL_SPEED
        add hl,de
        ld (wheel_x),hl

        ; Gone once the right-hand pixel is off the screen too:
        ; x + width <= 0.
        ld de,WHEEL_WIDTH
        add hl,de
        bit 7,h
        jr nz,.leave            ; x + width is negative
        ld a,h
        or l
        ret nz                  ; still a pixel on the screen, or more
.leave: xor a
        ld (wheel_phase),a
        ld a,WHEEL_GAP
        ld (wheel_delay),a
        ret

.waiting:
        ld hl,wheel_delay
        dec (hl)
        ret nz
        call wheel_next_height  ; a new base, from the LFSR
        ld hl,256               ; left pixel just past the right edge
        ld (wheel_x),hl
        xor a
        ld (wheel_bob_i),a
        ld (wheel_spin_n),a
        ld (wheel_frame),a
        ld a,(wheel_base)       ; bob[0] is 0, so y starts at the base
        ld (wheel_y),a
        ld a,WHEEL_FLY
        ld (wheel_phase),a
        ret

;------------------------------------------------------------------------------
; wheel_next_height - step the LFSR and take a base from the table
; The low 3 bits pick one of 8 heights. Every entry is between
; WHEEL_TOP_BASE and WHEEL_LOW_BASE, so the bob cannot leave the water.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
wheel_next_height:
        call wheel_rng
        and 7
        ld e,a
        ld d,0
        ld hl,wheel_heights
        add hl,de
        ld a,(hl)
        ld (wheel_base),a
        ret

;------------------------------------------------------------------------------
; wheel_rng - one step of an 8-bit LFSR. A is the new value.
;
; The other cheap source is the R register. R counts instructions, so it
; changes when a frame runs long, and a soak test could not know which
; height was coming. This sequence is the same every time the game is
; switched on.
;
; Galois form, polynomial x^8 + x^6 + x^5 + x^4 + 1. The shifted-out bit
; selects the xor with $B8. Period 255. Seed 0 would stay 0, so the seed
; below is not 0, and the xor keeps it off 0.
;
; Seed 42. The first step is 21 (index 5, the fish's depth). The second
; is 178 (index 2, the surface). The soak counts on that order.
; Corrupts: AF
;------------------------------------------------------------------------------
wheel_rng:
        ld a,(wheel_seed)
        srl a                   ; bit 0 into carry, a zero into bit 7
        jr nc,.keep
        xor $B8
.keep:  ld (wheel_seed),a
        ret

;------------------------------------------------------------------------------
; wheel_restore - put back the pixels and the attribute bytes from last
;                 frame
; wheel_draw    - photograph the new position, draw, and colour the cells,
;                 or do none of that when it is fully off the screen
; Drawn after the fish and before the diver, so the fish is behind it
; and the diver is in front. It never reaches the seaweed, so it is
; always drawn before the seabed copy. Both of these run at the start
; of the frame, while the beam is still up in the border on a frame
; that finishes on time. That is what keeps the erase from flickering.
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
wheel_restore:
        ld iy,wheel_bg
        call fast_restore
        jp wheel_restore_attrs

wheel_draw:
        ld a,(wheel_phase)
        or a
        jr z,.off               ; the pause: nothing on screen

        ; Stored width depends on the shift. The low 3 bits of x pick
        ; it, including when x is negative: -1 has low bits 7, and that
        ; copy is 3 bytes. sprite_set_pos_x then clips that width.
        ld hl,(wheel_x)
        ld a,l
        and 7
        ld e,a
        ld d,0
        ld hl,wheel_shift_bytes
        add hl,de
        ld d,(hl)               ; stored bytes for this shift
        ld a,(wheel_y)
        ld b,a
        ld e,WHEEL_HEIGHT
        ld hl,(wheel_x)
        call sprite_set_pos_x
        ld a,(spr_hidden)
        or a
        jr nz,.off

        ; Resolve the ink every draw, so a store to wheel_colour shows
        ; up on the next frame without any other setup.
        ld a,(wheel_colour)
        ld e,a
        ld d,0
        ld hl,wheel_palette
        add hl,de
        ld a,(hl)
        ld (wheel_ink),a

        ld iy,wheel_bg
        call fast_save

        ld a,(wheel_frame)      ; one facing, so the index is the frame
        ld hl,wheel_images
        call sprite_image
        call fast_pick          ; HL -> image for this shift

        ; Row 0 may start part way along, when the left bytes are off
        ; the screen. Later rows get the same skip from spr_gap2.
        ld a,(spr_skip2)
        add a,l
        ld l,a
        jr nc,.noskip
        inc h
.noskip:
        call fast_draw_gap
        jp wheel_paint_attrs

.off:   ; Fully off, or waiting. The restore already ran, including the
        ; attribute bytes. Drop the record so the next restore does not
        ; paint the old photograph again.
        ld iy,wheel_bg
        ld (iy+BG_VALID),0
        ret

;------------------------------------------------------------------------------
; wheel_restore_attrs - write back the attribute bytes saved last frame
; A cell the bomb covered (title, diver, fish, digits) gets its own
; colour back. The count is cleared, so a second call does nothing.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_restore_attrs:
        ld a,(wheel_attr_n)
        or a
        ret z
        ld b,a
        ld hl,wheel_attrs
.cell:  ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = attribute address
        inc hl
        ld a,(hl)               ; the byte that was there before the bomb
        inc hl
        ld (de),a
        djnz .cell
        xor a
        ld (wheel_attr_n),a
        ret

;------------------------------------------------------------------------------
; wheel_attr_box - the character cells this bomb covers
; Out: Z if it is waiting, or fully off the screen.
;      NZ, and wheel_c0..wheel_c1, wheel_r0..wheel_r1 are inclusive
;      column and row numbers. The bottom row is never the seaweed:
;      pixel 168 is character row 21, and the box stops at row 20.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
wheel_attr_box:
        ld a,(wheel_phase)
        or a
        ret z                   ; waiting

        ld hl,(wheel_x)
        bit 7,h
        jr nz,.negative
        ld a,h
        or a
        jr z,.left_ready        ; x is 0..255, so HL is the first pixel
        xor a                   ; x >= 256: still off the right
        ret

.negative:
        ; Off the left. x + width > 0 means at least one pixel is on.
        ld de,WHEEL_WIDTH
        add hl,de
        bit 7,h
        jr z,.some_left
        xor a
        ret
.some_left:
        ld a,h
        or l
        ret z                   ; x + width = 0: the last pixel just left
        ld hl,0                 ; first visible pixel is column 0
.left_ready:
        ld a,l                  ; first visible pixel / 8
        rrca
        rrca
        rrca
        and 31
        ld (wheel_c0),a

        ld hl,(wheel_x)
        ld de,WHEEL_WIDTH - 1
        add hl,de               ; last pixel, possibly past 255
        bit 7,h
        jr z,.last_pos
        xor a                   ; should not happen: the left test passed
        ret
.last_pos:
        ld a,h
        or a
        jr z,.last_byte
        ld a,255                ; past the right edge: last on-screen pixel
        jr .last_col
.last_byte:
        ld a,l
.last_col:
        rrca
        rrca
        rrca
        and 31
        ld (wheel_c1),a

        ld a,(wheel_y)
        rrca
        rrca
        rrca
        and 31
        ld (wheel_r0),a

        ld a,(wheel_y)
        add a,WHEEL_HEIGHT - 1
        cp BACK_ROW * 8         ; pixel 168 is the first seaweed pixel
        jr c,.bottom_ok
        ld a,BACK_ROW * 8 - 1
.bottom_ok:
        rrca
        rrca
        rrca
        and 31
        ld (wheel_r1),a
        or 1                    ; NZ: there is a box (row 0 would be A = 0)
        ret

;------------------------------------------------------------------------------
; wheel_paint_attrs - colour every cell in the box, remembering the old
;                     byte so the next frame can put it back
; Paper stays blue, because that is what the palette entries use. The
; old byte is saved rather than assuming the cell was water: a title
; cell is yellow, and it has to come back yellow.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
wheel_paint_attrs:
        call wheel_attr_box
        ret z
        xor a
        ld (wheel_attr_n),a
        ld ix,wheel_attrs
        ld a,(wheel_r0)
.row:   ld (wheel_row),a
        ld b,a
        ld a,(wheel_c0)
        ld c,a
        call attr_addr          ; HL = first cell of this row. Corrupts AF.
        ld a,(wheel_c1)
        sub c
        inc a                   ; how many columns, inclusive
        ld b,a
.col:   ld e,(hl)               ; old attribute
        ld a,(wheel_ink)
        ld (hl),a
        ld (ix+0),l
        ld (ix+1),h
        ld (ix+2),e
        inc hl                  ; attributes run left to right
        inc ix
        inc ix
        inc ix
        ld a,(wheel_attr_n)
        inc a
        ld (wheel_attr_n),a
        djnz .col
        ld a,(wheel_row)
        ld c,a
        ld a,(wheel_r1)
        cp c
        ret z
        ld a,c
        inc a
        jr .row

;------------------------------------------------------------------------------
; wheel_on_row0 - NZ if this bomb covers pixel rows 0..7 and is on screen
; Used by the stat overlay: a bomb up there has to photograph water, not
; the digits. Z if it does not. Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
wheel_on_row0:
        ld a,(wheel_phase)
        or a
        ret z
        ld a,(wheel_y)
        cp 8
        jr c,.xchk
        xor a
        ret
.xchk:  ld hl,(wheel_x)
        ld a,h
        or a
        jr z,.on                ; x is 0..255, so at least one pixel shows
        bit 7,h
        jr z,.off               ; x >= 256: still off the right
        ld de,WHEEL_WIDTH
        add hl,de               ; x + width. Positive means a pixel is on.
        bit 7,h
        jr nz,.off
        ld a,h
        or l
        jr z,.off               ; x + width = 0: the last pixel just left
.on:    ld a,1
        or a
        ret
.off:   xor a
        ret

; --- State -------------------------------------------------------------------
wheel_kind:     db WHEEL_KIND_DRIFT
wheel_phase:    db WHEEL_FLY
; Starts just off the right, so the first thing the player sees is it
; sliding in, not popping into existence. The first height is fixed
; (table entry 0). Later heights come from the LFSR.
wheel_x:        dw 256
wheel_y:        db 36           ; matches the base; bob[0] is 0
wheel_base:     db 36
wheel_bob_i:    db 0
wheel_frame:    db 0
wheel_spin_n:   db 0
wheel_delay:    db 0
wheel_seed:     db 42

; Eight bases. Entry 0 is the first bomb (no LFSR yet): deep enough to
; meet the diver as he drops back from the surface, not so high that it
; sits on row 0 while the soak is checking his photograph.
; Entry 5 is the first LFSR height (seed 42 -> 21, low 3 bits = 5): the
; fish swims at pixel 76, and a bomb at 70 overlaps him at every point
; of the bob.
; Entry 2 is the second LFSR height: the surface. The bob reaches y = 0,
; so the stat digits can sit on top of it.
wheel_heights:
        db 36                   ; 0  diver's depth on the way down
        db 100                  ; 1
        db WHEEL_TOP_BASE       ; 2  surface
        db 120                  ; 3
        db 50                   ; 4
        db 70                   ; 5  fish
        db 24                   ; 6
        db WHEEL_LOW_BASE       ; 7  one pixel of bob above the seaweed

; Rounded sine, amplitude WHEEL_BOB, 32 steps. It holds at the top and
; the bottom for two frames, which is the shape of a sine and not of a
; straight up-and-down. Stored as signed offsets from the base.
wheel_bob:
        db 0, 1, 2, 3, 4, 5, 5, 6
        db 6, 5, 5, 4, 3, 2, 1, 0
        db 0,-1,-2,-3,-4,-5,-5,-6
        db -6,-5,-5,-4,-3,-2,-1, 0

; Ink for this bomb. An index into the table, not the attribute byte
; itself, so another bomb can use another entry without a second copy
; of the drawing code. 0 is the drifting bomb on screen today.
wheel_colour:   db 0

; Bright red on the blue of the water. White is the diver, the fish and
; the open water, so a white bomb would disappear into them. Paper is
; blue in every entry: the sea does not change colour. To recolour the
; bomb, change the byte below. For a second colour, add another db and
; store 1 in wheel_colour (a homing bomb would do that).
wheel_palette:
        db BRIGHT | RED | (BLUE << 3)

; The attribute byte last chosen from the table. The soak reads this
; when the bomb is on row 0. It matches the palette until a draw
; resolves a new index.
wheel_ink:      db BRIGHT | RED | (BLUE << 3)

; Cells recoloured last frame. Each entry is the address, then the byte
; that was there. Nine is the most a 12 pixel box can cover: three
; columns by three rows, when the box straddles a character boundary.
wheel_attr_n:   db 0
wheel_attrs:    ds 9 * 3

; Scratch for the attribute box. Not needed once the cells are painted.
wheel_c0:       db 0
wheel_c1:       db 0
wheel_r0:       db 0
wheel_r1:       db 0
wheel_row:      db 0

wheel_bg:       ds BG_DATA + WHEEL_BYTES * WHEEL_HEIGHT
