;==============================================================================
; preshift.asm - the sprites' shifted copies, made at start-up
;
; The draw wants 8 copies of every picture, each shifted one more pixel
; to the right, with a mask, as gfx2asm.py makes them. That is 8 times
; the art. For four sprites the tape carries only the art, each row once
; (tools/gfx2raw.py), and preshift makes the copies when the game starts:
;
;   the diver        6 pictures (3 frames, 2 facings)   540 -> 5,760 bytes
;   the fish         4 pictures (2 frames, 2 facings)   144 -> 1,728 bytes
;   the pulsar       2 pictures                          96 ->   912 bytes
;   the spinning     4 pictures                         192 -> 1,824 bytes
;   wheel
;
; The copies are byte for byte what gfx2asm.py writes, in its order, and
; PRESHIFT_TABLES (below) builds its pointer tables, so the draws are
; unchanged. The art is in the cold block (main.asm): nothing reads it
; after this.
;
; WHERE. The diver, the fish and the pulsar are drawn every frame, so
; their copies are in uncontended RAM, just below the scroll buffers at
; $F000, and the data block (main.asm) stops below them. The spinning
; wheel's are at $71C0-$7FFF, in contended RAM: there, while the beam
; draws the picture, the ULA delays each read by up to 6 T-states. The
; draw reads 48 to 72 bytes, so that is at most a couple of hundred
; T-states, and it was measured to cost nothing at 50 (see
; docs/WHEEL-BOMB.md). The code that reads them stays above $8000.
;==============================================================================

