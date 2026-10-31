;==============================================================================
; boom.asm - a short explosion, drawn in place of the bomb or the fish
;
; Four pictures, 16 wide by 12 tall, one copy each. x is snapped to the
; nearest byte, so nothing is pre-shifted. The burst does not scroll.
; It is drawn from wheel_draw's idle path, which runs only while the
; bomb is not on screen, so a heavy frame still draws the bomb alone.
;
; Pixels are ink bits. On open water that ink is bright white, the same
; as the sea, so the burst needs no attribute write.
;==============================================================================

BOOM_ROWS       equ 12
BOOM_HOLD       equ 8           ; 4 shapes, 2 draws each

boom_t:         db 0            ; 0 = nothing to draw
boom_left:      db 0            ; draws still to show
boom_got:       db 0            ; 1 = boom_bg holds the screen under it
boom_fish:      db 0            ; 1 = the fish draw was turned off
boom_col:       db 0            ; screen column, 0..30
boom_y:         db 0
boom_bg:        ds BOOM_ROWS * 2

;------------------------------------------------------------------------------
; boom_reset - no burst, and the fish draws itself again
;------------------------------------------------------------------------------
boom_reset:
        xor a
        ld (boom_t),a
        ld (boom_got),a
        ld (boom_fish),a
        ld hl,fish_draw_fast
        ld (fish_draw_call+1),hl
        ret

; The patched call lands here while a fish burst is showing. The restore
; this frame already put the fish's photograph back. Drop it so the next
; frames do not copy those bytes again.
fish_draw_skip:
        ld iy,fish_bg
        ld (iy+BG_VALID),0
        ret

;------------------------------------------------------------------------------
; boom_at_bomb - the bomb has just been removed. Burst where it was.
; boom_at_fish - the fish. Hide its draw until the burst ends.
;------------------------------------------------------------------------------
boom_at_bomb:
        call boom_show_fish
        ld hl,(wheel_x)
        ld a,(wheel_y)
        jr boom_arm

boom_at_fish:
        ld a,(boom_fish)
        or a
        jr nz,.arm
        ld a,1
        ld (boom_fish),a
        ld hl,fish_draw_skip
        ld (fish_draw_call+1),hl
.arm:   ld a,(fish_x)
        ld l,a
        ld h,0
        ld a,(fish_y)

; In: HL = pixel x (may be off the left), A = pixel y
boom_arm:
        ld (boom_y),a
        ld a,(boom_got)
        or a
        call nz,boom_restore    ; do not leave the previous burst up
        xor a
        ld (boom_got),a
        ld de,4                 ; nearest byte
        add hl,de
        bit 7,h
        jr z,.xpos
        ld hl,0
.xpos:  ld a,h
        or a
        jr z,.div
        ld a,30
        jr .stcol
.div:   ld a,l
        rrca
        rrca
        rrca
        and 31
        cp 31
        jr c,.stcol
        ld a,30
.stcol: ld (boom_col),a
        ld a,(boom_y)
        cp 181
        jr c,.sty
        ld a,180
        ld (boom_y),a
.sty:   ld a,BOOM_HOLD
        ld (boom_left),a
        ld a,1
        ld (boom_t),a
        or a                    ; not a lost life
        ret

boom_show_fish:
        ld a,(boom_fish)
        or a
        ret z
        xor a
        ld (boom_fish),a
        ld hl,fish_draw_fast
        ld (fish_draw_call+1),hl
        ret

;------------------------------------------------------------------------------
; fish_hit - the fish against the diver. No life is lost.
; torpedo_fish - a running torpedo against the fish. The torpedo is spent.
; Both are reached only when the bomb is not on screen.
;------------------------------------------------------------------------------
fish_hit:
        ld a,(boom_t)
        or a
        ret nz
        ld a,(fish_x)
        ld b,a
        ld a,(diver_x)
        sub b
        add a,23                ; -23..15 overlaps the two widths
        cp 39
        ret nc
        ld a,(diver_y)
        sub FISH_SWIM_Y
        add a,14                ; -14..8 overlaps the two heights
        cp 23
        ret nc
        jp boom_at_fish

