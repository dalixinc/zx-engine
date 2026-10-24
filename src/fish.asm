;==============================================================================
; fish.asm - the test fish, now a second sprite that swims by itself
;
; It swims left and right across the water at a fixed depth, turning round at
; the edges and wagging its tail all the time. Its only job is to prove that
; two sprites of different widths (fish 16 px, diver 24 px) can share the
; screen, pass over each other and over the scenery, without damage.
;
; All the pixel pushing happens in sprite.asm; this file just decides where
; the fish is and which image to show.
;==============================================================================

; Clamp: x can go up to 256 - bytes*8 + 7, so the last byte of a shifted row
; (column x/8 + FISH_BYTES - 1) is still column 31. With 3 bytes: 239.
FISH_MIN_X      equ 0
FISH_MAX_X      equ 256 - FISH_BYTES * 8 + 7
; Fixed depth, pixel row 76: below the demo title, above either seabed.
; Atlantis (DEFINE ATLANTIS, before this file) sets FISH_SWIM_Y itself.
; Its water starts at row 0, and WATER_TOP_ROW * 8 + 20 would park the
; fish on the title. The number is still 76, so he crosses the diver
; in open water either way. IFNDEF only sees DEFINE, not an EQU.
        IFNDEF ATLANTIS
FISH_SWIM_Y     equ WATER_TOP_ROW * 8 + 20
        ENDIF

;------------------------------------------------------------------------------
; update_fish - swim one pixel in the facing direction; turn at the edges
; Corrupts: AF
;------------------------------------------------------------------------------
update_fish:
        ld a,(fish_facing)
        cp FACE_LEFT
        jr z,.left

.right: ld a,(fish_x)
        cp FISH_MAX_X
        jr nc,.turn_left        ; reached the right edge
        inc a
        ld (fish_x),a
        ret
.turn_left:
        ld a,FACE_LEFT
        ld (fish_facing),a
        ret

.left:  ld a,(fish_x)
        cp FISH_MIN_X + 1
        jr c,.turn_right        ; reached the left edge
        dec a
        ld (fish_x),a
        ret
.turn_right:
        ld a,FACE_RIGHT
        ld (fish_facing),a
        ret

;------------------------------------------------------------------------------
; fish_restore - erase the fish drawn last frame (put its background back)
; fish_draw    - save the background at the new position, then draw it
; Split in two so main_loop can restore every sprite before drawing any.
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
fish_restore:
        ld iy,fish_bg
        jp sprite_restore_bg    ; (jp instead of call + ret: same effect)

fish_draw:
        ld a,(fish_y)
        ld b,a
        ld a,(fish_x)
        ld c,a
        ld d,FISH_BYTES
        ld e,FISH_HEIGHT
        call sprite_set_pos

        ld iy,fish_bg
        call sprite_save_bg

        call fish_image_index   ; A = which image
        ld hl,fish_images
        call sprite_image       ; HL -> its 8 shifted copies
        jp sprite_draw

;------------------------------------------------------------------------------
; fish_image_index - A = facing * FISH_FRAMES + animation frame
; The frame flips every ANIM_FRAMES video frames: one bit of frame_count.
; Corrupts: AF, E
;------------------------------------------------------------------------------
fish_image_index:
        ld a,(frame_count)
        and ANIM_FRAMES         ; one bit of the counter: 0 or ANIM_FRAMES
        jr z,.frame0
        ld a,1
.frame0:
        ld e,a                  ; E = animation frame, 0 or 1
        ld a,(fish_facing)
        add a,a                 ; facing * 2 (FISH_FRAMES = 2)
        add a,e
        ret

; --- Fish state --------------------------------------------------------------
fish_x:         db 180          ; pixels
fish_y:         db FISH_SWIM_Y
fish_facing:    db FACE_LEFT
fish_bg:        ds BG_DATA + FISH_BYTES * FISH_HEIGHT   ; background record