; One picture, all 8 shifts: each row is 2 bytes (mask and ink) for each
; byte of width. A row is NAME_RAW bytes wide below the shift NAME_WIDE,
; and one more from it on (gfx2asm.py's stored_bytes).
        MACRO PRESHIFT_SIZE result?, pics?, rows?, wide?, raw?
result? equ (pics?) * (rows?) * 2 * ((raw?) * 8 + 8 - (wide?))
        ENDM

        PRESHIFT_SIZE DIVER_SHIFTED, DIVER_PICS, DIVER_HEIGHT, DIVER_WIDE, DIVER_RAW
        PRESHIFT_SIZE FISH_SHIFTED, FISH_PICS, FISH_HEIGHT, FISH_WIDE, FISH_RAW
        PRESHIFT_SIZE WHEEL_SHIFTED, WHEEL_PICS, WHEEL_HEIGHT, WHEEL_WIDE, WHEEL_RAW
        PRESHIFT_SIZE WSPIN_SHIFTED, WSPIN_PICS, WSPIN_HEIGHT, WSPIN_WIDE, WSPIN_RAW

; The pulsar ends at the scroll buffers, the fish below it, the diver
; below that. main.asm checks that the data (data_end) stops short of
; PRESHIFT_START.
WHEEL_BUF       equ SCROLL_BASE - WHEEL_SHIFTED
FISH_BUF        equ WHEEL_BUF - FISH_SHIFTED
DIVER_BUF       equ FISH_BUF - DIVER_SHIFTED
PRESHIFT_START  equ DIVER_BUF

; The spinning wheel is packed against $8000, so the cold block below it
; (main.asm) has all the room there is.
WSPIN_BUF_END   equ CODE_START
WSPIN_BUF       equ WSPIN_BUF_END - WSPIN_SHIFTED

; The diver's still pose with the jet's other phase (diver_jet_build):
; two more pictures, one per facing, at the top of the free room after
; the code, just below the data block. Drawn every frame, so above $8000.
; The soak has no room for them (its code is there), so it keeps the
; still pose without them.
DIVER_RAW_PIC   equ DIVER_HEIGHT * DIVER_RAW * 2       ; one picture of art
    IFDEF DIVER_JET
        PRESHIFT_SIZE JET_SHIFTED, 2, DIVER_HEIGHT, DIVER_WIDE, DIVER_RAW
JET_BUF         equ DATA_START - JET_SHIFTED
    ENDIF

; The round fish (TWO_FISH, boom.asm): its 4 pictures just below the
; jet's. Drawn every frame, so above $8000.
    IFDEF TWO_FISH
        PRESHIFT_SIZE RFISH_SHIFTED, RFISH_PICS, RFISH_HEIGHT, RFISH_WIDE, RFISH_RAW
; In two halves, each its two pictures facing one way: the pointer
; tables let them be anywhere. The left-facing pair just below the
; jet's (RFISH_BUF); the right-facing pair at the top of the room above
; the run-time buffers, up to BSS_LIMIT (RFISH_HI), which is uncontended
; too and free in the tape build. That gives the code 864 bytes.
RFISH_HALF      equ RFISH_SHIFTED / 2
RFISH_RAW_PIC   equ RFISH_HEIGHT * RFISH_RAW * 2       ; one picture of art
RFISH_BUF       equ JET_BUF - RFISH_HALF
RFISH_HI        equ BSS_LIMIT - RFISH_HALF
        ASSERT RFISH_PICS == 4 && RFISH_FRAMES == 2, "the round fish's halves are 2 pictures each
    ENDIF

; One job per sprite, for preshift_all.
        MACRO PRESHIFT_JOB src?, buf?, pics?, rows?, wide?, raw?
        dw src?, buf?
        db pics?, rows?, wide?, raw?
        ENDM

preshift_jobs:
    IFDEF DIVER_JET
        ; First: its art is a copy in DIVER_BUF, which the next job fills.
        PRESHIFT_JOB DIVER_BUF, JET_BUF, 2, DIVER_HEIGHT, DIVER_WIDE, DIVER_RAW
    ENDIF
    IFDEF TWO_FISH
        PRESHIFT_JOB rfish_src, RFISH_HI, 2, RFISH_HEIGHT, RFISH_WIDE, RFISH_RAW
        PRESHIFT_JOB rfish_src + 2 * RFISH_RAW_PIC, RFISH_BUF, 2, RFISH_HEIGHT, RFISH_WIDE, RFISH_RAW
    ENDIF
        PRESHIFT_JOB diver_src, DIVER_BUF, DIVER_PICS, DIVER_HEIGHT, DIVER_WIDE, DIVER_RAW
        PRESHIFT_JOB fish_src, FISH_BUF, FISH_PICS, FISH_HEIGHT, FISH_WIDE, FISH_RAW
        PRESHIFT_JOB wheel_src, WHEEL_BUF, WHEEL_PICS, WHEEL_HEIGHT, WHEEL_WIDE, WHEEL_RAW
        PRESHIFT_JOB wspin_src, WSPIN_BUF, WSPIN_PICS, WSPIN_HEIGHT, WSPIN_WIDE, WSPIN_RAW
        dw 0

;------------------------------------------------------------------------------
; preshift_all - every shifted copy. Called once, by boot, with the
; interrupts off. 22 frames (0.44 s), all four: see docs/MEMORY.md.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
preshift_all:
        call diver_jet_build
        ld hl,preshift_jobs
.job:   ld e,(hl)
        inc hl
        ld d,(hl)               ; the art
        inc hl
        ld a,d
        or e
        ret z
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; where the copies go
        inc hl
        ld b,(hl)               ; pictures
        inc hl
        ld c,(hl)               ; rows
        inc hl
        ld a,(hl)
        ld (preshift.wide+1),a
        inc hl
        ld a,(hl)
        ld (preshift.raw+1),a
        inc hl
        ex (sp),hl              ; HL = the art; the job list is kept
        call preshift
        pop hl
        jr .job

;------------------------------------------------------------------------------
; preshift - the 8 shifted copies of some pictures
; In:  HL = the art, gfx2raw.py's rows (NAME_RAW mask bytes, then as many
;           ink bytes)
;      DE = where the copies go
;      B  = pictures, C = rows in each
;      .wide = the first shift whose rows are one byte wider (0: all),
;      .raw = NAME_RAW (2 or 3): both patched by preshift_all
; Writes them in gfx2asm.py's order: picture by picture, shift 0 to 7,
; row by row. Each row of art is read once: it is widened to 32 bits
; (the mask filled with 1s, the ink with 0s), written to shift 0's copy,
; moved one pixel right, written to shift 1's, and so on. preshift_ptr
; holds where each shift's copy has got to.
; Out: DE = one past the last byte written.
; Corrupts: AF, BC, HL, IX
;------------------------------------------------------------------------------
preshift:
        ld a,c
        ld (.rows1+1),a
        ld (.rows2+1),a
        ld (.art+1),hl
.pic:   push bc                 ; B = pictures left
        ; Where each shift's copy of this picture starts: shift 0 here,
        ; each one after the last one's rows.
        ld ix,preshift_ptr
        ld c,0
.base:  ld (ix+0),e
        ld (ix+1),d
        inc ix
        inc ix
        call .size
        ld h,0
        ld l,a
        ex de,hl
.rows1: ld b,0                  ; patched: rows
.mul:   add hl,de
        djnz .mul
        ex de,hl
        inc c
        ld a,c
        cp 8
        jr c,.base
        push de                 ; the next picture starts here
