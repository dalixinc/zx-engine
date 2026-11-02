;==============================================================================
; silo.asm - the silo's picture, and the code that draws it
;
; 16 wide, 24 tall, one character row in each band of the seabed:
;
;   ................   row 21: the dome. Green on blue: scroll.asm paints
;   .....######.....   the cells it has ink in the seaweed's colour, so a
;   ....#-####-#....   plant passing through the same cell is green too.
;   ...##########...   Paper (-) only inside the ink, or a cell could be
;   ..############..   green with nothing in it.
;   ..############..
;   .##############.
;   ################
;   -##############-   row 22: the tower. Yellow on blue. The paper down
;   -#-##########-#-   each side cuts it out of the dunes. In the middle,
;   -#-##------##-#-   cut in blue, the Trigon's serifed T, the one on
;   -#-##-#--#-##-#-   the hub of the wheel bomb (gfx/wheel.txt).
;   -######--######-
;   -#-####--####-#-
;   -#-###----###-#-
;   -##############-
;   ################   row 23: the base, in the ground buffer. Black on
;   ################   yellow. Only the ink is used: these 16 bytes
;   ##-##########-##   replace two ground columns, and every clear bit is
;   ################   the row's yellow paper.
;   ################
;   ################
;   ################
;   ################
;
;   #  ink    -  paper (opaque)    .  see-through
;
; A missile waits in the hatch, centred on pixels 5-10 (missile.asm).
;
; The dome and the tower are drawn on every frame, at the ground's fine
; scroll, so they are the most-drawn picture in the game. They are not
; a table walked by one loop. Each of the 8 shifts is its own straight
; run of code, built here by the assembler from the rows below: a byte
; the silo covers completely is one LD (HL),n, a byte it does not touch
; is left out, and only the edge bytes are masked. That is about half
; the time of the masked loop, which is still used where a silo hangs
; off an edge of the screen (silo_pics, the same picture as data).
;==============================================================================

; Each row is the ink (SILO_Dn) and the opaque pixels, ink or paper
; (SILO_On). Bit 15 is the leftmost pixel.
SILO_D0         equ %0000000000000000
SILO_O0         equ %0000000000000000
SILO_D1         equ %0000011111100000
SILO_O1         equ %0000011111100000
SILO_D2         equ %0000101111010000
SILO_O2         equ %0000111111110000
SILO_D3         equ %0001111111111000
SILO_O3         equ %0001111111111000
SILO_D4         equ %0011111111111100
SILO_O4         equ %0011111111111100
SILO_D5         equ %0011111111111100
SILO_O5         equ %0011111111111100
SILO_D6         equ %0111111111111110
SILO_O6         equ %0111111111111110
SILO_D7         equ %1111111111111111
SILO_O7         equ %1111111111111111

; The T is pixels 5-10, cleared out of the yellow: the bar, the two
; serifs hanging from its ends, the stem, and the wider foot.
SILO_TOWER_A    equ %0111111111111110
SILO_TOWER_B    equ %0101111111111010
SILO_D8         equ SILO_TOWER_A
SILO_D9         equ SILO_TOWER_B
SILO_D10        equ %0101100000011010   ; bar
SILO_D11        equ %0101101001011010   ; serifs, and the top of the stem
SILO_D12        equ %0111111001111110   ; stem
SILO_D13        equ %0101111001111010   ; stem
SILO_D14        equ %0101110000111010   ; foot
SILO_D15        equ SILO_TOWER_A
SILO_O_TOWER    equ %1111111111111111

; The base, in the ground buffer: ink only.
SILO_B0         equ %1111111111111111
SILO_B1         equ %1111111111111111
SILO_B2         equ %1101111111111011
SILO_B3         equ %1111111111111111
SILO_B4         equ %1111111111111111
SILO_B5         equ %1111111111111111
SILO_B6         equ %1111111111111111
SILO_B7         equ %1111111111111111

; The dome's ink, all rows together: which bytes of the screen it uses.
SILO_DOME_INK   equ SILO_D0|SILO_D1|SILO_D2|SILO_D3|SILO_D4|SILO_D5|SILO_D6|SILO_D7

SILO_ROW_BYTES  equ 6           ; mask and data, three bytes a row
SILO_PIC_BYTES  equ 16 * SILO_ROW_BYTES

; --- the picture as data, for the edges ----------------------------------------
; Shift s puts the silo's left pixel s pixels into the first byte, as
; gfx2asm's tables do. Each row: mask, data for three bytes. Mask 1 keeps
; the screen.
        MACRO SILO_ROWDB dat, opq
silo_w = (dat) << (8 - silo_s)
silo_o = (opq) << (8 - silo_s)
        db ~(silo_o >> 16) & 255, (silo_w >> 16) & 255
        db ~(silo_o >> 8) & 255, (silo_w >> 8) & 255
        db ~silo_o & 255, silo_w & 255
        ENDM

        MACRO SILO_TABLE s
silo_s = s
        SILO_ROWDB SILO_D0, SILO_O0
        SILO_ROWDB SILO_D1, SILO_O1
        SILO_ROWDB SILO_D2, SILO_O2
        SILO_ROWDB SILO_D3, SILO_O3
        SILO_ROWDB SILO_D4, SILO_O4
        SILO_ROWDB SILO_D5, SILO_O5
        SILO_ROWDB SILO_D6, SILO_O6
        SILO_ROWDB SILO_D7, SILO_O7
        SILO_ROWDB SILO_D8, SILO_O_TOWER
        SILO_ROWDB SILO_D9, SILO_O_TOWER
        SILO_ROWDB SILO_D10, SILO_O_TOWER
        SILO_ROWDB SILO_D11, SILO_O_TOWER
        SILO_ROWDB SILO_D12, SILO_O_TOWER
        SILO_ROWDB SILO_D13, SILO_O_TOWER
        SILO_ROWDB SILO_D14, SILO_O_TOWER
        SILO_ROWDB SILO_D15, SILO_O_TOWER
        ENDM

