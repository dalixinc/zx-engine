;==============================================================================
; hit.asm - the wheel bomb against the diver, and the lives
;
; Once per step, after everything has moved, the bomb's box is tested
; against the diver's. A hit costs a life, the bomb is taken away the
; same way it leaves through the left edge, and the border flashes red.
; The last life sends the game back to the menu, which says GAME OVER.
;
; There is no time without hits after one. The bomb is gone at once, the
; next waits WHEEL_GAP and then starts off the right edge, and the
; diver cannot swim past CFG_DIVER_MAX_X. So the next bomb is at least
; two seconds away, and one overlap cannot cost two lives.
;
; The boxes are smaller than the pictures. The diver's leaves out the
; tips of his flippers (three pixels at either side, so it is the same
; box whichever way he faces), the top row (only the top of the helmet)
; and the bottom row. The bomb's leaves out two pixels of rim all round.
; A corner that only grazes the flippers or the rim does not count.
;
; Cost: at most about 210 T-states on a step with a bomb in flight,
; the call included. Under one scanline (224). Nothing at all while the bomb is between flights.
;
; The soak does not call hit_check. Its script steers the diver through
; the bomb on purpose (reason 9 wants to see them cross), and a hit
; would take the bomb away before the frames the soak checks it on.
;==============================================================================

; The counted pixels of each picture, from its own top-left corner,
; inclusive.
HIT_DIVER_L     equ 3
HIT_DIVER_R     equ DIVER_WIDTH - 1 - 3
HIT_DIVER_T     equ 1
HIT_DIVER_B     equ DIVER_HEIGHT - 2
HIT_WHEEL_L     equ 2
HIT_WHEEL_R     equ WHEEL_WIDTH - 1 - 2
HIT_WHEEL_T     equ 2
HIT_WHEEL_B     equ WHEEL_HEIGHT - 1 - 2

; The boxes overlap when the bomb's x minus the diver's x is between
; HIT_X_LO and HIT_X_LO + HIT_X_SPAN - 1. Adding -HIT_X_LO turns that
; into one unsigned compare. The same for y.
HIT_X_LO        equ HIT_DIVER_L - HIT_WHEEL_R
HIT_X_SPAN      equ HIT_DIVER_R - HIT_WHEEL_L - HIT_X_LO + 1
HIT_Y_LO        equ HIT_DIVER_T - HIT_WHEEL_B
HIT_Y_SPAN      equ HIT_DIVER_B - HIT_WHEEL_T - HIT_Y_LO + 1

lives:          db CFG_LIVES
hit_flash:      db 0            ; steps of red border left; 0 = the heartbeat

;------------------------------------------------------------------------------
; hit_check - the bomb against the diver
; Out: carry set if that was the last life. The caller jumps to game_over,
;      so the menu starts from the main loop's stack and not from inside
;      a call.
; Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
hit_check:
        ld a,(wheel_phase)
        or a
        ret z                   ; between flights. OR cleared the carry.

        ; x is 16 bits: the bomb can hang off either edge.
        ld hl,(wheel_x)
        ld a,(diver_x)
        ld e,a
        ld d,0
        or a
        sbc hl,de               ; bomb x - diver x
        ld de,-HIT_X_LO
        add hl,de
        ld a,h
        or a
        ret nz                  ; far left or far right. OR cleared the carry.
        ld a,l
        cp HIT_X_SPAN
        ret nc                  ; not across him

        ; y is 8 bits. Both are 0..191, so a difference that wraps is
        ; 73 or more after the add, never inside the span.
        ld a,(diver_y)
        ld b,a
        ld a,(wheel_y)
        sub b
        add a,-HIT_Y_LO
        cp HIT_Y_SPAN
        ret nc                  ; not level with him

        call wheel_remove
        ld a,CFG_HIT_FLASH
        ld (hit_flash),a
        ld hl,lives
        dec (hl)
        jr z,.over
        or a                    ; lives left: carry clear
        ret
.over:  scf
        ret
