;==============================================================================
; finale/ediver.asm - the Trigon divers who shoot at the player (Finale)
;
; Up to two (ed_count, from the level's row of CFG_ED_LEVELS), in the
; fish's old place in the frame: drawn after the bomb and the missile
; before the seabed copy, restored before them, kept above the weed. Each
; has a record (ED_* offsets, reached through IX): where he is, how many
; hits he has left, his movement, and his one shot.
;
; Erin's art: two kinds, 16 by 15, facing left (gfx/finale/ediver_blue.txt
; and ediver_red.txt): the blue standard diver and the red, tougher one.
; Four pictures each: apart, halfway, glide (the kick goes 0, 1, 2, 1, a
; picture each ED_KICK 1/50 seconds) and firing (ED_FIRE_POSE 1/50
; seconds as he fires). Drawn at even x like ours, so four shifted copies
; of each picture: the blue's in the fish's old room (Finale's game
; never makes the fish's), the red's just below the jet's pictures, at
; the top of the code's room (both uncontended: in contended RAM at
; $78E0 the red's draw lost frames at level 5).
; On a level with one diver he is the row's kind; with two, one of each.
; Their shot is Erin's 6 x 2, four pixels over six.
;
; He comes in from the right edge at a random depth and swims left a
; pixel each 1/50 second, in one of the level's movements, picked at
; random as he comes (ED_P_*):
;   straight   across at his depth
;   drift      a pixel towards our diver's depth every other 1/50 second
;   stop       across to ED_STOP_X, then holds there ED_STOP_TIME firing
;              twice as often, then on across
;   dive       a pixel towards our diver's depth every 1/50 second
; He fires to the left, one shot at a time, every ed_gap 1/50 seconds
; while he is well on the screen. A shot is a 6-pixel dash, two rows
; tall, ED_SHOT_SPEED pixels a 1/50 second, drawn with its background
; saved like the torpedo's. His cells are painted CFG_ED_INK (tp_box,
; theme.asm), only when he moves into other cells.
;
; Hits: the torpedo and the Lance take one of his hits; the last one
; blows him up (a burst, and CFG_ED_PTS in the "+20" pop-up). While he
; has hits left, a hit makes him blink. Touching him, or being hit by a
; shot, costs our diver a life (hit_check's routines for no bomb or a
; missed one: ed_touch). The bomb waits while both divers are out
; (ed_both_out, wheel.asm). Off the left edge, or blown up, he comes
; again after CFG_ED_GAP 1/50 seconds.
;==============================================================================

    IFDEF ENEMY_DIVER

        INCLUDE "../../gfx/finale/ediver_blue_raw.asm"
        INCLUDE "../../gfx/finale/ediver_red_raw.asm"
; Both kinds are one size: the code uses the blue's names for it.
EDIVER_WIDTH    equ EDBLUE_WIDTH
EDIVER_HEIGHT   equ EDBLUE_HEIGHT
EDIVER_BYTES    equ EDBLUE_BYTES
        ASSERT EDRED_WIDTH == EDBLUE_WIDTH && EDRED_HEIGHT == EDBLUE_HEIGHT && EDRED_PICS == EDBLUE_PICS
        ASSERT EDBLUE_PICS == 4, "apart, halfway, glide, firing"

        PRESHIFT_SIZE ED_ALL8, EDBLUE_PICS, EDBLUE_HEIGHT, EDBLUE_WIDE, EDBLUE_RAW
ED_SHIFTED      equ ED_ALL8 / 2         ; one kind's, even shifts only, as our diver's
ED_BUF_BLUE     equ FISH_BUF            ; the fish's old room
    IFDEF DIVER_JET
ED_BUF_RED      equ JET_BUF - ED_SHIFTED ; below the jet's, above the code: uncontended
    ELSE
ED_BUF_RED      equ DATA_START - ED_SHIFTED ; a measurement: where the jet's would be
    ENDIF
        ASSERT ED_SHIFTED <= FISH_SHIFTED, "the blue diver's pictures do not fit the fish's room"
        ASSERT EDBLUE_WIDE == 0 && EDRED_WIDE == 0, "the enemy diver's shifts are not all one size"
        ASSERT EDIVER_WIDTH == 16, "ed_paint and the box-change rule are written for 16 wide"
ED_KICK         equ 6                   ; 1/50 seconds a kick picture
ED_FIRE_POSE    equ 8                   ; 1/50 seconds of the firing picture
ED_BLUE         equ 0
ED_RED          equ 1

