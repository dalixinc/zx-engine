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
; itself. A silo's missile in its way is blown up first (missile_shot).
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
TORP_STATE      equ $ - torp_on ; one torpedo, torp_on to here

    IFDEF DOUBLE_SHOT
; The double shot's second torpedo: the same block, the same layout,
; T2_OFF bytes on. Its save is torp_save + 4.
t2_on:          db 0
t2_x:           dw 0
t2_y:           db 0
t2_dir:         db 0
t2_tab:         dw 0
t2_r0:          dw 0
t2_r1:          dw 0
t2_vn:          db 0
t2_vcol:        db 0
T2_OFF          equ t2_on - torp_on
        ASSERT $ - t2_on == TORP_STATE && t2_x - t2_on == torp_x - torp_on && t2_y - t2_on == torp_y - torp_on && t2_dir - t2_on == torp_dir - torp_on && t2_tab - t2_on == torp_tab - torp_on && t2_r0 - t2_on == torp_r0 - torp_on && t2_r1 - t2_on == torp_r1 - torp_on && t2_vn - t2_on == torp_vn - torp_on && t2_vcol - t2_on == torp_vcol - torp_on, "the second torpedo's block is not laid out as the first's"
        ASSERT torp_x == torp_on + 1 && torp_y == torp_on + 3 && torp_dir == torp_on + 4, "t2_swap swaps torp_on to torp_dir as three words"
torp_two:       db 0            ; 1 = main_loop is patched for two
double_on:      db 0            ; 1 = a bubble was taken: two at once until double_until
double_until:   dw 0            ; frame_count when the double shot runs out
t2_fresh:       db 0            ; 1 = just handed over: it has moved this step
    ENDIF
; torp_save: in bss.asm (zeroed at start-up, not on the tape)  ; row 0 bytes 0 and 1, then row 1 bytes 0 and 1
fire_ready:     dw 0            ; frame_count at which the next launch is allowed

;------------------------------------------------------------------------------
; torpedo_fire - launch one on a fresh press of fire
; main_loop calls this only while fire is down. A torpedo already
; running, or a fire button that was already down, does nothing.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
torpedo_fire:
        ld hl,(frame_count)
        ld de,(fire_ready)
        or a
        sbc hl,de
        ret c                   ; not yet: this costs nothing on frames
                                ; fire is up, because we are not called
        ld a,(input_prev)
        and IN_FIRE
        ret nz                  ; held from before: not a new press
        ld a,(torp_on)
        or a
    IFDEF DOUBLE_SHOT
        call nz,double_hand     ; Z: the running one went to the second slot
    ENDIF
        ret nz
        ; The last one left (or hit) this step and is still drawn: its
        ; restore, next step, reads torp_r0/r1. A launch now would
        ; write the new rows there, and its bytes at the edge were left
        ; on the screen. Fire again a step later.
        ld a,(torp_vn)
        or a
        ret nz

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
    IFDEF DOUBLE_SHOT
        call double_live
        ld de,CFG_FIRE_COOLDOWN
        jr z,.cool
        ld de,CFG_DOUBLE_COOLDOWN ; the double shot: the next can follow soon
.cool:
    ELSE
        ld de,CFG_FIRE_COOLDOWN
    ENDIF
        ld hl,(frame_count)
        add hl,de
        ld (fire_ready),hl
    IFNDEF NO_SOUND
        jp snd_laser_start      ; pew
    ELSE
        ret
    ENDIF

;------------------------------------------------------------------------------
; The double shot (a power-up, missile.asm): for CFG_DOUBLE_TIME seconds
; he can fire again while a torpedo is still running, so two can be out.
;
; The running one is handed to a second slot (t2_*, the same block T2_OFF
; on) and a fresh one leaves the gun as the first. The second is drawn
; and put back by the same macros at that offset (t2_draw, t2_restore).
; It moves and hits through the first one's own routines: t2_swap
; exchanges the bytes those read (torp_on to torp_dir) for the call.
;
; A single torpedo must not pay for any of it, so nothing tests for a
; second one on the frame. While one exists, torp_two_set patches
; main_loop instead: its three restores, two draws and two hit calls
; (labelled .torp_rc1-3, .torp_dc1-2, .torp_hc1-2 there) are made
; unconditional and go to the "both" routines below, which test each
; torpedo. When the second has gone and been put back, hit_both
; patches them back.
;------------------------------------------------------------------------------
    IFDEF DOUBLE_SHOT
