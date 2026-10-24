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

; The seabed layout (which rows scroll, the ink/paper pairs, the pixel
; buffers) is not in this file. Both programs include their own layout
; before any code that uses it:
;   src/layout.asm            Engine Demo 1
;   src/atlantis/layout.asm   Atlantis
; Sharing the numbers here would force both games onto the same seabed.

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

; Atlantis (and only Atlantis) splits the program in two. The instructions
; stay below DATA_START, in the one block the demo also uses. The pictures,
; the menu words and the lookup tables are assembled at DATA_START and
; loaded as a second block, so the instruction area has room to grow.
; The demo does not mention DATA_START: its pictures stay inside the one
; code block, and that tape is unchanged. The scroll buffers at $F000,
; the row table, the stack and the interrupt table stay where they are.
DATA_START      equ $C000
