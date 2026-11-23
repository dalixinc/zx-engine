;==============================================================================
; city.asm - the end of Finale: Trigon City and the bomb drop (TRIGON_END:
; booting to the menu)
;
; When level CFG_ENDING_LEVEL is finished, level_up comes here instead of
; the next level's banner, and the game stops where it is. The screen
; goes black, and the city comes on in a circle (ct_circle). Then the
; drop: the diver swims above the city with the bomb under him, and fire
; lets it go. It falls through the shields, bars of one colour that
; slide across the city, into the power generator, cells that flash at
; the foot of the city. A shield stops it, and so does the bottom of the
; city: CFG_DROP_TRIES bombs in all.
;
; Into the generator: a white blast grows from it over the whole screen,
; then the dark, then the ending's words until a fresh key, the high
; score and the menu. With no bombs left: the words, then the game
; starts again at CFG_DROP_RETRY_LEVEL, as its level code would.
;
; The picture is packed at the top of the cold block's room, $8000 down
; (city_pix_zx0, main.asm): free while the game runs, and on the tape at
; the end of the second block, which city_go copies up before the game
; starts (tape.asm). It is the Atlantis city (gfx/finale/city.scr, from
; tools/mkcity.py --finale) until Erin's Trigon City replaces it.
; Its colours wait in the seabed's buffers (CT_ATTRS), which game_reset
; draws again, while it is up.
;
; It runs once a game: here in the cold block, and its busier half in
; cityhi.asm, above the run-time buffers. The diver is drawn with
; the game's own routines; the bomb is an 8 x 8 picture at a whole cell
; column, its background kept in ct_save. The frames are paced by
; spare_count (ct_wait), so the game's sounds play.
;==============================================================================

    IFDEF TRIGON_END

CT_ATTRS        equ SCROLL_BASE         ; the picture's colours (768 bytes)
        ASSERT SCROLL_BUF_END - SCROLL_BASE >= ATTRS_SIZE, "the city's colours do not fit the seabed's buffers"

CT_LEFT         equ 4                   ; the city's cells (mkcity.py)
CT_WIDE         equ 24
CT_BOTTOM       equ 19                  ; its last cell row
CT_DIVER_Y      equ 8                   ; his top, rows 1 to 2
CT_HOLD_Y       equ 24                  ; the bomb's top while he holds it: row 3
CT_TEXT         equ BRIGHT | WHITE      ; on black
CT_BOMBS_ROW    equ 23
CT_BOMBS_COL    equ 12
CT_STEP         equ 3                   ; half cells a ring
CT_RIM          equ 4                   ; the ring's width, half cells
CT_R_END        equ 52                  ; past the farthest corner from the generator
CT_BLAST        equ BRIGHT | WHITE | (WHITE << 3)

        ASSERT CFG_DROP_TRIES >= 1 && CFG_DROP_TRIES <= 9, "CFG_DROP_TRIES: one digit"
        ASSERT CFG_DROP_SPEED >= 1 && CFG_DROP_SPEED <= 8, "CFG_DROP_SPEED: the bomb would jump a shield's row"
        ASSERT CFG_DROP_RETRY_LEVEL >= 1 && CFG_DROP_RETRY_LEVEL <= CFG_ENDING_LEVEL
        ASSERT CFG_GEN_ROW >= 4 && CFG_GEN_ROW + CFG_GEN_HIGH - 1 <= CT_BOTTOM, "the generator is off the city"
        ASSERT CFG_GEN_COL >= CT_LEFT && CFG_GEN_COL + CFG_GEN_WIDE <= CT_LEFT + CT_WIDE, "the generator is off the city"
        ASSERT CFG_GEN_ATTR != CFG_SHIELD_ATTR

;------------------------------------------------------------------------------
; ct_city - level_up: the next level would be CFG_ENDING_LEVEL + 1.
; Never returns.
;------------------------------------------------------------------------------
ct_city:
        ld sp,STACK_TOP         ; nothing here returns to the game
    IFNDEF NO_SOUND
        call snd_reset
        ld a,1
        ld (snd_gate),a         ; every wait plays, as at 50
    ENDIF
        ; Black first: the pixels go on under black cells, unseen.
        xor a
        ld (ct_drawn),a
        call ct_border
        xor a
        call cls
        ld hl,city_pix_zx0
        ld de,SCREEN
        call dzx0_standard
        ld hl,city_atr_zx0
        ld de,CT_ATTRS
        call dzx0_standard
        ; The generator, in the picture's colours, so it stays.
        ld hl,CT_ATTRS + CFG_GEN_ROW * 32 + CFG_GEN_COL
        ld b,CFG_GEN_HIGH