ED_TOP          equ WHEEL_TOP_Y         ; below the score line
ED_LOW          equ BACK_ROW * 8 - EDIVER_HEIGHT    ; above the weed
ED_RANGE        equ ED_LOW - ED_TOP + 1
        ASSERT ED_RANGE >= 64 && ED_RANGE <= 192
ED_STOP_X       equ 168                 ; where a stopping diver holds
ED_STOP_TIME    equ 75                  ; 1/50 seconds he holds there
ED_SHOT_SPEED   equ 3                   ; pixels a 1/50 second
ED_GUN_Y        equ 7                   ; his shot's row, down from his top
ED_FIRE_MIN     equ 40                  ; he fires with his left edge
ED_FIRE_MAX     equ 200                 ; between these (shot column <= 24)
ED_FLASH_TIME   equ 12                  ; 1/50 seconds a hit blinks him
ED_INK_BLUE     equ CFG_ED_BLUE_INK | SEA
ED_INK_RED      equ CFG_ED_RED_INK | SEA

ED_P_STRAIGHT   equ 0
ED_P_DRIFT      equ 1
ED_P_STOP       equ 2
ED_P_DIVE       equ 3

; A diver's record (ed_rec0, ed_rec1 in bss.asm), through IX.
ED_ON           equ 0           ; 1 = swimming, 0 = waiting
ED_WAIT         equ 1           ; 1/50 seconds until he comes
ED_X            equ 2           ; 2 bytes: his left pixel, signed; 256 = just off the right
ED_Y            equ 4           ; his top row
ED_HITS         equ 5           ; hits he can still take
ED_PAT          equ 6           ; his movement, ED_P_*
ED_TIMER        equ 7           ; a stopping diver's hold
ED_FLASH        equ 8           ; 1/50 seconds of blinking left
ED_SHOT         equ 9           ; 1 = his shot is flying
ED_SX           equ 10          ; its left pixel
ED_SY           equ 11          ; its top row
ED_SVN          equ 12          ; 1 = it is drawn: ED_SA*, ED_SSAVE hold what it covered
ED_SA0          equ 13          ; 2 bytes: its first row's screen byte
ED_SA1          equ 15          ; 2 bytes: its second row's
ED_SSAVE        equ 17          ; 4 bytes: the bytes under it, row 0 then row 1
ED_COOL         equ 21          ; 1/50 seconds until he may fire
ED_PON          equ 22          ; 1 = his cells are painted
ED_PAT_AT       equ 23          ; 2 bytes: L column, H row of the painted box
ED_PSIZE        equ 25          ; 2 bytes: C columns, B rows
ED_REPAINT      equ 27          ; 1 = his cells may have changed: ed_paint at the next draw
ED_KIND         equ 28          ; ED_BLUE or ED_RED
ED_ANIM         equ 29          ; 1/50 seconds left of this kick picture
ED_FIRE         equ 30          ; 1/50 seconds of the firing picture left
ED_KSTEP        equ 31          ; the kick's step, 0 to 3 (ed_kick: its picture)
ED_REC          equ 32

;------------------------------------------------------------------------------
; ed_level - level_style, each level and a new game: the level's row of
; CFG_ED_LEVELS (count, hits, movements, shot gap, missiles).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
ed_level:
        ld a,(level_n)
        cp ED_ROWS + 1
        jr c,.row
        ld a,ED_ROWS            ; past the table: its last row again
.row:   dec a
        ld e,a
        add a,a
        add a,a
        add a,e                 ; * 3
        add a,a                 ; * 6
        add a,e                 ; 7 bytes a row
        ld e,a
        ld d,0
        ld hl,ed_tab
        add hl,de
        ld de,ed_count
        ld bc,ED_ROW_LEN
        ldir
        ret

;------------------------------------------------------------------------------
; ed_reset - a new game (boom_reset): both waiting, nothing on the screen
; to put back. Corrupts: AF, IX
;------------------------------------------------------------------------------
ed_reset:
        ld a,(ed_forced)
        or a
        jr z,.rate
        xor a
        ld (ed_forced),a
        ld a,50
        call rate_apply         ; the speed he chose, not ed_rate's
.rate:  ld ix,ed_rec0
        call .one
        ld (ix + ED_WAIT),CFG_ED_FIRST
        ld ix,ed_rec1
        call .one
        ld (ix + ED_WAIT),CFG_ED_FIRST + CFG_ED_GAP
        xor a
        ld (ed_bg + BG_VALID),a
        ld (ed2_bg + BG_VALID),a
        ret
