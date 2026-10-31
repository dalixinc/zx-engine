;==============================================================================
; torpedo.asm - the diver's torpedo
;
; Fire (SPACE, 0, or the Kempston button) launches one from the dark
; mouth at the nose of his jet unit, the way he is facing. It runs
; straight along that row, TORP_SPEED pixels per 1/50 second, and is
; gone when it leaves the screen. One at a time: fire does nothing
; while a torpedo is still running, and holding fire does not repeat.
; Each launch is a fresh press.
;
; A torpedo that touches any pixel of a wheel bomb's picture takes it
; away, the same way the bomb leaves through the left edge, and is spent
; itself.
;
; It does not follow him. Once launched it keeps the row it left on,
; so a diver who sinks after firing leaves it running above him.
;
; It has its own drawing code. Through the general sprite path (clip,
; photograph through IY, the screen address worked out again for every
; save, draw and restore) a running torpedo cost 12 scanlines, for a
; picture of at most four bytes. Its row never changes, so the two
; screen row addresses are looked up once, at launch. Each step only
; works out the column and the shift, then saves and draws the two or
; four bytes in a straight line. Restore puts those bytes back.
;
; Seven pixels by two rows: one byte a row at shifts 0 and 1, two at
; the rest (see gfx/torpedo.txt). At the edges the byte that would be
; in column -1 or column 32 is left out.
;
; main_loop draws it straight after the diver, because it is always
; near his height when it is new, and restores it in the reverse order.
; A torpedo fired from the seabed runs through the weed or the sand and
; is drawn after the seabed copy, like the diver down there. torp_on
; says which: every check while none is running is a load and a test.
;==============================================================================

TORP_SPEED      equ 4           ; pixels per 1/50 second

; The mouth, from the diver's top-left corner. Facing right it is just
; past his right edge. Facing left the art is mirrored, so it is just
; before his left edge, and the torpedo's own width goes to the left.
TORP_MOUTH_Y    equ 12
TORP_RIGHT_X    equ DIVER_WIDTH
TORP_LEFT_X     equ -TORPEDO_WIDTH

; Both boxes are the whole picture. The inset box in hit.asm forgives
; the diver a graze. Here it would be the other way round: a torpedo
; seen to pass through the rim would miss, and that reads as a fault.
TORP_X_LO       equ 0 - (WHEEL_WIDTH - 1)
TORP_X_SPAN     equ TORPEDO_WIDTH - 1 - TORP_X_LO + 1
TORP_Y_LO       equ 0 - (WHEEL_HEIGHT - 1)
TORP_Y_SPAN     equ TORPEDO_HEIGHT - 1 - TORP_Y_LO + 1

; 0 = none. TORP_HIGH: running above the weed, drawn before the seabed
; copy. TORP_LOW: running in the weed or the sand, drawn after it.
TORP_HIGH       equ 1
TORP_LOW        equ $80
torp_on:        db 0
torp_x:         dw 0            ; left pixel, signed: it can hang off an edge
torp_y:         db 0            ; top pixel row
torp_dir:       db FACE_RIGHT   ; also the picture: facing * TORPEDO_FRAMES
torp_tab:       dw 0            ; the 8 shifted pictures for this facing
torp_r0:        dw 0            ; screen address of its top row, column 0
torp_r1:        dw 0            ; and of its second row

; What the last draw covered. torp_vn is the bytes per row on screen
; (1 or 2), with TORP_LOW added when it was drawn after the copy, or 0
; when nothing is on screen. Restore clears it.
torp_vn:        db 0
torp_vcol:      db 0            ; first column on screen
torp_save:      ds 4            ; row 0 bytes 0 and 1, then row 1 bytes 0 and 1

;------------------------------------------------------------------------------
; torpedo_fire - launch one on a fresh press of fire
; main_loop calls this only while fire is down. A torpedo already
; running, or a fire button that was already down, does nothing.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
torpedo_fire:
        ld a,(torp_on)
        or a
        ret nz
        ld a,(input_prev)
        and IN_FIRE
        ret nz                  ; held from before: not a new press

        ld a,(diver_facing)
        ld (torp_dir),a
        ld hl,torpedo_images    ; one frame, so the index is the facing
        call sprite_image
        ld (torp_tab),hl

        ld a,(diver_x)
        ld l,a
        ld h,0
        ld de,TORP_RIGHT_X
        ld a,(torp_dir)
        or a                    ; FACE_RIGHT is 0
        jr z,.place
        ld de,TORP_LEFT_X
.place: add hl,de
        ld (torp_x),hl

        ; The two row addresses, from the table, once.
        ld a,(diver_y)
        add a,TORP_MOUTH_Y
        ld (torp_y),a
        ld l,a
        ld h,0
        add hl,hl
        ld de,ROW_TABLE
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (torp_r0),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (torp_r1),de

        ; Above the weed or in it. It keeps this row, so this is decided
        ; once. It appears at the mouth this step and moves on the next.
        ld a,(torp_y)
        add a,TORPEDO_HEIGHT - 1
        cp BACK_ROW * 8
        ld a,TORP_HIGH
        jr c,.on
        ld a,TORP_LOW
.on:    ld (torp_on),a
        ret

;------------------------------------------------------------------------------
; torpedo_move - one step along its row. main_loop calls this only while
; one is running. It applies step_ticks itself.
; Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
torpedo_move:
        ld a,(step_ticks)
        ld b,a
        ld de,TORP_SPEED
        ld a,(torp_dir)
        or a
        jr z,.step
        ld de,-TORP_SPEED