.rows2: ld b,0                  ; patched: rows
.row:   push bc
        ; The work row is mask,ink pairs, left byte first: background
        ; past the art, then the art's bytes on the left.
        ld hl,preshift_blank
        ld de,preshift_row
        ld bc,8
        ldir
.art:   ld hl,0                 ; patched: this row of art
        ld de,preshift_row
        call .bytes             ; the mask bytes
        ld de,preshift_row + 1
        call .bytes             ; the ink bytes
        ld (.art+1),hl
        ld ix,preshift_ptr
        ld c,0                  ; the shift
.shift: ld e,(ix+0)
        ld d,(ix+1)
        call .size
        ld hl,preshift_row
        push bc
        ld c,a
        ld b,0
        ldir                    ; this shift's row of pairs
        pop bc
        ld (ix+0),e
        ld (ix+1),d
        inc ix
        inc ix
        ld hl,preshift_row      ; one pixel more to the right
        scf                     ; a 1 comes into the mask
        rr (hl)
        inc hl
        inc hl
        rr (hl)
        inc hl
        inc hl
        rr (hl)
        inc hl
        inc hl
        rr (hl)
        ld hl,preshift_row + 1
        or a                    ; a 0 into the ink
        rr (hl)
        inc hl
        inc hl
        rr (hl)
        inc hl
        inc hl
        rr (hl)
        inc hl
        inc hl
        rr (hl)
        inc c
        ld a,c
        cp 8
        jr c,.shift
        pop bc
        djnz .row
        pop de
        pop bc
        dec b
        jp nz,.pic
        ret

; A = the bytes in one row of pairs at shift C: 2 * NAME_RAW, or one pair
; more from the shift .wide on.
.size:  ld a,c
.wide:  cp 0                    ; patched: the first wider shift
.raw:   ld a,0                  ; patched: NAME_RAW. LD keeps the carry.
        ccf
        adc a,0
        add a,a
        ret

; Copy NAME_RAW bytes from HL to every other byte from DE.
.bytes: ld a,(.raw+1)
        ld b,a
.copy:  ld a,(hl)
        ld (de),a
        inc hl
        inc de
        inc de
        djnz .copy
        ret

preshift_blank:
        db $FF, 0, $FF, 0, $FF, 0, $FF, 0