torpedo_fish:
        ld a,(boom_t)
        or a
        ret nz
        ld a,(torp_y)
        sub FISH_SWIM_Y
        add a,1
        cp FISH_HEIGHT + 1      ; torpedo is 2 rows tall
        ret nc
        ld hl,(torp_x)
        ld a,(fish_x)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld de,15                ; -(FISH_WIDTH-1)
        add hl,de
        ld a,h
        or a
        ret nz
        ld a,l
        cp 22                   ; 15 + TORPEDO_WIDTH
        ret nc
        call torpedo_spent
        jp boom_at_fish

;------------------------------------------------------------------------------
; boom_service - erase the last picture, then draw the next, or finish
; Called from wheel_draw when the bomb is not showing.
;------------------------------------------------------------------------------
boom_service:
        ld a,(boom_t)
        or a
        ret z
        ld a,(boom_got)
        or a
        call nz,boom_restore
        ld a,(boom_left)
        or a
        jr z,boom_end
        ld b,a
        ld a,BOOM_HOLD
        sub b
        srl a                   ; which of the four shapes
        ld l,a
        ld h,0
        add hl,hl               ; *2
        add hl,hl               ; *4
        add hl,hl               ; *8
        ld e,l
        ld d,h
        add hl,hl               ; *16
        add hl,de               ; *24
        ld de,boom_shapes
        add hl,de
        call boom_paint
        ld hl,boom_left
        dec (hl)
        ld a,1
        ld (boom_got),a
        ret

boom_end:
        xor a
        ld (boom_t),a
        ld (boom_got),a
        jp boom_show_fish

; Copy boom_bg back onto the screen.
boom_restore:
        ld hl,boom_bg
        jr boom_rows

; Save the screen under the burst, then copy HL (the shape) onto it.
boom_paint:
        push hl
        ld a,(boom_y)
        call row_table_entry
        pop hl
        ld de,boom_bg
        ld b,BOOM_ROWS
.row:   push bc
        ld c,(ix+0)
        ld b,(ix+1)
        ld a,(boom_col)
        or c
        ld c,a
        ld a,(bc)
        ld (de),a
        ld a,(hl)
        ld (bc),a
        inc de
        inc hl
        inc c
        ld a,(bc)
        ld (de),a
        ld a,(hl)
        ld (bc),a
        inc de
        inc hl
        inc ix
        inc ix
        pop bc
        djnz .row
        ret

; In: HL = 24 bytes to write. No save.
boom_rows:
        push hl
        ld a,(boom_y)
        call row_table_entry
        pop hl
        ld b,BOOM_ROWS
.row:   push bc
        ld c,(ix+0)
        ld b,(ix+1)
        ld a,(boom_col)
        or c
        ld c,a
        ld a,(hl)
        ld (bc),a
        inc hl
        inc c
        ld a,(hl)
        ld (bc),a
        inc hl
        inc ix
        inc ix
        pop bc
        djnz .row
        ret

; Four shapes, 12 rows, 2 bytes each. A bit set is ink.
boom_shapes:
        db $00,$00, $03,$C0, $07,$E0, $0F,$F0, $1F,$F8, $1F,$F8
        db $1F,$F8, $0F,$F0, $07,$E0, $03,$C0, $01,$80, $00,$00
        db $01,$80, $07,$E0, $1F,$F8, $3F,$FC, $7F,$FE, $7E,$FE
        db $7F,$FE, $3F,$FC, $1F,$F8, $07,$E0, $01,$80, $00,$00
        db $0F,$F0, $38,$1C, $60,$06, $C0,$03, $80,$01, $80,$01
        db $C0,$03, $60,$06, $38,$1C, $0F,$F0, $01,$80, $00,$00
        db $01,$00, $20,$08, $04,$20, $40,$04, $02,$80, $80,$01
        db $02,$80, $40,$04, $04,$20, $20,$08, $01,$00, $00,$00
