;==============================================================================
; freeze.asm - play stops while a level's banner is up (Atlantis only:
; BANNER_FREEZE)
;
; A new level's "LEVEL n" banner, and the code under it, used to sit on a
; game still going: the bomb, the fish and the missiles moved and fired,
; the diver could die reading it, and sprites crossing it broke up the
; letters. Now, while it is up:
;
; NOTHING MOVES. The death's freeze does it (death_freeze, death.asm):
; main_loop's two jumps skip the seabed's shifts and every move, so each
; step only restores and draws the sprites where they are. No movement,
; no firing, no hits, no points, no counting down. Only the bursts and
; pop-ups already going finish, and the sound plays on (the level's
; jingle). The moves' jump goes to bf_step, not death_step: it keeps
; step_ticks at 1, so at 25 the idle frame, which would move things,
; never runs (as Trigon's tp_frozen does). The double shot's clock is
; frame_count, which goes on counting, so it is pushed on by the
; banner's time, the way the quake pushes it.
;
; NOTHING SHOWS THROUGH IT. The banner is attribute cells only: its
; letters' blocks are yellow on yellow (BANNER_SOLID), and every other
; cell of its rows, the code's rows too, and a row above and below them,
; is the water's blue on blue (BANNER_HIDE). A cell whose ink is its paper shows no pixels, so a
; sprite, a burst or a pop-up behind it is hidden. A banner is a still,
; clean panel in front of the frozen game. Two things would still write
; colours on it, so both are turned aside while it is up. The bomb's
; (wheel_colours, which keeps them up to date as it moves, and puts back
; its own cells) is switched off by making its first byte a RET. A fish
; shot just before, with a burst already up, finishes its yellow and red
; flash (fish_flash_draw), so fish_paint's first bytes become a JP to
; bf_fish_paint, which paints only the cells outside the banner's rows.
; (Painting the banner again every 8 frames instead cost a frozen step
; more than it had: 35 late steps in a measurement, against none.)
;
; PLAY GOES ON exactly where it stopped: on the last frozen step, the
; one before the banner's time is up, bf_step calls bf_thaw, which puts
; the bomb's colours back, paints the banner's rows back to plain water
; and puts the speed's jumps back (rate_apply); then the banner is taken
; down there (the bomb paints its own cells again) and level 2's message
; is set to follow, as banner_tick did. All of it after the step's draws,
; with time to spare, so the next step is an ordinary one. banner_tick
; (bf_down) still takes down the nuke's word, and a level's banner if a
; late step ever missed it.
;
; THE MARK. wheel_colours' first byte is the record of the freeze:
; RET ($C9) while a level's banner holds the game, CALL ($CD) otherwise.
; So bf_fire (B, a special bomb: not under the banner), bf_rate (a change
; of speed, or the end of a death: frozen again if the banner is still
; up) and bf_down (the nuke's own word, which uses the banner's clock
; but freezes nothing) all read it. enter_menu puts it back (bf_off), so
; a game left under a banner, or ended there, starts the next one clean
; (fish_paint's bytes go back with it).
;
; WHERE IT LIVES: all in the data block (FREEZE_CODE, expanded by
; main.asm), which is not contended; banner_show, enter_menu, banner_tick,
; rate_apply and sp_poll only call or jump here. The data block's room
; is the city's: its colours now wait in the seabed's buffers while the
; city is up (interlude.asm), as Finale's do.
;==============================================================================

BANNER_SOLID    equ BRIGHT | YELLOW | (YELLOW << 3) ; the letters: no pixels show
BANNER_HIDE     equ SEA | ((SEA >> 3) & 7)          ; the water round them, likewise
BF_TOP          equ BANNER_ROW - 1      ; the panel: a row of water above the letters,
BF_ROWS         equ 1 + 5 + 1           ; their 5 rows (banner_line), and a row below
BF_CODE_ROWS    equ 1 + 5 + 1 + 5 + 1   ; with the code's 5 under them, and one below:
                                        ; a sprite just past it reads as part of a letter
BF_RET          equ $C9
BF_CALL         equ $CD                 ; (torpedo.asm's OP_CALL is the double shot's only)
BF_JP           equ $C3
BF_PUSH_AF      equ $F5                 ; fish_paint's first bytes: PUSH AF,
BF_LD_A_NN      equ $3A                 ; LD A,(fish_arow)

        MACRO FREEZE_CODE

;------------------------------------------------------------------------------
; bf_on - banner_show, a level's banner just painted: freeze the game
; In: DE = the banner's time, in television frames.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
bf_on:
    IFDEF DOUBLE_SHOT
        ld hl,(double_until)
        add hl,de
        ld (double_until),hl    ; its time stands still too (harmless if none)
    ENDIF
        ld a,BF_RET
        ld (wheel_colours),a    ; the bomb keeps its colours off the banner
        ld a,BF_JP
        ld hl,bf_fish_paint
        call bf_fish            ; and the fish's flash too
        ld a,BANNER_HIDE
        call bf_box             ; the panel: its rows blue on blue,
        ld a,BANNER_SOLID
        call banner_paint       ; its letters (and the code's) yellow on yellow
        ld a,(death_t)
        or a                    ; (a level is never won while he dies,
        ; fall through          ;  but if it were, the death would go on)

;------------------------------------------------------------------------------
; bf_rate - rate_apply's last test, with the flags of "death_t or a": a
; death keeps its own freeze, and a level's banner still up keeps its,
; whatever speed was just set (Symbol Shift + F, or a death that ended).
; Corrupts: AF, HL
;------------------------------------------------------------------------------
bf_rate:
        jp nz,death_freeze      ; dying: the death's freeze, as before
        ld a,(wheel_colours)
        cp BF_RET
        ret nz                  ; no banner holding the game
        call death_freeze       ; no shifts, no moves; step_ticks 1
        ld hl,bf_step
        ld (step_jp_move + 1),hl ; the moves' jump: here, not death_step
        ret

;------------------------------------------------------------------------------
; bf_step - main_loop's jump in place of the moves, while a level's banner
; is up. Every sprite has been drawn, where it was, for this step.
;------------------------------------------------------------------------------
bf_step:
        ld a,1
        ld (step_ticks),a       ; at 25 a kill in the idle frame left 2:
                                ; 1, so no idle frame runs the moves
    IFNDEF NO_SOUND
        ld (snd_gate),a         ; and the jingle plays in every wait
    ENDIF
        ; Does the banner come down at the next frame? Then it comes down
        ; now, and play goes on, at the end of this step, which has time
        ; to spare. Done by banner_tick at the top of the next step, the
        ; work held that step's draws past the beam: the sprites vanished
        ; for a frame.
        ld hl,(frame_count)
        inc hl
        ld de,(banner_until)
        or a
        sbc hl,de
        add hl,hl               ; signed, as banner_tick
        jp c,step_moved         ; not yet
        call bf_thaw            ; play again
        ld hl,hud_dirty
        res HUD_BANNER,(hl)     ; down: banner_tick has nothing more to do
        call banner_bomb        ; the bomb paints its own cells again
    IFDEF TEASER
        call banner_tick.tease  ; level 2's message, at the end of this step
    ENDIF
        jp step_moved           ; at 25 the idle frame moves things already

; (banner_paint also tells the bomb to paint its cells again: they are
; the banner's until wheel_colours is a CALL again.)

;------------------------------------------------------------------------------
; bf_fish_paint - fish_paint (boom.asm) while a level's banner is up, by
; the JP over its first bytes: A = the colour for the fish's two rows of
; three cells, but a row in the panel's rows (the code's too, with a
; code or not) is left as it is. Corrupts: AF, BC, D, HL
;------------------------------------------------------------------------------
bf_fish_paint:
        ld d,a                  ; the colour
        ld a,(fish_acol)
        ld c,a
        ld a,(fish_arow)
        ld b,a
        call bf_fish_row        ; the top row,
        inc b                   ; then the one below
bf_fish_row:
        ld a,b
        sub BF_TOP
        cp BF_CODE_ROWS
        ret c                   ; the banner's: left alone
        call attr_addr          ; HL = the row's first cell (B, C kept)
        ld (hl),d
        inc l
        ld (hl),d
        inc l
        ld (hl),d
        ret

;------------------------------------------------------------------------------
; bf_box - every cell of the panel's rows (the banner's, the code's too if
; it has one, and the margins), across the whole screen. In: A = the
; attribute.
; bf_water - all of them, code or not, back to plain water: a banner that
; replaced one with a code (two levels at once) leaves none hidden.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
bf_water:
        ld a,WATER_ATTR
        ld bc,BF_CODE_ROWS * 32 - 1
        jr bf_fill
bf_box:
        ld bc,BF_ROWS * 32 - 1
        ld hl,banner_code
        inc (hl)
        dec (hl)
        jr z,bf_fill
        ld bc,BF_CODE_ROWS * 32 - 1
bf_fill:
        ld hl,ATTRS + BF_TOP * 32
        ld de,ATTRS + BF_TOP * 32 + 1
        ld (hl),a
        ldir
        ret

;------------------------------------------------------------------------------
; bf_down - banner_tick, the banner's time is up: it comes down
; (banner_erase), as before. A level's has normally come down already
; (bf_step); if a late step missed that, play goes on from here.
; bf_thaw - play again: the bomb's colours, the banner's rows back to the
; water, and the speed's jumps (a death keeps its own).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
bf_down:
        ld a,(wheel_colours)
        cp BF_RET
        call z,bf_thaw          ; not yet: a step was late
        jp banner_erase         ; and the bomb paints its own cells again
bf_thaw:
        call bf_off             ; the bomb's colours again
        call bf_water           ; the banner's rows back to the water
        ld a,(game_rate)
        jp rate_apply           ; no longer frozen: the speed's jumps

    IFDEF POWERUPS
;------------------------------------------------------------------------------
; bf_fire - sp_poll, B just pressed with a special bomb held: set it off,
; but not under a level's banner (it stays held for afterwards).
; Corrupts: AF, BC, DE, HL (as special_fire)
;------------------------------------------------------------------------------
bf_fire:
        ld a,(wheel_colours)
        cp BF_RET
        ret z
        jp special_fire
    ENDIF

;------------------------------------------------------------------------------
; bf_off - enter_menu, and bf_thaw: no game frozen any more (it may have
; been left, or lost, under a banner): the bomb's colours and fish_paint
; as they were. Corrupts: AF, HL
; bf_fish - A, HL = fish_paint's first three bytes.
;------------------------------------------------------------------------------
bf_off:
        ld a,BF_CALL
        ld (wheel_colours),a
        ld a,BF_PUSH_AF
        ld hl,BF_LD_A_NN | (low fish_arow << 8)
bf_fish:
        ld (fish_paint),a
        ld (fish_paint + 1),hl
        ret

        ASSERT ({wheel_colours} & $FF) == BF_CALL, "wheel_colours does not start with a CALL: the freeze's mark"
        ASSERT {fish_paint} == BF_PUSH_AF | (BF_LD_A_NN << 8) && ({fish_paint + 2} & $FF) == low fish_arow, "fish_paint does not start PUSH AF : LD A,(fish_arow)"
        ASSERT BF_TOP + BF_CODE_ROWS <= BACK_ROW, "the banner's rows reach the seabed"

        ENDM