; From torpedo_fire, with a torpedo running (NZ). Out: Z if it went to
; the second slot and a new one may leave; NZ if not.
; Corrupts: AF, BC, DE, HL
double_hand:
        ld a,(t2_on)
        ld hl,t2_vn
        or (hl)
        ret nz                  ; the second slot is busy, or not put back yet
        call double_live
        jr nz,.yes
        or 1                    ; NZ: no double shot now
        ret
.yes:   ld hl,torp_on           ; the running one, as it is on the screen,
        ld de,t2_on             ; becomes the second
        ld bc,TORP_STATE
        ldir
        ld hl,torp_save
        ld de,torp_save + 4
        ld bc,4
        ldir
        xor a
        ld (torp_vn),a          ; the first has nothing on the screen now
        ld (torp_on),a
        inc a
        ld (t2_fresh),a         ; it moved this step already
        call torp_two_set       ; A = 1
        xor a                   ; Z
        ret

; Out: NZ while the double shot lasts. Corrupts: AF
double_live:
    IFDEF MEAS_DOUBLE
        or 1                    ; measurement: always
        ret
    ELSE
        ld a,(double_on)        ; double_tick (missile.asm) ends it on time
        or a
        ret
    ENDIF

; Exchange torp_on..torp_dir (and torp_tab's low byte, put back the same
; way) with the second torpedo's. 216 T-states. Corrupts: DE, HL
t2_swap:
        ld hl,(torp_on)
        ld de,(t2_on)
        ld (torp_on),de
        ld (t2_on),hl
        ld hl,(torp_on + 2)
        ld de,(t2_on + 2)
        ld (torp_on + 2),de
        ld (t2_on + 2),hl
        ld hl,(torp_on + 4)
        ld de,(t2_on + 4)
        ld (torp_on + 4),de
        ld (t2_on + 4),hl
        ret

; main_loop's hit calls, patched. The first's hit as before, then the
; second's move and hit (it moves here, after the bomb, not with the
; first: the same step either way). Corrupts: AF, BC, DE, HL
hit_both:
        ld a,(torp_on)
        or a
        call nz,torpedo_hit
        ld a,(t2_on)
        or a
        jr z,.gone
        call t2_swap
        ld hl,t2_fresh          ; (t2_fresh is outside the swap)
        ld a,(hl)
        ld (hl),0
        or a
        call z,torpedo_move
        ld a,(torp_on)
        or a
        call nz,torpedo_hit
        jp t2_swap
.gone:  ld a,(t2_vn)
        or a
        ret nz                  ; still on the screen: put back next frame
        jp torp_two_set         ; A = 0: one torpedo again

; main_loop's restores, patched: the second first, the reverse of the draws.
restore_low_both:
        ld a,(t2_vn)
        rla
        call c,t2_restore
        ld a,(torp_vn)
        rla
        ret nc
        jp torpedo_restore
restore_high_both:
        ld a,(t2_vn)
        dec a
        cp 2
        call c,t2_restore
        ld a,(torp_vn)
        dec a
        cp 2
        ret nc
        jp torpedo_restore
; main_loop's draws, patched.
draw_high_both:
        ld a,(torp_on)
        dec a
        call z,torpedo_draw
        ld a,(t2_on)
        dec a
        ret nz
        jp t2_draw
draw_low_both:
        ld a,(torp_on)
        rla
        call c,torpedo_draw
        ld a,(t2_on)
        rla
        ret nc
        jp t2_draw

; A = 0 one torpedo, 1 two. Patches only on a change: at a hand-over
; and when the second has gone, not every frame. (The cold block has no
; room left for it.) Corrupts: AF, C, DE, HL
torp_two_set:
        ld hl,torp_two
        cp (hl)
        ret z
        ld (hl),a
        ld c,a
        ld hl,double_bytes
.byte:  ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.words
        ld a,(hl)               ; one torpedo's value
        inc hl
        bit 0,c
        jr z,.b1
        ld a,(hl)               ; two's
.b1:    inc hl
        ld (de),a
        jr .byte
.words: ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z
        push hl
        bit 0,c
        jr z,.w1
        inc hl
        inc hl
.w1:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        jr .words

        ; What each patched site holds as built (DOUBLE_DATA below).