.gen:   push bc
        push hl
        ld b,CFG_GEN_WIDE
.genc:  ld (hl),CFG_GEN_ATTR
        inc hl
        djnz .genc
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        djnz .gen
        ; The words in black: the circle gives them their colour.
        ld a,CFG_DROP_TRIES
        ld (ct_tries),a
        ld hl,ct_words
        call ct_lines
        call ct_status
    IFNDEF NO_SOUND
        ld hl,snd_tune_level    ; the level jingle, as it comes on
        call snd_tune_start
    ENDIF
        ld bc,(24 << 8) | 32    ; the middle of the screen, in half cells
        ld a,CT_TEXT
        call ct_circle
        ; A second whatever is pressed: fire, still going from the fight,
        ; must not throw the picture away, or the first bomb.
        ld b,50
.hold:  call wait_frame
        djnz .hold
        ld d,CFG_CITY_TIME
        call ct_key

        ; The drop.
        ld a,CT_TEXT
        ld (text_attr),a
        xor a
        ld (diver_bg),a         ; nothing under him yet
        ld a,CT_DIVER_Y
        ld (diver_y),a
        jp ct_try

        PBUF                    ; the drop, in the printer buffer (main.asm)
ct_try:
        ld a,CT_HOLD_Y
        ld (ct_by),a
        xor a
        ld (ct_fall),a
        ; Each frame draws first, at the top of the frame, ahead of the
        ; beam (he is on rows 1 and 2), then works out the next one.
.frame: call ct_wait
        call ct_bomb_off
        call diver_restore_fast
        call diver_draw_fast
        call ct_bomb_on
        call ct_shields
        call read_input
        ; Left and right, two pixels a 1/50 second, as in the game.
        ld a,(input_state)
        ld c,a
        ld hl,diver_x
        xor a
        ld (diver_moving),a
        bit IN_LEFT_BIT,c
        jr z,.right
        ld a,(hl)
        cp 2
        jr c,.right
        sub 2
        ld (hl),a
        ld a,FACE_LEFT
        jr .moved
.right: bit IN_RIGHT_BIT,c
        jr z,.bomb
        ld a,(hl)
        cp 256 - 24
        jr nc,.bomb
        add a,2
        ld (hl),a
        ld a,FACE_RIGHT
.moved: ld (diver_facing),a
        ld a,1
        ld (diver_moving),a
        ld hl,diver_anim
        inc (hl)
.bomb:  ld a,(ct_fall)
        or a
        jr nz,.fall
        ; Held: under his middle, until a fresh press of fire.
        ld a,(diver_x)
        add a,12
        rrca
        rrca
        rrca
        and 31
        ld (ct_bcol),a
        ld a,(input_prev)
        cpl
        and c
        and IN_FIRE
        jr z,.next
        ld (ct_fall),a
    IFNDEF NO_SOUND
        call snd_launch_start
    ENDIF
.next:  jp .frame
.fall:  ld a,(ct_by)
        add a,CFG_DROP_SPEED
        ld (ct_by),a
        add a,7                 ; its bottom row's cell
        rrca
        rrca
        rrca
        and 31
        cp CT_BOTTOM + 1
        jr nc,.missed
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(ct_bcol)
        or l
        ld l,a
        ld de,ATTRS
        add hl,de
        ld a,(hl)               ; the shields are painted after the bomb
        cp CFG_SHIELD_ATTR
        jr z,.stopped
        ld de,CT_ATTRS - ATTRS
        add hl,de
        ld a,(hl)               ; the generator: in the picture's colours,
        cp CFG_GEN_ATTR         ; which the bomb's own do not hide
        jr nz,.next
        jp ct_hit

.stopped:
        ld a,RED
        call ct_border
    IFNDEF NO_SOUND
        call snd_boom_start
    ENDIF
        jr .lost
.missed:
    IFNDEF NO_SOUND
        call snd_missile_start
    ENDIF
.lost:  call ct_bomb_off
        ld b,40                 ; a moment, the shields still sliding
.pause: push bc
        call ct_wait
        call ct_shields
        pop bc
        djnz .pause
        xor a
        call ct_border
        ld hl,ct_tries
        dec (hl)
        jp z,ct_fail
        call ct_status
        jp ct_try
        PB_COLD

; No bombs left: the words, then the game again at CFG_DROP_RETRY_LEVEL.
ct_fail:
        ld hl,ct_fail_words
        call ct_page
        call score_game_over    ; the high score counts
        ld a,CFG_DROP_RETRY_LEVEL
        ld (start_level),a
        jp game_reset

