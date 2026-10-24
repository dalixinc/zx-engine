;==============================================================================
; wheel.asm - the first Trigon enemy, the wheel bomb
;
; One at a time. It slides in from the right edge, a pixel a frame, bobs
; up and down, and leaves through the left edge. After a short pause
; another one appears at a different height.
;
; The legs spin. The T in the hub does not: that mark is on every Trigon
; enemy, and it stays upright. The art is gfx/wheel.txt (four frames, the
; wide leg stepping a quarter turn counter-clockwise, which is the way a
; wheel rolls when it travels left).
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
; pixels. The legs sit about 7 pixels from the hub, and a wheel of that
; radius rolls one turn in about 44 pixels, so this is a little quick.
; Quicker reads more clearly with only four frames. Lower it to slow the
; spin; it does not have to match the roll.
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
; wheel_restore - put back what was under the bomb last frame
; wheel_draw    - photograph the new position and draw, or do neither
;                 when it is fully off the screen
; Drawn after the fish and before the diver, so the fish is behind it
; and the diver is in front. It never reaches the seaweed, so it is
; always drawn before the seabed copy.
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
wheel_restore:
        ld iy,wheel_bg
        jp sprite_restore_bg

wheel_draw:
        ld a,(wheel_phase)
        or a
        jr z,.off               ; the pause: nothing on screen
        ld hl,(wheel_x)
        ld a,(wheel_y)
        ld b,a
        ld d,WHEEL_BYTES
        ld e,WHEEL_HEIGHT
        call sprite_set_pos_x
        ld a,(spr_hidden)
        or a
        jr nz,.off

        ld iy,wheel_bg
        call sprite_save_bg

        ld a,(wheel_frame)      ; one facing, so the index is the frame
        ld hl,wheel_images
        call sprite_image
        jp sprite_draw_clip

.off:   ; Fully off, or waiting. The restore already ran. Drop the
        ; record so the next restore does not paint it again.
        ld iy,wheel_bg
        ld (iy+BG_VALID),0
        ret

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

wheel_bg:       ds BG_DATA + WHEEL_BYTES * WHEEL_HEIGHT
