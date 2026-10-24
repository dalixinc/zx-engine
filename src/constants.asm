;==============================================================================
; constants.asm - hardware addresses and engine-wide constants
;==============================================================================

; --- Memory map (see the plan Page) -----------------------------------------
SCREEN          equ $4000       ; bitmap, 6144 bytes, interleaved rows
SCREEN_SIZE     equ 6144
ATTRS           equ $5800       ; attributes, 32x24 = 768 bytes
ATTRS_SIZE      equ 768
CODE_START      equ $8000       ; engine code lives in uncontended RAM
STACK_TOP       equ $FDFD       ; first PUSH writes $FDFC/$FDFB, grows down
IM2_JP          equ $FDFD       ; JP <isr> lives here (3 bytes)
IM2_TABLE       equ $FE00       ; 257-byte vector table, all $FD
IM2_VECTOR_BYTE equ $FD         ; -> every vector reads as $FDFD

; --- Font --------------------------------------------------------------------
; The 48K ROM font lives at $3D00 (char 32 = space). We only READ the glyph
; bytes; no ROM routines are called. Point FONT_BASE at your own 96-char,
; 8-bytes-per-glyph font later and nothing else needs to change.
FONT_BASE       equ $3D00 - 32*8

; --- I/O ---------------------------------------------------------------------
ULA_PORT        equ $FE         ; border colour (bits 0-2), beeper, keyboard

; --- Colours / attributes ----------------------------------------------------
BLACK   equ 0
BLUE    equ 1
RED     equ 2
MAGENTA equ 3
GREEN   equ 4
CYAN    equ 5
YELLOW  equ 6
WHITE   equ 7
BRIGHT  equ %01000000
FLASH   equ %10000000

; attribute byte = FLASH | BRIGHT | PAPER<<3 | INK
        MACRO ATTR ink, paper
        db (paper << 3) | ink
        ENDM

; --- Engine tuning -----------------------------------------------------------
BORDER_FRAMES   equ 8           ; change border colour every N frames (power of 2)

; --- Input -------------------------------------------------------------------
; One byte of flags, laid out like the Kempston joystick so a joystick read
; can be OR-ed straight in. A set bit means "pressed".
IN_RIGHT_BIT    equ 0
IN_LEFT_BIT     equ 1
IN_DOWN_BIT     equ 2
IN_UP_BIT       equ 3
IN_FIRE_BIT     equ 4
IN_RIGHT        equ 1 << IN_RIGHT_BIT
IN_LEFT         equ 1 << IN_LEFT_BIT
IN_DOWN         equ 1 << IN_DOWN_BIT
IN_UP           equ 1 << IN_UP_BIT
IN_FIRE         equ 1 << IN_FIRE_BIT
IN_MASK         equ %00011111

KEMPSTON_PORT   equ $1F         ; 000FUDLR, active high
KEMPSTON_FLOAT  equ %11100000   ; any of these set -> no interface fitted

; Keyboard half-rows: the high byte put on the address bus when reading $FE.
; A key reads as 0 in bits 0-4 (bit 0 = key nearest the outside edge).
ROW_CAPS_V      equ $FE         ; CAPS Z X C V
ROW_A_G         equ $FD         ; A S D F G
ROW_Q_T         equ $FB         ; Q W E R T
ROW_1_5         equ $F7         ; 1 2 3 4 5
ROW_0_6         equ $EF         ; 0 9 8 7 6
ROW_P_Y         equ $DF         ; P O I U Y
ROW_ENT_H       equ $BF         ; ENTER L K J H
ROW_SPC_B       equ $7F         ; SPACE SYM M N B

; --- Play area and scenery -------------------------------------------------
; Rows are character rows (0-23). Sprites work in pixels (y = row * 8).
; The ground is two scrolling silhouettes. Each is two character rows, so
; the profile can rise and fall. The near one sits directly under the far
; one and stops at the debug text (row 22). See scroll.asm and SCROLLING.md
; for which ink/paper pair each row uses, and why the far strip is copied
; and shifted on alternate frames.
WATER_TOP_ROW   equ 7           ; first row of open water
BACK_ROW        equ 18          ; far strip: yellow hills, slow, seaweed
BACK_PX         equ 16          ; two character rows (pixel lines 144-159)
FRONT_ROW       equ 20          ; near strip: black hills, fast, rocks, silos
FRONT_PX        equ 16          ; two character rows (pixel lines 160-175)

; Bottom of the near silhouette, one past the last pixel it owns. The
; diver's feet stop one pixel above whatever column is under him.
NEAR_BOTTOM     equ FRONT_ROW * 8 + FRONT_PX

WATER_ATTR      equ BRIGHT | WHITE | (BLUE << 3)
; Far hills: yellow ink, blue paper. A set pixel is sand, a clear pixel is
; the water showing through. The top far row is this pair for every column.
BACK_HILL_ATTR  equ BRIGHT | YELLOW | (BLUE << 3)
; A seaweed column's bottom cell only. Green ink, yellow paper: the plant
; is green and the cell behind it is sand. Blue water cannot also be in
; that cell. See SCROLLING.md.
BACK_WEED_ATTR  equ BRIGHT | GREEN | (YELLOW << 3)
; Near hills: black ink, yellow paper. Everything in the strip (ground,
; rocks, silos) is black; the clear pixels are the yellow background.
FRONT_ATTR      equ BRIGHT | BLACK | (YELLOW << 3)

; Pixel buffers for the strips. Ordinary RAM, not screen RAM, so rotating
; them is not slowed by the ULA. Filled by scroll_init, not stored on tape.
;   BACK_BUF  16*32 = 512 bytes, FRONT_BUF 16*32 = 512, together 1024.
;   $F000-$F3FF. The row table at $FA00 is well clear of this.
SCROLL_BASE     equ $F000
BACK_BUF        equ SCROLL_BASE
FRONT_BUF       equ BACK_BUF + BACK_PX * 32
SCROLL_BUF_END  equ FRONT_BUF + FRONT_PX * 32

; --- Sprites -----------------------------------------------------------------
; Sizes (width, bytes per shifted row, height) come from the generated
; gfx/*.asm files, e.g. DIVER_BYTES, DIVER_HEIGHT.
ANIM_FRAMES     equ 8           ; fish: swap animation frame every N frames (power of 2)
DIVER_ANIM_STEP equ 4           ; diver: frames per step of the kick while moving

FACE_RIGHT      equ 0           ; facing values; gfx2asm.py puts the right-facing
FACE_LEFT       equ 1           ; images first, then the mirrored left-facing ones

; Lookup table of the screen address of each of the 192 pixel rows, built at
; start-up by build_row_table (screen.asm). 192 x 2 bytes = 384 bytes. It is
; filled in at run time, so it costs nothing on tape.
ROW_TABLE       equ $FA00       ; $FA00-$FB7F, in the "buffers" part of the map
