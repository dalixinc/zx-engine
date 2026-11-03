;==============================================================================
; data.asm - words and lookup tables
;
; These bytes are not instructions. They live at DATA_START ($C000),
; above the code, so the code area below $C000 has room to grow. The
; pictures follow this file in the same region. Nothing here may reach
; the scroll buffers at $F000.
;
; The bytes do not change while the game runs. Each bomb keeps its own
; copy of the numbers it needs, in ordinary RAM next to the wheel code.
;==============================================================================

; --- The start screen --------------------------------------------------------
; Drawn by menu.asm. The play screen has none of these words: row 0 is
; kept clear for the stat line, and the water is empty apart from that.

str_title:      db "ATLANTIS",0
str_ctrl_swim:  db "QAOP or 5678 to swim",0
str_ctrl_stats: db "Symbol Shift + S  stats",0
str_ctrl_speed: db "Symbol Shift + F  speed",0
str_ctrl_menu:  db "Symbol Shift + P  menu",0
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

; Level 2's message (score.asm, teaser).
str_tease_1:    db "WELL DONE, YOU REACHED LEVEL 2.",0
str_tease_2:    db "STAY TUNED, MORE IS COMING",0
str_tease_key:  db "PRESS A KEY",0

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
        LEVEL_CODES

; The speed line is one of these two. They are the same length, so
; reprinting one on top of the other does not leave a stray letter.
; "50" and "25" are the only difference.
str_rate50:     db "2  50 frames a second",0
str_rate25:     db "2  25 frames a second",0

; The stat line, 32 characters, one per cell of row 0.
;   scan   spare scanlines in the last frame (two digits)
;   50/s   the speed, 50 or 25 frames a second
;   x y    the diver, in pixels
;   L      lives left
;   f      the television frame counter
; The digits are written over the zeros. The words stay put. The x and
; y digits sit against their letters, to make room for the lives.
stats_template:
        db "scan 00 50/s x000 y000 L0 f00000"
STATS_TEMPLATE_LEN equ $ - stats_template
        ASSERT STATS_TEMPLATE_LEN == 32, "the stat line has to be one row"

; --- A life ------------------------------------------------------------------
; One heart for each life left, on row 1 (hit.asm). The eight zero bytes
; after it are an empty cell, for a life that has gone.
lives_heart:
        db %00000000
        db %01101100
        db %11111110
        db %11111110
        db %01111100
        db %00111000
        db %00010000
        db %00000000
        ds 8, 0

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

; Eight heights for the middle of the bob. Entry 0 is the first bomb,
; before any random number: deep enough to meet the diver on the way
; down, not so high that it sits on row 0 while the checks are watching
; his photograph. Later bombs take the low 3 bits of the random byte.
; Entry 5 is the fish's depth. Entry 2 is the surface. Entry 7 is the
; lowest: one swing of the standard height still ends above the weed.

wheel_heights:
        db 36                   ; 0  diver's depth on the way down
        db 100                  ; 1
        db WHEEL_TOP_BASE       ; 2  surface: one swing below the top
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
;   kind           which movement. 0 drifts left and bobs.
;                  1 is reserved for a bomb that homes in on the diver.
;                  That routine is not written. Do not put 1 here:
;                  update_wheel will ignore the bomb rather than jump
;                  to a routine that does not exist. The commented line
;                  under wheel_kind_tab is the slot it will occupy.
;   colour         ink and paper, from CFG_WHEEL_INK
;
; A new type is another five bytes here, and a line in wheel_kind_tab
; if it moves in a way the drift routine does not. Each bomb copies the
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
        ; A homing type, when that routine exists, would be another row:
        ; db 6, 1, 0, 1, BRIGHT | RED | (BLUE << 3)