.one:   xor a
        ld (ix + ED_ON),a
        ld (ix + ED_SHOT),a
        ld (ix + ED_SVN),a
        ld (ix + ED_PON),a
        ld (ix + ED_FLASH),a
        ret

; Out: NZ if both divers are out (the bomb waits). Corrupts: AF, HL
ed_both_out:
        ld a,(ed_rec0 + ED_ON)
        ld hl,ed_rec1 + ED_ON
        and (hl)
        ret

; A = the next of the divers' own shift register, mixed with the clock.
; Corrupts: AF, HL
ed_rng:
        ld a,(ed_seed)
        srl a                   ; the Galois step wheel_rng uses
        jr nc,.keep
        xor $B8
.keep:  ld (ed_seed),a
        ld hl,frame_count
        xor (hl)
        ret

;------------------------------------------------------------------------------
; ed_move - one 1/50 second (main_loop's step_move and idle_move): both
; divers, the second only on a level with two. Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
ed_move:
        ld ix,ed_rec0
        call ed_move1
        call ed_paint_if
        ld a,(ed_count)
        cp 2
        ret c
        ld ix,ed_rec1
        call ed_move1
        ; fall through
; His cells' colours, when they may have changed: here, with the moves,
; not in the draw, so at 25 they are in the idle frame and the picture
; frame keeps its time (level 5 lost frames with them there).
ed_paint_if:
        ld a,(ix + ED_ON)
        or a
        ret z
        ld a,(ix + ED_REPAINT)
        or a
        ret z
        jp ed_paint

ed_move1:
        ; His shot first: it flies on whatever he does.
        ld a,(ix + ED_SHOT)
        or a
        jr z,.noshot
        ld a,(ix + ED_SX)
        sub ED_SHOT_SPEED
        jr c,.shotoff
        cp 2
        jr nc,.shotkeep
.shotoff:
        ld (ix + ED_SHOT),0     ; gone off the left: the next restore puts back
        jr .noshot
.shotkeep:
        ld (ix + ED_SX),a
.noshot:
        ld a,(ix + ED_ON)
        or a
        jp nz,.on
        dec (ix + ED_WAIT)
        ret nz
        ; Never three big sprites: with the bomb and the other diver both
        ; out, he waits (a step at a time) for one of them to go.
        ld a,(wheel_phase)
        or a
        jr z,.come
        ld a,(ed_rec0 + ED_ON)
        ld hl,ed_rec1 + ED_ON
        or (hl)                 ; he is not out, so this is the other
        jr z,.come
        inc (ix + ED_WAIT)
        ret
.come:
        ; He comes: just off the right edge, at a random depth, in one of
        ; the level's movements.
        ld (ix + ED_X),0
        ld (ix + ED_X + 1),1
        call ed_rng
        and 127
        cp ED_RANGE
        jr c,.depth
        sub 64
.depth: add a,ED_TOP
        ld (ix + ED_Y),a
        ; His kind: with two, the first blue and the second red; alone,
        ; the level's.
        ld a,(ed_count)
        cp 2
        ld a,(ed_solo)
        jr c,.kind
        push ix
        pop hl
        ld a,l
        cp low ed_rec1
        ld a,ED_BLUE
        jr nz,.kind
        inc a                   ; ED_RED
.kind:  ld (ix + ED_KIND),a
        or a
        ld a,(ed_hblue)
        jr z,.hits
        ld a,(ed_hred)
.hits:  ld (ix + ED_HITS),a
.pick:  call ed_rng
        and 3
        ld c,a
        inc a
        ld b,a
        ld a,(ed_pats)
.bit:   rrca
        djnz .bit
        jr nc,.pick             ; not one of the level's
        ld (ix + ED_PAT),c
        xor a
        ld (ix + ED_TIMER),a
        ld (ix + ED_FLASH),a
        ld (ix + ED_FIRE),a
        ld (ix + ED_KSTEP),a
        ld (ix + ED_ANIM),ED_KICK
        ld a,(ed_gap)
        srl a
        ld (ix + ED_COOL),a     ; the first shot a little sooner
        ld (ix + ED_ON),1
        ld (ix + ED_REPAINT),1
        ret

.on:    dec (ix + ED_ANIM)      ; the kick: a new step each ED_KICK
        jr nz,.kicked
        ld (ix + ED_ANIM),ED_KICK
        ld a,(ix + ED_KSTEP)
        inc a
        and 3
        ld (ix + ED_KSTEP),a
.kicked:
        ld a,(ix + ED_FIRE)
        or a
        jr z,.nopose
        dec (ix + ED_FIRE)
.nopose:
        ld a,(ix + ED_FLASH)
        or a
        jr z,.noflash
        dec (ix + ED_FLASH)
.noflash:
        ld a,(ix + ED_COOL)
        or a
        jr z,.cool
        dec (ix + ED_COOL)
.cool:  ld a,(ix + ED_PAT)
        cp ED_P_STOP
        jr nz,.go
        ld a,(ix + ED_TIMER)
        or a
        jr z,.stopq
        ; Holding: no move, and the gun twice as quick.
        dec (ix + ED_TIMER)
        jr nz,.held
        ld (ix + ED_PAT),ED_P_STRAIGHT ; the hold is over: on across
.held:  ld a,(ix + ED_COOL)
        or a
        jr z,.fire
        dec (ix + ED_COOL)
        jr .fire
.stopq: ld a,(ix + ED_X + 1)
        or a
        jr nz,.go
        ld a,(ix + ED_X)
        cp ED_STOP_X
        jr nz,.go
        ld (ix + ED_TIMER),ED_STOP_TIME
        jr .fire
.go:    ld l,(ix + ED_X)
        ld h,(ix + ED_X + 1)
        dec hl
        ld (ix + ED_X),l
        ld (ix + ED_X + 1),h
        ; His box of cells changes only at x & 7 = 7 (a new column) or 1
        ; (four columns down to three).
        ld a,l
        and 7
        cp 7
        jr z,.boxed
        cp 1
        jr nz,.boxok
.boxed: ld (ix + ED_REPAINT),1
.boxok:
        bit 7,h
        jr z,.vert
        ld a,l
        cp -EDIVER_WIDTH
        jr nc,.vert             ; still partly on the screen
        ; Off the left: he comes again later.
        ld (ix + ED_ON),0
        ld (ix + ED_WAIT),CFG_ED_GAP
        jp ed_unpaint
.vert:  ld a,(ix + ED_PAT)
        cp ED_P_DIVE
        jr z,.dive
        cp ED_P_DRIFT
        jr nz,.fire
        ld a,(frame_count)
        and 1
        jr nz,.fire
.dive:  call .toward
.fire:  ld a,(ix + ED_SHOT)
        or a
        ret nz
        ld a,(ix + ED_COOL)
        or a
        ret nz
        ld a,(ix + ED_X + 1)
        or a
        ret nz
        ld a,(ix + ED_X)
        cp ED_FIRE_MAX
        ret nc
        cp ED_FIRE_MIN
        ret c
        sub 4
        ld (ix + ED_SX),a
        ld a,(ix + ED_Y)
        add a,ED_GUN_Y
        ld (ix + ED_SY),a
        ld (ix + ED_SHOT),1
        ld (ix + ED_FIRE),ED_FIRE_POSE
        ld a,(ed_gap)
        ld (ix + ED_COOL),a
        ret
; A pixel towards our diver's depth, kept between ED_TOP and ED_LOW.
.toward:
        ld a,(diver_y)
        cp (ix + ED_Y)
        ret z
        jr c,.up
        ld a,(ix + ED_Y)
        cp ED_LOW
        ret nc
        inc (ix + ED_Y)
        ld (ix + ED_REPAINT),1  ; a new depth: maybe new rows of cells
        ret
.up:    ld a,(ix + ED_Y)
        cp ED_TOP + 1
        ret c
        dec (ix + ED_Y)
        ld (ix + ED_REPAINT),1
        ret

;------------------------------------------------------------------------------
; ed_restore - main_loop, before the bomb's and the missile's early
; restores: the shots, then the divers, the reverse of ed_draw.
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
ed_restore:
        call ed_rate            ; 25 or 50, by how many big enemies are out
        ld ix,ed_rec1
        call ed_shot_restore
        ld ix,ed_rec0
        call ed_shot_restore
        ld iy,ed2_bg
        call fast_restore
        ld iy,ed_bg
        jp fast_restore

ed_shot_restore:
        ld a,(ix + ED_SVN)
        or a
        ret z
        ld (ix + ED_SVN),0
        ld l,(ix + ED_SA0)
        ld h,(ix + ED_SA0 + 1)
        ld a,(ix + ED_SSAVE)
        ld (hl),a
        inc l
        ld a,(ix + ED_SSAVE + 1)
        ld (hl),a
        ld l,(ix + ED_SA1)
        ld h,(ix + ED_SA1 + 1)
        ld a,(ix + ED_SSAVE + 2)
        ld (hl),a
        inc l
        ld a,(ix + ED_SSAVE + 3)
        ld (hl),a
        ret

;------------------------------------------------------------------------------
; ed_draw - main_loop, in the fish's old place: the divers, then their
; shots. Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
ed_draw:
        ld ix,ed_rec0
        ld iy,ed_bg
        call ed_draw1
        ld ix,ed_rec1
        ld iy,ed2_bg
        call ed_draw1
        ld ix,ed_rec0
        call ed_shot_draw
        ld ix,ed_rec1
        jp ed_shot_draw

ed_draw1:
        ld a,(ix + ED_ON)
        or a
        jr z,.off
        ld a,(ix + ED_FLASH)
        and 2
        jr nz,.off              ; hit: he blinks
        ld l,(ix + ED_X)
        ld h,(ix + ED_X + 1)
        ld a,l
        and $FE                 ; even x: 2-pixel steps
        ld l,a
        ld b,(ix + ED_Y)
        ld d,EDIVER_BYTES
        ld e,EDIVER_HEIGHT
        call sprite_set_pos_x
        ld a,(spr_hidden)
        or a
        jr nz,.off
        call fast_save
        ; The picture: firing, or the kick's 0, 1, 2, 1.
        ld a,(ix + ED_FIRE)
        or a
        ld a,3
        jr nz,.pic
        ld a,(ix + ED_KSTEP)
        cp 3
        jr nz,.pic
        ld a,1                  ; steps 0, 1, 2, 3 are pictures 0, 1, 2, 1
.pic:   ld hl,ed_blue_images
        bit 0,(ix + ED_KIND)
        jr z,.img
        ld hl,ed_red_images
.img:   call sprite_image
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
.off:   ld (iy + BG_VALID),0
        ret

; His shot: Erin's 6 x 2 (.####. over ######), ORed on with what it
; covers kept.
; It is fired with its column at most 24, so its two bytes stay in the row.
ed_shot_draw:
        ld a,(ix + ED_SHOT)
        or a
        ret z
        ld a,(ix + ED_SY)
        ld l,a
        ld h,0
        add hl,hl
        ld de,ROW_TABLE
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = its first row
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = its second
        ld a,(ix + ED_SX)
        rrca
        rrca
        rrca
        and 31
        ld h,a
        or e
        ld e,a
        ld a,h
        or c
        ld c,a
        ld (ix + ED_SA0),e
        ld (ix + ED_SA0 + 1),d
        ld (ix + ED_SA1),c
        ld (ix + ED_SA1 + 1),b
        ld a,(ix + ED_SX)
        and 7
        add a,a
        add a,low ed_shot_pat
        ld l,a
        adc a,high ed_shot_pat
        sub l
        ld h,a                  ; HL = its top row at this shift, two bytes
        ld a,(de)
        ld (ix + ED_SSAVE),a
        or (hl)
        ld (de),a
        inc e
        inc hl
        ld a,(de)
        ld (ix + ED_SSAVE + 1),a
        or (hl)
        ld (de),a
        ld a,l
        add a,15                ; its bottom row's two bytes (ed_shot_low)
        ld l,a
        ld a,(bc)
        ld (ix + ED_SSAVE + 2),a
        or (hl)
        ld (bc),a
        inc c
        inc hl
        ld a,(bc)
        ld (ix + ED_SSAVE + 3),a
        or (hl)
        ld (bc),a
        ld (ix + ED_SVN),1
        ret
        ASSERT (ED_FIRE_MAX - 4) / 8 + 1 <= 31, "a shot's second byte would leave its row"

;------------------------------------------------------------------------------
; ed_paint - his cells in CFG_ED_INK: a box of 2 or 3 rows (by his y)
; and 2 or 3 columns (by his x, clipped at the edges), painted again only
; when it changes, the last box given back to the water first.
; ed_unpaint - the box back to the water. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
ed_paint:
        ld (ix + ED_REPAINT),0
        ld a,(ix + ED_Y)
        ld c,a
        rrca
        rrca
        rrca
        and 31
        ld h,a                  ; his top row
        ld a,c
        and 7
        cp 2                    ; 15 rows: two cell rows from a row's top 2
        ld b,2
        jr c,.rows
        inc b
.rows:  ld a,(ix + ED_X + 1)
        or a
        jr z,.pos
        inc a
        ret nz                  ; off the right: nothing to paint
        ld a,(ix + ED_X)        ; off the left: what shows of him
        add a,EDIVER_WIDTH + 7
        rrca
        rrca
        rrca
        and 31
        ret z
        ld c,a
        ld l,0
        jr .have
.pos:   ld a,(ix + ED_X)
        ld e,a
        rrca
        rrca
        rrca
        and 31
        ld l,a
        ld a,e
        and 6                   ; drawn at even x
        ld c,EDIVER_WIDTH / 8
        jr z,.cols
        inc c
.cols:  ld a,32
        sub l
        cp c
        jr nc,.have
        ld c,a                  ; up to the right edge
.have:  ld a,(ix + ED_PON)
        or a
        jr z,.new
        ld a,(ix + ED_PAT_AT)
        cp l
        jr nz,.change
        ld a,(ix + ED_PAT_AT + 1)
        cp h
        jr nz,.change
        ld a,(ix + ED_PSIZE)
        cp c
        jr nz,.change
        ld a,(ix + ED_PSIZE + 1)
        cp b
        ret z                   ; the same cells: nothing to do
.change:
        push hl
        push bc
        call ed_unpaint
        pop bc
        pop hl
.new:   ld (ix + ED_PAT_AT),l
        ld (ix + ED_PAT_AT + 1),h
        ld (ix + ED_PSIZE),c
        ld (ix + ED_PSIZE + 1),b
        ld (ix + ED_PON),1
        bit 0,(ix + ED_KIND)
        ld a,ED_INK_BLUE
        jp z,tp_box
        ld a,ED_INK_RED
        jp tp_box

ed_unpaint:
        ld a,(ix + ED_PON)
        or a
        ret z
        ld (ix + ED_PON),0
        ld l,(ix + ED_PAT_AT)
        ld h,(ix + ED_PAT_AT + 1)
        ld c,(ix + ED_PSIZE)
        ld b,(ix + ED_PSIZE + 1)
        ld a,WATER_ATTR
        jp tp_box

;------------------------------------------------------------------------------
; ed_touch - hit_check, when the bomb is not on him: a diver's shot, or a
; diver himself, against ours. Out: carry = a hit (diver_hurt).
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
ed_touch:
        ld ix,ed_rec0
        call ed_touch1
        ret c
        ld ix,ed_rec1
ed_touch1:
        ld a,(ix + ED_SHOT)
        or a
        jr z,.diver
        ld a,(diver_x)
        ld b,a
        ld a,(ix + ED_SX)
        sub b
        add a,5                 ; -5 .. 23 overlaps
        cp DIVER_WIDTH + 5
        jr nc,.diver
        ld a,(diver_y)
        ld b,a
        ld a,(ix + ED_SY)
        sub b
        inc a                   ; -1 .. 14 overlaps
        cp DIVER_HEIGHT + 1
        jr nc,.diver
        ld (ix + ED_SHOT),0
        jp diver_hurt
.diver: ld a,(ix + ED_ON)
        or a
        ret z
        ld l,(ix + ED_X)
        ld h,(ix + ED_X + 1)
        ld a,(diver_x)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld de,EDIVER_WIDTH - 1
        add hl,de               ; -23 .. 23 overlaps: 0 .. 46
        ld a,h
        or a
        ret nz
        ld a,l
        cp EDIVER_WIDTH + DIVER_WIDTH - 1
        ret nc
        ld a,(diver_y)
        ld b,a
        ld a,(ix + ED_Y)
        sub b
        add a,EDIVER_HEIGHT - 1 ; -14 .. 14 overlaps
        cp EDIVER_HEIGHT + DIVER_HEIGHT - 1
        ret nc
        call ed_burst           ; he goes up with him
        jp diver_hurt

;------------------------------------------------------------------------------
; ed_torp - torpedo_hit, when the bomb is not in its way: a diver.
; Out: carry if one was hit (the torpedo is spent). Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
ed_torp:
        ld ix,ed_rec0
        call ed_torp1
        ret c
        ld ix,ed_rec1
ed_torp1:
        ld a,(ix + ED_ON)
        or a
        ret z
        ld hl,(torp_x)
        ld e,(ix + ED_X)
        ld d,(ix + ED_X + 1)
        or a
        sbc hl,de
        ld de,TORPEDO_WIDTH - 1
        add hl,de               ; -6 .. 23 overlaps: 0 .. 29
        ld a,h
        or a
        ret nz
        ld a,l
        cp TORPEDO_WIDTH + EDIVER_WIDTH - 1
        ret nc
        ld a,(ix + ED_Y)
        ld b,a
        ld a,(torp_y)
        sub b
        add a,TORPEDO_HEIGHT - 1
        cp TORPEDO_HEIGHT + EDIVER_HEIGHT - 1
        ret nc
        call torpedo_spent
        ; fall through

; ed_damage - one of his hits: he blinks, or, the last, blows up and
; scores. Out: carry set. Corrupts: AF, BC, DE, HL
ed_damage:
        dec (ix + ED_HITS)
        jr z,.kill
        ld (ix + ED_FLASH),ED_FLASH_TIME
        scf
        ret
.kill:  ld a,CFG_ED_PTS
        call pop_add            ; the score, and the "+20" at the burst's end
        call ed_burst
        scf
        ret

; ed_burst - he is gone: a burst where he was (unless one is up), and he
; comes again later. Corrupts: AF, DE, HL
ed_burst:
        ld (ix + ED_ON),0
        ld (ix + ED_WAIT),CFG_ED_GAP
        push bc
        call ed_unpaint
        pop bc
        ld a,(boom_t)
        or a
        ret nz
    IFNDEF NO_SOUND
        call snd_fish_start
    ENDIF
        ld l,(ix + ED_X)
        ld h,(ix + ED_X + 1)
        ld de,(EDIVER_WIDTH - 16) / 2
        add hl,de               ; the burst is 16 wide, over his middle
        ld a,(ix + ED_Y)
        jp boom_arm

;------------------------------------------------------------------------------
; ed_lance - lance_hits: the beam takes one of each diver's hits each
; time it touches him. Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
ed_lance:
        ld ix,ed_rec0
        call .one
        ld ix,ed_rec1
.one:   ld a,(ix + ED_ON)
        or a
        ret z
        ld a,(ix + ED_X + 1)
        dec a
        ret z                   ; off the right
        ld l,(ix + ED_X)
        ld h,(ix + ED_X + 1)
        ld a,(ix + ED_Y)
        ld bc,(EDIVER_HEIGHT << 8) | EDIVER_WIDTH
        call lance_box
        ret nc
        jp ed_damage

;------------------------------------------------------------------------------
; ed_msl_pick - missile_or_power, when no power-up is due: a missile on a
; level with them (CFG_ED_LEVELS), or, on one without, the slot's turn
; goes by (missile_gone: a new wait, and the roll for a heart).
;------------------------------------------------------------------------------
ed_msl_pick:
        ld a,(ed_missiles)
        or a
        jp nz,missile_pick
        jp missile_gone

;------------------------------------------------------------------------------
; ed_rate - each step, before the restores: the frame budget. From level
; CFG_ED_25_LEVEL, with two big enemies out (two divers, or a diver and
; the bomb; before that level 50 holds with them) the game drops to 25
; frames a second, the speed of the game the same (rate_apply), and goes
; back to 50 ED_HOLD 1/50 seconds after one has gone, so it does not
; flicker between the two. Only from 50 the player chose: at 25 it stays.
; Not while he dies or the banner holds the game still (their own freezes
; set the jumps). Corrupts: AF, B, HL
;------------------------------------------------------------------------------
ED_HOLD         equ 25                  ; half a second
ed_rate:
    IFDEF MEASURE
        ld a,(step_ticks)
        dec a
        jr z,.m50
        ld hl,(ed_n25)
        inc hl
        ld (ed_n25),hl          ; steps at 25, for the report
.m50:
    ENDIF
        ld a,(hud_dirty)
        bit HUD_BANNER,a
        ret nz
        ld a,(death_t)
        or a
        ret nz
        ld a,(level_n)
        cp CFG_ED_25_LEVEL
        ld a,0                  ; before it: never two (50 holds there)
        jr c,.count
        ld a,(wheel_phase)
        or a
        jr z,.nobomb
        ld a,1
.nobomb:
        ld hl,ed_rec0 + ED_ON
        add a,(hl)
        ld hl,ed_rec1 + ED_ON
        add a,(hl)
.count: cp 2
        jr c,.calm
        ld a,ED_HOLD
        ld (ed_hold),a
        ld a,(ed_forced)
        or a
        ret nz                  ; at 25 already
        ld a,(game_rate)
        cp 50
        ret nz                  ; he plays at 25 anyway
        ld a,1
        ld (ed_forced),a
    IFDEF MEASURE
        ld hl,(ed_nsw)
        inc hl
        ld (ed_nsw),hl          ; times it went down to 25
    ENDIF
        ld a,25
        jp rate_apply
.calm:  ld a,(ed_forced)
        or a
        ret z
        ld hl,ed_hold
        ld a,(step_ticks)
        ld b,a
        ld a,(hl)
        sub b
        jr c,.back
        jr z,.back
        ld (hl),a
        ret
.back:  xor a
        ld (ed_forced),a
        ld a,50
        jp rate_apply

ed_forced:      db 0            ; 1 = ed_rate put the game at 25
ed_hold:        db 0            ; 1/50 seconds of calm before it goes back
    IFDEF MEASURE
ed_n25:         dw 0            ; steps at 25
ed_nsw:         dw 0            ; times down to 25
    ENDIF

ed_count:       db 1            ; the level's row (ed_level), in this order
ed_hblue:       db 2            ; a blue diver's hits
ed_hred:        db 3            ; a red one's
ed_solo:        db ED_BLUE      ; the kind on a level with one
ed_pats:        db 1
ed_gap:         db 120
ed_missiles:    db 0
ed_seed:        db 57           ; never 0

; The shot at each of the 8 shifts, two bytes: its top row (.####.),
; then, 16 bytes on, its bottom row (######).
ed_shot_pat:
        db %01111000, %00000000
        db %00111100, %00000000
        db %00011110, %00000000
        db %00001111, %00000000
        db %00000111, %10000000
        db %00000011, %11000000
        db %00000001, %11100000
        db %00000000, %11110000
ed_shot_low:
        db %11111100, %00000000
        db %01111110, %00000000
        db %00111111, %00000000
        db %00011111, %10000000
        db %00001111, %11000000
        db %00000111, %11100000
        db %00000011, %11110000
        db %00000001, %11111000
        ASSERT high ed_shot_pat == high (ed_shot_pat + 31), "ed_shot_draw steps L only"
        ASSERT ed_shot_low == ed_shot_pat + 16

; The levels' rows (config.asm, CFG_ED_LEVELS).
        MACRO ED_ROW count?, hblue?, hred?, solo?, pats?, gap?, missiles?
        ASSERT count? >= 1 && count? <= 2, "CFG_ED_LEVELS: one or two divers"
        ASSERT hblue? >= 1 && hblue? <= 9 && hred? >= 1 && hred? <= 9
        ASSERT solo? == ED_BLUE || solo? == ED_RED
        ASSERT pats? >= 1 && pats? <= 15, "CFG_ED_LEVELS: at least one movement"
        ASSERT gap? >= 10 && gap? <= 255
        ASSERT missiles? == 0 || missiles? == 1
        db count?, hblue?, hred?, solo?, pats?, gap?, missiles?
        ENDM
ED_ROW_LEN      equ 7
        ASSERT ed_missiles == ed_count + ED_ROW_LEN - 1, "ed_level copies a row onto ed_count..ed_missiles"
ed_tab:
        CFG_ED_LEVELS
ED_ROWS         equ ($ - ed_tab) / ED_ROW_LEN
        ASSERT ED_ROWS >= 1

; The pointer tables, with the code in the data block: the odd shifts point
; at the even ones, as our diver's do (PRESHIFT_EVEN).
        MACRO ED_DATA
ed_blue_images:
        PRESHIFT_INDEX ed_blue_shifts, EDBLUE_PICS
ed_blue_shifts:
        PRESHIFT_EVEN ED_BUF_BLUE, EDBLUE_PICS, EDBLUE_HEIGHT, EDBLUE_RAW
        ASSERT pst_a == ED_BUF_BLUE + ED_SHIFTED, "the blue diver's tables and preshift disagree"
ed_red_images:
        PRESHIFT_INDEX ed_red_shifts, EDRED_PICS
ed_red_shifts:
        PRESHIFT_EVEN ED_BUF_RED, EDRED_PICS, EDRED_HEIGHT, EDRED_RAW
        ASSERT pst_a == ED_BUF_RED + ED_SHIFTED, "the red diver's tables and preshift disagree"
        ENDM
        ED_DATA                 ; here, in the data block with the code

    ENDIF