.step:  ld hl,(torp_x)
.add:   add hl,de
        djnz .add
        ld (torp_x),hl

        ; Off the right: x >= 256 and positive. Off the left: x plus the
        ; width is 0 or less. Anything else still has a pixel on screen.
        bit 7,h
        jr nz,.left
        ld a,h
        or a
        ret z                   ; 0..255
        jr torpedo_spent
.left:  ld de,TORPEDO_WIDTH
        add hl,de
        bit 7,h
        jr nz,torpedo_spent
        ld a,h
        or l
        ret nz
        ; fall through: x + width is exactly 0

;------------------------------------------------------------------------------
; torpedo_spent - it has gone. The next restore puts back what it
; covered. Nothing is drawn after that.
; Corrupts: AF
;------------------------------------------------------------------------------
torpedo_spent:
        xor a
        ld (torp_on),a
        ret

;------------------------------------------------------------------------------
; torpedo_hit - the running torpedo against the bomb in flight
; Call after update_wheel, so both are where this step put them.
; main_loop calls this only while a torpedo is running.
; Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
torpedo_hit:
        ld a,(wheel_phase)
        or a
        ret z

        ; The same compare as hit_check: the bomb's x minus the torpedo's,
        ; moved so the overlap is 0 .. span-1. Both are 16 bits here.
        ld hl,(wheel_x)
        ld de,(torp_x)
        or a
        sbc hl,de
        ld de,-TORP_X_LO
        add hl,de
        ld a,h
        or a
        ret nz
        ld a,l
        cp TORP_X_SPAN
        ret nc

        ld a,(torp_y)
        ld b,a
        ld a,(wheel_y)
        sub b
        add a,-TORP_Y_LO
        cp TORP_Y_SPAN
        ret nc

        call wheel_remove
        jr torpedo_spent

;------------------------------------------------------------------------------
; torpedo_restore - put back the bytes the last draw covered
; main_loop calls this only when torp_vn says something is on screen.
; Corrupts: AF, B, C, DE, HL
;------------------------------------------------------------------------------
torpedo_restore:
        ld a,(torp_vn)
        and $7F
        ld b,a                  ; 1 or 2 bytes a row
        xor a
        ld (torp_vn),a
        ld a,(torp_vcol)
        ld c,a
        ld hl,(torp_r0)         ; a row address has the low five bits clear,
        ld a,l                  ; so OR puts the column in
        or c
        ld l,a
        ld de,(torp_r1)
        ld a,e
        or c
        ld e,a
        ld a,(torp_save)
        ld (hl),a
        ld a,(torp_save+2)
        ld (de),a
        dec b
        ret z
        inc l
        inc e
        ld a,(torp_save+1)
        ld (hl),a
        ld a,(torp_save+3)
        ld (de),a
        ret

;------------------------------------------------------------------------------
; torpedo_draw - save the bytes under it, then draw it
; Corrupts: AF, BC, DE, HL
;
; One masked byte: read the screen into the save, then
;   screen = (screen AND mask) OR data
; HL walks the picture (mask, data, mask, data ...), DE the screen.
;------------------------------------------------------------------------------
        MACRO TORP_BYTE slot
        ld a,(de)
        ld (torp_save + slot),a
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        ENDM

torpedo_draw:
        ; The picture for this shift.
        ld hl,(torp_x)
        ld a,l
        and 7
        ld c,a                  ; C = shift
        add a,a
        ld e,a
        ld d,0
        ld b,h                  ; B = high byte of x: 0, or $FF off the left
        ld hl,(torp_tab)
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = first mask byte

        ld a,b
        or a
        jr nz,.off_left         ; x is -7..-1: column -1
        ld a,(torp_x)
        rrca
        rrca
        rrca
        and 31
        ld b,a                  ; B = column
        ld a,c
        cp 2
        jr c,.narrow            ; shifts 0 and 1: one byte a row
        ld a,b
        cp 31
        jr z,.clip_right        ; the second byte would be column 32

        ; Two bytes a row, both on screen.
        ld a,2
        call .record
        ld de,(torp_r0)
        ld a,e
        or b
        ld e,a
        TORP_BYTE 0
        inc e
        TORP_BYTE 1
        ld de,(torp_r1)
        ld a,e
        or b
        ld e,a
        TORP_BYTE 2
        inc e
        TORP_BYTE 3
        ret

.off_left:
        ; Column -1. One byte a row would be all off the screen. With
        ; two, the second lands in column 0: skip the first pair of
        ; row 0 here, and the first pair of row 1 after row 0's byte.
        ld a,c
        cp 2
        ret c                   ; nothing on screen. torp_vn is already 0.
        inc hl
        inc hl
        ld b,0
        ld c,2
        jr .one

.clip_right:
        ld c,2                  ; skip the pair that is off the right
        jr .one

.narrow:
        ld c,0
.one:   ; One byte a row. B = column, C = image bytes to skip after it.
        ld a,1
        call .record
        ld de,(torp_r0)
        ld a,e
        or b
        ld e,a
        TORP_BYTE 0
        ld a,c
        add a,l
        ld l,a
        jr nc,.row1
        inc h
.row1:  ld de,(torp_r1)
        ld a,e
        or b
        ld e,a
        TORP_BYTE 2
        ret

        ; A = bytes a row. Note them and the column for the restore,
        ; with TORP_LOW added when this is the draw after the copy.
.record:
        ld e,a
        ld a,(torp_on)
        and TORP_LOW
        or e
        ld (torp_vn),a
        ld a,b
        ld (torp_vcol),a
        ret

;------------------------------------------------------------------------------
; torpedo_reset - none running, nothing to put back. Corrupts: AF
;------------------------------------------------------------------------------
torpedo_reset:
        xor a
        ld (torp_on),a
        ld (torp_vn),a
        ret
