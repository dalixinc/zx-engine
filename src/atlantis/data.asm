;==============================================================================
; data.asm - words and lookup tables
;
; These bytes are not instructions. They live at DATA_START ($C400),
; above the code, so the code area below it has room to grow. The
; pictures follow this file in the same region. Nothing here may reach
; the fish's and the pulsar's shifted copies (preshift.asm), which are
; built below the scroll buffers at $F000.
;
; The bytes do not change while the game runs. Each bomb keeps its own
; copy of the numbers it needs, in ordinary RAM next to the wheel code.
;==============================================================================

        COLD                    ; read by the menu and the message only
; --- The start screen --------------------------------------------------------
; Drawn by menu.asm. The play screen has none of these words: row 0 is
; kept clear for the stat line, and the water is empty apart from that.

str_ctrl_swim:  db "QAOP or 5678 to swim",0
    IFDEF STATS
str_ctrl_stats: db "Symbol Shift + S  stats",0
    ENDIF
str_ctrl_speed: db "Symbol Shift + F  speed",0
str_ctrl_menu:  db "Symbol Shift + P  menu",0
    IFDEF POWERUPS
str_ctrl_bomb:  db "Symbol Shift + B  bomb",0
    ENDIF
str_opt_start:  db "1  Start game",0
str_game_over:  db "GAME OVER",0
str_score:      db "SCORE ",0
str_high:       db "HIGH  ",0
; Option 3 and what it turns into. All the same length, so each one
; covers the last.
str_opt_code:   db "3  Enter code    ",0
str_code_ask:   db "3  Code ",0     ; then the letters typed so far
str_code_bad:   db "3  BAD CODE      ",0
str_code_dots:  db "......",0
str_code_word:  db "CODE ",0
str_level_sp:   db "LEVEL ",0

; The message for levels 2 and 3 (score.asm, teaser). The level's digit
; is written into the first line. The second line is level 2's or level
; 3's, centred.
str_tease_1:    db "WELL DONE, YOU REACHED LEVEL "
str_tease_n:    db "2.",0
str_tease_go:   db "LEVEL 2 STARTS NOW",0
TEASE_GO_COL    equ (32 - ($ - 1 - str_tease_go)) / 2
str_tease_2:    db "STAY TUNED, MORE IS COMING",0
TEASE_2_COL     equ (32 - ($ - 1 - str_tease_2)) / 2
str_tease_key:  db "PRESS A KEY",0
        HOT

; Row 1 in play: the words, with spaces where score.asm puts the numbers.
str_hud:        db "SCORE 000000  LEVEL   "
        ASSERT $ - str_hud == HUD_LEN
str_level:      db "LEVEL"

; The banner's block letters, three cells by five, bit 2 the left cell.
; "LEVEL" and the level codes (codes.asm) use the capitals. M, N, Q, W
; and X are rough at three cells wide, which is why no code uses them.
banner_font_sp: db 0, 0, 0, 0, 0
banner_font_a:  db %010, %101, %111, %101, %101 ; A
                db %110, %101, %110, %101, %110 ; B
                db %011, %100, %100, %100, %011 ; C
                db %110, %101, %101, %101, %110 ; D
                db %111, %100, %110, %100, %111 ; E
                db %111, %100, %110, %100, %100 ; F
                db %011, %100, %101, %101, %011 ; G
                db %101, %101, %111, %101, %101 ; H
                db %111, %010, %010, %010, %111 ; I
                db %001, %001, %001, %101, %010 ; J
                db %101, %101, %110, %101, %101 ; K
                db %100, %100, %100, %100, %111 ; L
                db %101, %111, %111, %101, %101 ; M
                db %110, %101, %101, %101, %101 ; N
                db %010, %101, %101, %101, %010 ; O
                db %110, %101, %110, %100, %100 ; P
                db %010, %101, %101, %110, %011 ; Q
                db %110, %101, %110, %101, %101 ; R
                db %011, %100, %010, %001, %110 ; S
                db %111, %010, %010, %010, %010 ; T
                db %101, %101, %101, %101, %111 ; U
                db %101, %101, %101, %101, %010 ; V
                db %101, %101, %111, %111, %101 ; W
                db %101, %101, %010, %101, %101 ; X
                db %101, %101, %010, %010, %010 ; Y
                db %111, %001, %010, %100, %111 ; Z