OP_CALL         equ $CD
OP_CALL_C       equ $DC
OP_CALL_Z       equ $CC
OP_CALL_NZ      equ $C4
OP_RET_NC       equ $D0
OP_NOP          equ $00
        ASSERT ({main_loop.torp_rc1} & $FF) == OP_CALL_C && {main_loop.torp_rc1 + 1} == torpedo_restore, ".torp_rc1 is not CALL C,torpedo_restore"
        ASSERT ({fish_rest_call.torp_rc2} & $FF) == OP_CALL_C && {fish_rest_call.torp_rc2 + 1} == torpedo_restore, ".torp_rc2 is not CALL C,torpedo_restore"
        ASSERT ({fish_rest_call.torp_rc3} & $FF) == OP_CALL_C && {fish_rest_call.torp_rc3 + 1} == torpedo_restore, ".torp_rc3 is not CALL C,torpedo_restore"
        ASSERT ({boom_hook.torp_dc1} & $FF) == OP_CALL_Z && {boom_hook.torp_dc1 + 1} == torpedo_draw, ".torp_dc1 is not CALL Z,torpedo_draw"
        ASSERT ({draw_late.torp_dc2 - 1} & $FF) == OP_RET_NC && {draw_late.torp_dc2 + 1} == torpedo_draw, ".torp_dc2 is not RET NC : JP torpedo_draw"
        ASSERT ({fish_mv.torp_hc1} & $FF) == OP_CALL_NZ && {fish_mv.torp_hc1 + 1} == torpedo_hit, ".torp_hc1 is not CALL NZ,torpedo_hit"
        ASSERT ({fish_mv2.torp_hc2} & $FF) == OP_CALL_NZ && {fish_mv2.torp_hc2 + 1} == torpedo_hit, ".torp_hc2 is not CALL NZ,torpedo_hit"
    ENDIF

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
; torpedo_hit - the running torpedo against a missile, then the bomb in
; flight, then the fish
; Call after update_wheel, so both are where this step put them.
; main_loop calls this only while a torpedo is running.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
    IFDEF TWO_BOMBS
TORP_NOT_BOMB   equ tb_torpedo  ; Trigon: the second bomb, then the fish
    ELSE
TORP_NOT_BOMB   equ torpedo_fish
    ENDIF
torpedo_hit:
        call missile_shot       ; a missile in the way goes first
        ret c
        ld a,(wheel_phase)
        or a
        jp z,TORP_NOT_BOMB      ; no bomb: the fish, if it is in the way

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
        jp nz,TORP_NOT_BOMB
        ld a,l
        cp TORP_X_SPAN
        jp nc,TORP_NOT_BOMB

        ld a,(torp_y)
        ld b,a
        ld a,(wheel_y)
        sub b
        add a,-TORP_Y_LO
.yspan: cp TORP_Y_SPAN
        jp nc,TORP_NOT_BOMB

        call wheel_remove
        call boom_at_bomb
        ld a,(level_pts_bomb)
        call score_add
        jr torpedo_spent

;------------------------------------------------------------------------------
; torpedo_restore - put back the bytes the last draw covered
; main_loop calls this only when torp_vn says something is on screen.
; t2_restore is the same for the double shot's second torpedo (its
; block T2_OFF on, save bytes 4 to 7).
; Corrupts: AF, B, C, DE, HL
;------------------------------------------------------------------------------
        MACRO TORP_RESTORE o?, base?
        ld a,(torp_vn + o?)
        and $7F
        ld b,a                  ; 1 or 2 bytes a row
        xor a
        ld (torp_vn + o?),a
        ld a,(torp_vcol + o?)
        ld c,a
        ld hl,(torp_r0 + o?)             ; a row address has the low five bits clear,
        ld a,l                  ; so OR puts the column in
        or c
        ld l,a
        ld de,(torp_r1 + o?)
        ld a,e
        or c
        ld e,a
        ld a,(torp_save + base?)
        ld (hl),a
        ld a,(torp_save + base? + 2)
        ld (de),a
        dec b
        ret z
        inc l
        inc e
        ld a,(torp_save + base? + 1)
        ld (hl),a
        ld a,(torp_save + base? + 3)
        ld (de),a
        ret
        ENDM

torpedo_restore:
        TORP_RESTORE 0, 0
    IFDEF DOUBLE_SHOT