; Into the generator: the blast, then the dark, then the ending.
ct_hit:
    IFNDEF NO_SOUND
        call snd_diver_start    ; the longest crunch
    ENDIF
        ld a,WHITE
        call ct_border
        ld a,CT_BLAST
        call ct_fill
        ld bc,((CFG_GEN_ROW * 2 + CFG_GEN_HIGH) << 8) | (CFG_GEN_COL * 2 + CFG_GEN_WIDE)
        push bc
        ld a,BRIGHT | (YELLOW << 3)
        call ct_circle
        xor a
        call ct_fill            ; A stays 0
        call ct_border
        pop bc
        ld a,RED << 3
        call ct_circle
        ld hl,ct_end_words
        call ct_page
        call score_game_over    ; a new high score?
        xor a
        ld (menu_game_over),a   ; not GAME OVER: he won
        jp enter_menu           ; it starts the stack again


        HOT                     ; the words: the cold block is full
; Each line: row, column, colour, the words, 0. A row of 255 ends them.
; The city's are black until the circle reaches them.
ct_words:
        db 0, 10, 0, "TRIGON CITY", 0
        db 21, 7, 0, "Bomb the generator.", 0
        db CT_BOMBS_ROW, CT_BOMBS_COL, 0, "BOMBS", 0
        db 255
ct_fail_words:
        db 9, 6, CT_TEXT, "The bombs are spent.", 0
        db 11, 8, CT_TEXT, "Back to level ", '0' + CFG_DROP_RETRY_LEVEL, 0
        db 255
        ASSERT CFG_DROP_RETRY_LEVEL <= 9, "the words have one digit for the level"
ct_end_words:
        db 6, 7, CT_TEXT, "TRIGON CITY FALLS", 0
        db 9, 5, BRIGHT | YELLOW, "THE BLOCKADE IS BROKEN", 0
        db 11, 8, BRIGHT | YELLOW, "ATLANTIS IS FREE", 0
        db 255
str_ct_key:     db "PRESS A KEY", 0
        COLD
        PBUF                    ; its records, there too

ct_tries:       db 0            ; bombs left
ct_fall:        db 0            ; 0 = he holds it
ct_by:          db 0            ; the bomb's top, in pixels
ct_bcol:        db 0            ; and its cell column
ct_drawn:       db 0            ; 1 = it is on the screen, ct_save under it
ct_dy:          db 0            ; where it was drawn
ct_dcol:        db 0
ct_r:           db 0            ; the circle: its radius, in half cells
ct_in:          dw 0            ; its square
ct_rim:         dw 0            ; the ring's outer square
ct_dy2:         dw 0            ; this row's distance, squared
ct_save:        ds 8            ; what is under the bomb
ct_bomb_art:                    ; the bomb, 8 x 8, its fins up
        db %00111100
        db %00011000
        db %00111100
        db %01111110
        db %11111111
        db %11111111
        db %01111110
        db %00111100
        ASSERT ct_bomb_art == ct_save + 8, "ct_bomb_io reads the picture 8 past the save"
        PB_COLD

;------------------------------------------------------------------------------
; city_go - the tape's way in (tape.asm's go jumps here, not to entry):
; the packed city, then cityhi.asm, from the end of the second block to
; their places, before anything at start-up can write over them. The
; city goes first: the second copy lands on the tape's copy of it. That
; one moves up over its own tail, so it is copied from the top down.
; The snapshot has both in place already, and starts at entry.
;------------------------------------------------------------------------------
CT_TAPE_HIGH    equ UDG_START - CITY_LEN - CT_HIGH_LEN  ; where the tape leaves them
CT_TAPE_PB      equ CT_TAPE_HIGH - PB_LEN               ; and, before them, the printer buffer's
CT_TAPE_FONT    equ CT_TAPE_PB - FONT_LEN               ; and the letters
city_go:
        ld hl,CT_TAPE_FONT      ; the letters, first: the printer
        ld de,FONT_RUN          ; buffer's copy lands lower than they
        ld bc,FONT_LEN          ; were (font.asm)
        ldir
        ld hl,CT_TAPE_PB        ; the printer buffer's routines to where
        ld de,PB_SRC            ; boot copies them from (main.asm)
        ld bc,PB_LEN
        ldir
        ld hl,UDG_START - CITY_LEN
        ld de,city_pix_zx0
        ld bc,CITY_LEN
        ldir
        ld hl,CT_TAPE_HIGH + CT_HIGH_LEN - 1
        ld de,ct_high_end - 1
        ld bc,CT_HIGH_LEN
        lddr
        jp entry
        ASSERT CT_TAPE_HIGH + CT_HIGH_LEN - 1 < ct_high_end - 1, "city_go's copy of cityhi.asm must go up (LDDR)"

    ENDIF