banner_font_0:  db %111, %101, %101, %101, %111
                db %010, %110, %010, %010, %111
                db %111, %001, %111, %100, %111
                db %111, %001, %011, %001, %111
                db %101, %101, %111, %001, %001
                db %111, %100, %111, %001, %111
                db %111, %100, %111, %101, %111
                db %111, %001, %010, %010, %010
                db %111, %101, %111, %101, %111
                db %111, %101, %111, %001, %111

; The levels (config.asm, score.asm).
level_tab:
        CFG_LEVELS
level_end:
LEVEL_COUNT_ROWS equ level_rows

; The level codes and the key map (codes.asm).
        COLD
        LEVEL_CODES

; The speed line is one of these two. They are the same length, so
; reprinting one on top of the other does not leave a stray letter.
; "50" and "25" are the only difference.
str_rate50:     db "2  50 frames a second",0
str_rate25:     db "2  25 frames a second",0
        HOT

; The stat line, 32 characters, one per cell of row 0.
;   scan   spare scanlines in the last frame (two digits)
;   50/s   the speed, 50 or 25 frames a second
;   x y    the diver, in pixels
;   L      lives left
;   f      the television frame counter
; The digits are written over the zeros. The words stay put. The x and
; y digits sit against their letters, to make room for the lives.
    IFDEF STATS
stats_template:
        db "scan 00 50/s x000 y000 L0 f00000"
STATS_TEMPLATE_LEN equ $ - stats_template
        ASSERT STATS_TEMPLATE_LEN == 32, "the stat line has to be one row"
    ENDIF