; silo_pics, silo_cellbits and the base are data: main.asm puts them
; with the pictures above $C000 (SILO_DATA, below).

; Per shift: bit j set when byte j has dome ink (for the cell colours).
        MACRO SILO_CELLBITS s
silo_w = SILO_DOME_INK << (8 - s)
        ; (b + 255) >> 8 is 1 for a byte that is not 0, and 0 for 0.
        db ((((silo_w >> 16) & 255) + 255) >> 8) | (((((silo_w >> 8) & 255) + 255) >> 8) << 1) | ((((silo_w & 255) + 255) >> 8) << 2)
        ENDM

; The tables, emitted where main.asm says (the data block).
        MACRO SILO_DATA
silo_pics:
        SILO_TABLE 0
        SILO_TABLE 1
        SILO_TABLE 2
        SILO_TABLE 3
        SILO_TABLE 4
        SILO_TABLE 5
        SILO_TABLE 6
        SILO_TABLE 7
        ASSERT $ - silo_pics == 8 * SILO_PIC_BYTES

silo_cellbits:
        SILO_CELLBITS 0
        SILO_CELLBITS 1
        SILO_CELLBITS 2
        SILO_CELLBITS 3
        SILO_CELLBITS 4
        SILO_CELLBITS 5
        SILO_CELLBITS 6
        SILO_CELLBITS 7

; The base's two halves, top row first: the left 8 pixels, the right 8.
silo_base_l:    db high SILO_B0, high SILO_B1, high SILO_B2, high SILO_B3
                db high SILO_B4, high SILO_B5, high SILO_B6, high SILO_B7
silo_base_r:    db low SILO_B0, low SILO_B1, low SILO_B2, low SILO_B3
                db low SILO_B4, low SILO_B5, low SILO_B6, low SILO_B7

        ENDM

; --- the picture as code -------------------------------------------------------
; In:  HL = screen, row 21's top line, the silo's first column (0..29).
; Corrupts: AF, BC, HL
;
; One line of one row. The bytes are visited left to right on even
; lines and right to left on odd ones, so L only moves to the next byte
; that needs writing. silo_cur is where L is, as an offset from the
; first column.
        MACRO SILO_BYTE j
silo_ob = (silo_o >> (16 - 8 * j)) & 255
silo_db = (silo_w >> (16 - 8 * j)) & 255
        IF silo_ob
        IF j > silo_cur
        DUP j - silo_cur
        inc l
        EDUP
        ENDIF
        IF j < silo_cur
        DUP silo_cur - j
        dec l
        EDUP
        ENDIF
silo_cur = j
        IF silo_ob == 255
        ld (hl),silo_db         ; all silo: 10 T-states
        ELSE
        ld a,(hl)
        IF silo_db != silo_ob
        and ~silo_ob & 255      ; paper among the edge bits
        ENDIF
        or silo_db
        ld (hl),a
        ENDIF
        ENDIF
        ENDM

        MACRO SILO_LINE dat, opq, down
silo_w = (dat) << (8 - silo_s)
silo_o = (opq) << (8 - silo_s)
        IF silo_dir
        SILO_BYTE 2
        SILO_BYTE 1
        SILO_BYTE 0
        ELSE
        SILO_BYTE 0
        SILO_BYTE 1
        SILO_BYTE 2
        ENDIF
silo_dir = 1 - silo_dir
        IF down
        inc h
        ENDIF
        ENDM

        MACRO SILO_CODE s
silo_s = s
silo_cur = 0
silo_dir = 0
        SILO_LINE SILO_D0, SILO_O0, 1
        SILO_LINE SILO_D1, SILO_O1, 1
        SILO_LINE SILO_D2, SILO_O2, 1
        SILO_LINE SILO_D3, SILO_O3, 1
        SILO_LINE SILO_D4, SILO_O4, 1
        SILO_LINE SILO_D5, SILO_O5, 1
        SILO_LINE SILO_D6, SILO_O6, 1
        SILO_LINE SILO_D7, SILO_O7, 0
        ld bc,$10000 - $700 + 32 ; seven lines up, one character row down
        add hl,bc
        SILO_LINE SILO_D8, SILO_O_TOWER, 1
        SILO_LINE SILO_D9, SILO_O_TOWER, 1
        SILO_LINE SILO_D10, SILO_O_TOWER, 1
        SILO_LINE SILO_D11, SILO_O_TOWER, 1
        SILO_LINE SILO_D12, SILO_O_TOWER, 1
        SILO_LINE SILO_D13, SILO_O_TOWER, 1
        SILO_LINE SILO_D14, SILO_O_TOWER, 1
        SILO_LINE SILO_D15, SILO_O_TOWER, 0
        ret
        ENDM

silo_code0:     SILO_CODE 0
silo_code1:     SILO_CODE 1
silo_code2:     SILO_CODE 2
silo_code3:     SILO_CODE 3
silo_code4:     SILO_CODE 4
silo_code5:     SILO_CODE 5
silo_code6:     SILO_CODE 6
silo_code7:     SILO_CODE 7
silo_code_tab:  dw silo_code0, silo_code1, silo_code2, silo_code3
                dw silo_code4, silo_code5, silo_code6, silo_code7