t2_restore:
        TORP_RESTORE T2_OFF, 4
    ENDIF

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
        ld (torp_save + tsb + slot),a
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        ENDM

; The draw is a macro so the double shot's second torpedo (its block
; T2_OFF on, save bytes 4 to 7) is the same code: t2_draw. tsb is the
; save base TORP_BYTE uses, set before each copy.
        MACRO TORP_DRAW o?
        ; The picture for this shift.
        ld hl,(torp_x + o?)
        ld a,l
        and 7
        ld c,a                  ; C = shift
        add a,a
        ld e,a
        ld d,0
        ld b,h                  ; B = high byte of x: 0, or $FF off the left
        ld hl,(torp_tab + o?)
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = first mask byte

        ld a,b
        or a
        jr nz,.off_left         ; x is -7..-1: column -1
        ld a,(torp_x + o?)
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
        ld de,(torp_r0 + o?)
        ld a,e
        or b
        ld e,a
        TORP_BYTE 0
        inc e
        TORP_BYTE 1
        ld de,(torp_r1 + o?)
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
        ld de,(torp_r0 + o?)
        ld a,e
        or b
        ld e,a
        TORP_BYTE 0
        ld a,c
        add a,l
        ld l,a
        jr nc,.row1
        inc h
.row1:  ld de,(torp_r1 + o?)
        ld a,e
        or b
        ld e,a
        TORP_BYTE 2
        ret

        ; A = bytes a row. Note them and the column for the restore,
        ; with TORP_LOW added when this is the draw after the copy.
.record:
        ld e,a
        ld a,(torp_on + o?)
        and TORP_LOW
        or e
        ld (torp_vn + o?),a
        ld a,b
        ld (torp_vcol + o?),a
        ret
        ENDM

tsb = 0
torpedo_draw:
        TORP_DRAW 0
    IFDEF DOUBLE_SHOT
tsb = 4
t2_draw:
        TORP_DRAW T2_OFF
    ENDIF

        COLD
;------------------------------------------------------------------------------
; torpedo_reset - none running, nothing to put back. Corrupts: AF
;------------------------------------------------------------------------------
torpedo_reset:
        xor a
        ld (torp_on),a
        ld (torp_vn),a
        ld (fire_ready),a
        ld (fire_ready+1),a
    IFDEF DOUBLE_SHOT
        ld (t2_on),a
        ld (t2_vn),a
        ld (double_on),a
      IFDEF POWERUPS
        call special_reset      ; no special bomb held or moving things
        call msl_calls_set      ; and the double shot's clock off: missile_update
        xor a
      ENDIF
        jp torp_two_set         ; A = 0: the plain routines back
    ELSE
        ret
    ENDIF
        HOT

; The double shot's patch tables. Only read, so they live in the data
; block (main.asm puts them there).
        MACRO DOUBLE_DATA
; Opcode bytes: where, one torpedo, two. Then 0.
double_bytes:
        dw main_loop.torp_rc1
        db OP_CALL_C, OP_CALL
        dw fish_rest_call.torp_rc2
        db OP_CALL_C, OP_CALL
        dw fish_rest_call.torp_rc3
        db OP_CALL_C, OP_CALL
        dw boom_hook.torp_dc1
        db OP_CALL_Z, OP_CALL
        dw draw_late.torp_dc2 - 1
        db OP_RET_NC, OP_NOP
        dw fish_mv.torp_hc1
        db OP_CALL_NZ, OP_CALL
        dw fish_mv2.torp_hc2
        db OP_CALL_NZ, OP_CALL
        dw 0
; Call operands: where, one torpedo, two. Then 0.
double_words:
        dw main_loop.torp_rc1 + 1, torpedo_restore, restore_low_both
        dw fish_rest_call.torp_rc2 + 1, torpedo_restore, restore_high_both
        dw fish_rest_call.torp_rc3 + 1, torpedo_restore, restore_high_both
        dw boom_hook.torp_dc1 + 1, torpedo_draw, draw_high_both
        dw draw_late.torp_dc2 + 1, torpedo_draw, draw_low_both
        dw fish_mv.torp_hc1 + 1, torpedo_hit, hit_both
        dw fish_mv2.torp_hc2 + 1, torpedo_hit, hit_both
        dw 0
        ENDM