; (A life's heart is in the UDG area: udg.asm.)

        COLD
; --- Menu options ------------------------------------------------------------
; One row per option. menu.asm walks this list to draw the menu and to
; notice a key. To add an option later:
;   1. Put the words in a db "...",0 above.
;   2. Add a row here. The mask is which key on the 1-2-3-4-5 row:
;      key 1 is 1, key 2 is 2, key 3 is 4, key 4 is 8, key 5 is 16.
;      Keys 3, 4 and 5 are free.
;   3. Write a small routine. It returns with the carry flag set to
;      start the game, or clear to stay on the menu.
; A text address of 0 means "the speed line", which changes when it is
; pressed. A mask of 0 ends the list.
;
; mask, character row, character column, text address, routine address

menu_tab:
        db 1
        db 11
        db 4
        dw str_opt_start
        dw menu_start
        db 2
        db 12
        db 4
        dw 0
        dw menu_toggle_rate
        db 4
        db CODE_ROW
        db 4
        dw str_opt_code
        dw menu_code
        db 0
        HOT

; --- Wheel bomb tables -------------------------------------------------------
; The sine is one full swing, 32 steps, stored for a height of 6 pixels.
; It holds at the top and the bottom, which is the shape of a sine and
; not of a straight up-and-down. A different height scales these numbers
; (see wheel_bob_offset). With the height left at 6, the value is used
; as it stands, which is the original bob.

wheel_bob:
        db 0, 1, 2, 3, 4, 5, 5, 6
        db 6, 5, 5, 4, 3, 2, 1, 0
        db 0,-1,-2,-3,-4,-5,-5,-6
        db -6,-5,-5,-4,-3,-2,-1, 0

; The waves (level.asm): 128 heights each, a whole sine, AMP pixels up
; and down, rounded to the nearest pixel. Made here from one table of
; sines scaled to 127, so CFG_*_WAVE_AMP can be any size.
        MACRO WAVE_B amp, u
        IF u >= 0
        db (u * amp + 63) / 127
        ELSE
        db -((-(u) * amp + 63) / 127)
        ENDIF
        ENDM
        MACRO WAVE_8 amp, u0, u1, u2, u3, u4, u5, u6, u7
        WAVE_B amp, u0
        WAVE_B amp, u1
        WAVE_B amp, u2
        WAVE_B amp, u3
        WAVE_B amp, u4
        WAVE_B amp, u5
        WAVE_B amp, u6
        WAVE_B amp, u7
        ENDM
        MACRO WAVE_TABLE amp
        ASSERT amp >= 0 && amp <= 127
        WAVE_8 amp, 0, 6, 12, 19, 25, 31, 37, 43
        WAVE_8 amp, 49, 54, 60, 65, 71, 76, 81, 85
        WAVE_8 amp, 90, 94, 98, 102, 106, 109, 112, 115
        WAVE_8 amp, 117, 120, 122, 123, 125, 126, 126, 127
        WAVE_8 amp, 127, 127, 126, 126, 125, 123, 122, 120
        WAVE_8 amp, 117, 115, 112, 109, 106, 102, 98, 94
        WAVE_8 amp, 90, 85, 81, 76, 71, 65, 60, 54
        WAVE_8 amp, 49, 43, 37, 31, 25, 19, 12, 6
        WAVE_8 amp, 0, -6, -12, -19, -25, -31, -37, -43
        WAVE_8 amp, -49, -54, -60, -65, -71, -76, -81, -85
        WAVE_8 amp, -90, -94, -98, -102, -106, -109, -112, -115
        WAVE_8 amp, -117, -120, -122, -123, -125, -126, -126, -127
        WAVE_8 amp, -127, -127, -126, -126, -125, -123, -122, -120
        WAVE_8 amp, -117, -115, -112, -109, -106, -102, -98, -94
        WAVE_8 amp, -90, -85, -81, -76, -71, -65, -60, -54
        WAVE_8 amp, -49, -43, -37, -31, -25, -19, -12, -6
        ENDM
bomb_wave_tab:  WAVE_TABLE CFG_BOMB_WAVE_AMP
fish_wave_tab:  WAVE_TABLE CFG_FISH_WAVE_AMP

; Eight heights for the middle of the bob. Entry 0 is the first bomb,
; before any random number: deep enough to meet the diver on the way
; down, not so high that it sits on row 0 while the checks are watching
; his photograph. Later bombs take the low 3 bits of the random byte.
; Entry 5 is the fish's depth. Entry 2 is the surface. Entry 7 is the
; lowest: one swing of the standard height still ends above the weed.

wheel_heights:
        db 36                   ; 0  diver's depth on the way down
        db 100                  ; 1
        db WHEEL_TOP_BASE       ; 2  surface: one swing below the score row
        db 120                  ; 3
        db 50                   ; 4
        db 70                   ; 5  fish
        db 24                   ; 6
        db WHEEL_LOW_BASE       ; 7  one swing above the weed

; One row per enemy type: the pulsar, then the spinning wheel. Which one
; a bomb gets is the level's choice (wheel_type, CFG_LEVELS).
; Five bytes:
;   bob height     pixels above the middle, and the same below
;   bob speed      sine steps per 1/50 second
;   wobble         0 = smooth sine. See CFG_WHEEL_WOBBLE.
;   kind           which movement. 0 drifts left and bobs. The level
;                  puts its own over it (wheel_type, CFG_LEVELS bmove):
;                  1 the wave, 2 the hunter (level.asm).
;   colour         ink and paper, from CFG_WHEEL_INK
;
; A new type is another five bytes here, and a routine and a test in
; update_wheel if it moves in a way the others do not. Each bomb copies the
; five bytes when it appears, then (if wobble is not 0) rolls its own
; variation on top.

ENEMY_ROW       equ 5

enemy_types:
enemy_wheel:
        db CFG_WHEEL_BOB
        db CFG_WHEEL_BOB_SPEED
        db CFG_WHEEL_WOBBLE
        db 0
        db CFG_WHEEL_INK
enemy_spin:                     ; the spinning wheel (wspin.asm): its ink
        db CFG_WHEEL_BOB
        db CFG_WHEEL_BOB_SPEED
        db CFG_WHEEL_WOBBLE
        db 0
        db CFG_SPIN_INK