;------------------------------------------------------------------------------
; diver_jet_build - the jet's two phases, put into the diver's art
; The jet he holds has a propeller at its back end. It turns, and throws
; bubbles back, in two phases a few 1/50 seconds each:
;   A  the blade face on, 3 pixels tall, at the end of a 2-pixel shaft
;      behind the 3 by 3 housing; two bubbles behind it
;   B  the blade edge on (one pixel), the housing down to its 2-wide
;      hub; three bubbles thrown back
; The housing is a row shorter than the art's (rows 11-13, not 11-14),
; and the shaft and blade reach back into the room under him that the
; legs (gfx/diver-atlantis.txt) leave free.
; His kick runs 0 1 2 1: frames 0 and 2 get A and frame 1 gets B, so
; while he swims the jet goes A B A B. The
; still pose is frame 2 (A). Its B is a copy of frame 2 with B, built in
; DIVER_BUF (the diver's own job overwrites it after) and shifted into
; JET_BUF by the first job; diver_image_index shows it every other 4
; 1/50 seconds while he is still. The legs do not move.
; Each bubble is a pixel with no ink beside it in any of the three
; frames (the shortened tail frees the row under it), so a bubble
; never joins a leg. Called by preshift_all,
; before the jobs. Patching twice gives the same art.
; The art (gfx/diver-atlantis.txt) keeps the old jet: the still pose
; needs both phases from one frame of art, so they are added here.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
diver_jet_build:
    IFDEF DIVER_JET
        ld hl,diver_src + DIVER_GLIDE * DIVER_RAW_PIC
        ld de,DIVER_BUF
        ld bc,DIVER_RAW_PIC
        ldir
        ld hl,diver_src + (DIVER_FRAMES + DIVER_GLIDE) * DIVER_RAW_PIC
        ld bc,DIVER_RAW_PIC
        ldir                    ; the left-facing one straight after
        ld hl,jet_b
        ld bc,DIVER_BUF
        ld de,DIVER_BUF + DIVER_RAW_PIC
        call jet_patch
    ENDIF
        ld hl,jet_a
        ld bc,diver_src
        ld de,diver_src + DIVER_FRAMES * DIVER_RAW_PIC
        call jet_patch
        ld hl,jet_a
        ld bc,diver_src + 2 * DIVER_RAW_PIC
        ld de,diver_src + (DIVER_FRAMES + 2) * DIVER_RAW_PIC
        call jet_patch
        ld hl,jet_b
        ld bc,diver_src + DIVER_RAW_PIC
        ld de,diver_src + (DIVER_FRAMES + 1) * DIVER_RAW_PIC
        ; fall through

; jet_patch - HL = a list of JET_PX pixels (ends with $FF), BC = a
; right-facing picture of art, DE = the same frame facing left.
; Corrupts: AF, HL
jet_patch:
        ld a,(hl)
        inc a
        ret z
        push de
        call .pix               ; facing right
        pop de
        push bc
        push de
        ld b,d
        ld c,e
        call .pix               ; facing left: the pixel mirrored
        pop de
        pop bc
        jr jet_patch
; HL -> the byte to clear the bit in, the byte to set it in, the bit,
; as offsets from BC. Out: HL past them. Corrupts: AF, DE
.pix:   ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,0
        add hl,bc
        ex de,hl                ; DE = the byte to clear it in
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,0
        add hl,bc               ; HL = the byte to set it in
        ex (sp),hl
        ld a,(hl)               ; the bit
        inc hl
        ex (sp),hl
        push af
        or (hl)
        ld (hl),a
        pop af
        cpl
        ex de,hl
        and (hl)
        ld (hl),a
        pop hl
        ret

; One pixel of art: ink (mask bit 0, ink bit 1) or gone (mask 1, ink 0),
; at row, column facing right, and its mirror facing left. A row of art
; is 3 mask bytes, then 3 ink bytes (DIVER_RAW; the diver is 24 wide,
; asserted below: the numbers are written out because the art's sizes
; come later in the build).
JET_INK         equ 0
JET_GONE        equ 1
        MACRO JET_PX op?, row?, col?
jpx_r = (row?) * 6 + ((col?) >> 3)
jpx_l = (row?) * 6 + ((23 - (col?)) >> 3)
        IF op? == JET_INK
        db jpx_r, jpx_r + 3, $80 >> ((col?) & 7)
        db jpx_l, jpx_l + 3, $80 >> ((23 - (col?)) & 7)
        ELSE
        db jpx_r + 3, jpx_r, $80 >> ((col?) & 7)
        db jpx_l + 3, jpx_l, $80 >> ((23 - (col?)) & 7)
        ENDIF
        ENDM

jet_a:  JET_PX JET_GONE, 14, 14 ; the housing one row shorter: rows 11-13
        JET_PX JET_GONE, 14, 15
        JET_PX JET_GONE, 14, 16
        JET_PX JET_INK, 12, 13  ; the shaft, two pixels back from it
        JET_PX JET_INK, 12, 12
        JET_PX JET_INK, 11, 14  ; the housing a solid 3 by 3
        JET_PX JET_INK, 13, 14
        JET_PX JET_INK, 11, 11  ; the blade face on, 3 tall, on the shaft's end
        JET_PX JET_INK, 12, 11
        JET_PX JET_INK, 13, 11
        JET_PX JET_INK, 12, 9   ; two bubbles behind it
        JET_PX JET_INK, 14, 8
        db $FF
jet_b:  JET_PX JET_GONE, 14, 14 ; the housing one row shorter, as A
        JET_PX JET_GONE, 14, 15
        JET_PX JET_GONE, 14, 16
        JET_PX JET_INK, 12, 13  ; the shaft
        JET_PX JET_INK, 12, 12
        JET_PX JET_GONE, 11, 14 ; the housing down to its 2-wide hub
        JET_PX JET_GONE, 13, 14
        JET_PX JET_INK, 12, 11  ; the blade edge on: one pixel
        JET_PX JET_INK, 11, 9   ; three bubbles thrown back
        JET_PX JET_INK, 13, 8
        JET_PX JET_INK, 14, 11
        db $FF
        ASSERT DIVER_WIDTH == 24 && DIVER_HEIGHT == 15 && DIVER_RAW == 3, "jet_a and jet_b are drawn for the 24 by 15 diver"
        ASSERT DIVER_GLIDE == 2, "the still pose is frame 2"

;------------------------------------------------------------------------------
; PRESHIFT_TABLES images, buffer, pictures, rows, wide, raw
; gfx2asm.py's tables for copies made by preshift: images is one word per
; picture, pointing at that picture's 8 words, one per shift, which point
; into the buffer. In the data block; the copies themselves are not.
;------------------------------------------------------------------------------
        MACRO PRESHIFT_TABLES images?, buf?, pics?, rows?, wide?, raw?
images?:
        PRESHIFT_INDEX images? + 2 * (pics?), pics?
        PRESHIFT_SHIFTS buf?, pics?, rows?, wide?, raw?
        ENDM

; The two halves: one word per picture, pointing at its 8 shift words;
; and those words, into the buffer.
        MACRO PRESHIFT_INDEX shifts?, pics?
pst_i = 0
        DUP pics?
        dw shifts? + 16 * pst_i
pst_i = pst_i + 1
        EDUP
        ENDM

        MACRO PRESHIFT_SHIFTS buf?, pics?, rows?, wide?, raw?
pst_a = buf?
        DUP pics?
pst_s = 0
        DUP 8
        dw pst_a
pst_a = pst_a + (rows?) * 2 * ((raw?) + ((pst_s >= (wide?)) & 1))
pst_s = pst_s + 1
        EDUP
        EDUP
        ENDM

; All four, and the spinning wheel's animation: every picture in turn,
; the cross turning. (The pulsar's, wheel_seq, is in gfx/wheel_raw.asm.)
        MACRO PRESHIFT_DATA
        ; The diver's: his 6 pictures, then the jet's 2 (picture 6 faces
        ; right, 7 left), which diver_image_index picks while he is still.
diver_images:
        PRESHIFT_INDEX diver_shifts, DIVER_PICS
    IFDEF DIVER_JET
        PRESHIFT_INDEX jet_shifts, 2
    ENDIF
diver_shifts:
        PRESHIFT_SHIFTS DIVER_BUF, DIVER_PICS, DIVER_HEIGHT, DIVER_WIDE, DIVER_RAW
        ASSERT pst_a == DIVER_BUF + DIVER_SHIFTED, "the diver's tables and preshift disagree"
    IFDEF DIVER_JET
jet_shifts:
        PRESHIFT_SHIFTS JET_BUF, 2, DIVER_HEIGHT, DIVER_WIDE, DIVER_RAW
        ASSERT pst_a == DATA_START, "the jet's tables and preshift disagree"
    ENDIF
        PRESHIFT_TABLES fish_images, FISH_BUF, FISH_PICS, FISH_HEIGHT, FISH_WIDE, FISH_RAW
        ASSERT pst_a == FISH_BUF + FISH_SHIFTED, "the fish's tables and preshift disagree"
        PRESHIFT_TABLES wheel_images, WHEEL_BUF, WHEEL_PICS, WHEEL_HEIGHT, WHEEL_WIDE, WHEEL_RAW
        ASSERT pst_a == WHEEL_BUF + WHEEL_SHIFTED, "the pulsar's tables and preshift disagree"
        PRESHIFT_TABLES wspin_images, WSPIN_BUF, WSPIN_PICS, WSPIN_HEIGHT, WSPIN_WIDE, WSPIN_RAW
        ASSERT pst_a == WSPIN_BUF_END, "the spinning wheel's tables and preshift disagree"
wspin_seq:                      ; the 4 quarter turns, twice: WHEEL_FRAMES steps
        db 0, 1, 2, 3, 0, 1, 2, 3
        ENDM

        ASSERT WSPIN_FRAMES == 4 && WSPIN_PICS == 4, "wspin_seq lists 4 pictures"
        ASSERT FISH_PICS == 2 * FISH_FRAMES, "the fish has two facings"
        ASSERT DIVER_PICS == 2 * DIVER_FRAMES, "the diver has two facings"
        ASSERT WSPIN_WIDTH == WHEEL_WIDTH && WSPIN_HEIGHT == WHEEL_HEIGHT, "both bombs share the draw, so they are one size"
        ASSERT WSPIN_WIDE == WHEEL_WIDE, "both bombs share wheel_shift_bytes"
        ASSERT WHEEL_FRAMES == 8, "wspin_seq is WHEEL_FRAMES (8) steps, as the pulsar's"

; The round fish's tables, in the code block (main.asm, before code_end).
        MACRO RFISH_TABLES
rfish_images:
        PRESHIFT_INDEX rfish_shifts, RFISH_PICS
rfish_shifts:
        PRESHIFT_SHIFTS RFISH_HI, 2, RFISH_HEIGHT, RFISH_WIDE, RFISH_RAW
        ASSERT pst_a == BSS_LIMIT, "the round fish's right-facing tables and preshift disagree"
        PRESHIFT_SHIFTS RFISH_BUF, 2, RFISH_HEIGHT, RFISH_WIDE, RFISH_RAW
        ASSERT pst_a == JET_BUF, "the round fish's left-facing tables and preshift disagree"
        ENDM
