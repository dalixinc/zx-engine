;==============================================================================
; trigon/ediver.asm - an enemy diver: an EXPERIMENT, -DENEMY_DIVER only
;
; Part 6 of the brief: a Trigon diver who swims at the player, sketched
; cheaply to find out what one costs before anything is built round him.
; Not in the tape, nor in any build without -DENEMY_DIVER.
;
; He is our diver's first frame turned to face left (gfx/trigon/ediver.txt,
; a placeholder until Erin draws him): one frame and one facing where
; ours has three and two, and, like ours, drawn at even x only, so only
; the four even shifts are made (480 bytes, just below our diver's).
; He comes in from the right edge, swims left a pixel each 1/50 second,
; and drifts a pixel towards our diver's depth every other 1/50 second;
; once off the left edge he waits ED_GAP steps and comes again. He is
; drawn and restored as the fish is, before the seabed copy, after the
; fish (main_loop), and kept above the weed. He hits nothing and nothing
; hits him yet: that is the next step, if the numbers allow it.
;==============================================================================

    IFDEF ENEMY_DIVER

        INCLUDE "../../gfx/trigon/ediver_raw.asm"

        PRESHIFT_SIZE ED_ALL8, EDIVER_PICS, EDIVER_HEIGHT, EDIVER_WIDE, EDIVER_RAW
ED_SHIFTED      equ ED_ALL8 / 2         ; even shifts only, as our diver's
ED_BUF          equ PRESHIFT_START - ED_SHIFTED
        ASSERT EDIVER_WIDE == 0, "the enemy diver's shifts are not all one size"

ED_TOP          equ WHEEL_TOP_Y         ; below the score line
ED_LOW          equ BACK_ROW * 8 - EDIVER_HEIGHT    ; above the weed
    IFDEF MEASURE
ED_GAP          equ 1                   ; always about: the worst case
    ELSE
ED_GAP          equ 100                 ; steps between one and the next
    ENDIF

;------------------------------------------------------------------------------
; ed_move - one 1/50 second (main_loop's step_move and idle_move)
; Corrupts: AF, HL
;------------------------------------------------------------------------------
ed_move:
        ld a,(ed_wait)
        or a
        jr z,.swim
        dec a
        ld (ed_wait),a
        ret nz
        ld hl,256               ; in again, just off the right edge
        ld (ed_x),hl
        ret
.swim:  ld hl,(ed_x)
        dec hl
        ld (ed_x),hl
        bit 7,h
        jr z,.depth             ; 0 to 256
        ld a,l
        cp -EDIVER_WIDTH + 1
        jr nc,.depth            ; partly on the screen still
        ld a,ED_GAP
        ld (ed_wait),a          ; gone off the left
        ret
.depth: ld a,(frame_count)
        and 1
        ret nz
        ld a,(diver_y)
        ld hl,ed_y
        cp (hl)
        ret z
        jr c,.up
        ld a,(hl)
        cp ED_LOW
        ret nc
        inc (hl)
        ret
.up:    ld a,(hl)
        cp ED_TOP + 1
        ret c
        dec (hl)
        ret

;------------------------------------------------------------------------------
; ed_restore, ed_draw - main_loop, before the seabed copy, as the fish's
; Corrupts: AF, BC, DE, HL, IY
;------------------------------------------------------------------------------
ed_restore:
        ld iy,ed_bg
        jp fast_restore

ed_draw:
        ld a,(ed_wait)
        or a
        jr nz,.off
        ld hl,(ed_x)
        ld a,l
        and $FE                 ; even x: 2-pixel steps
        ld l,a
        ld a,(ed_y)
        ld b,a
        ld d,EDIVER_BYTES
        ld e,EDIVER_HEIGHT
        call sprite_set_pos_x
        ld a,(spr_hidden)
        or a
        jr nz,.off
        ld iy,ed_bg
        call fast_save
        xor a                   ; the one picture
        ld hl,ediver_images
        call sprite_image
        call fast_pick
        ; Clipped at an edge: as the bomb's draw (wheel_draw).
        ld a,(spr_skip2)
        or a
        jr nz,.clipped
        ld a,(spr_gap2)
        or a
        jp z,fast_draw
.clipped:
        ld a,(spr_skip2)
        add a,l
        ld l,a
        jr nc,.noskip
        inc h
.noskip:
        jp fast_draw_gap
.off:   ld iy,ed_bg
        ld (iy+BG_VALID),0
        ret

ed_x:           dw 256                  ; his left edge; 256 is just off the right
ed_y:           db 80
ed_wait:        db 0                    ; steps until he comes again, 0 = here

; The pointer tables, in the data block (main.asm): the odd shifts point
; at the even ones, as our diver's do (PRESHIFT_EVEN).
        MACRO ED_DATA
ediver_images:
        PRESHIFT_INDEX ed_shifts, EDIVER_PICS
ed_shifts:
        PRESHIFT_EVEN ED_BUF, EDIVER_PICS, EDIVER_HEIGHT, EDIVER_RAW
        ASSERT pst_a == ED_BUF + ED_SHIFTED, "the enemy diver's tables and preshift disagree"
        ENDM

    ENDIF
