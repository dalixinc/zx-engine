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
;   the spinning     8 pictures                         384 -> 3,648 bytes
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

; One job per sprite, for preshift_all.
        MACRO PRESHIFT_JOB src?, buf?, pics?, rows?, wide?, raw?
        dw src?, buf?
        db pics?, rows?, wide?, raw?
        ENDM

preshift_jobs:
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
; PRESHIFT_TABLES images, buffer, pictures, rows, wide, raw
; gfx2asm.py's tables for copies made by preshift: images is one word per
; picture, pointing at that picture's 8 words, one per shift, which point
; into the buffer. In the data block; the copies themselves are not.
;------------------------------------------------------------------------------
        MACRO PRESHIFT_TABLES images?, buf?, pics?, rows?, wide?, raw?
images?:
pst_i = 0
        DUP pics?
        dw images? + 2 * (pics?) + 16 * pst_i
pst_i = pst_i + 1
        EDUP
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
        PRESHIFT_TABLES diver_images, DIVER_BUF, DIVER_PICS, DIVER_HEIGHT, DIVER_WIDE, DIVER_RAW
        ASSERT pst_a == DIVER_BUF + DIVER_SHIFTED, "the diver's tables and preshift disagree"
        PRESHIFT_TABLES fish_images, FISH_BUF, FISH_PICS, FISH_HEIGHT, FISH_WIDE, FISH_RAW
        ASSERT pst_a == FISH_BUF + FISH_SHIFTED, "the fish's tables and preshift disagree"
        PRESHIFT_TABLES wheel_images, WHEEL_BUF, WHEEL_PICS, WHEEL_HEIGHT, WHEEL_WIDE, WHEEL_RAW
        ASSERT pst_a == WHEEL_BUF + WHEEL_SHIFTED, "the pulsar's tables and preshift disagree"
        PRESHIFT_TABLES wspin_images, WSPIN_BUF, WSPIN_PICS, WSPIN_HEIGHT, WSPIN_WIDE, WSPIN_RAW
        ASSERT pst_a == WSPIN_BUF_END, "the spinning wheel's tables and preshift disagree"
wspin_seq:
        db 0, 1, 2, 3, 4, 5, 6, 7
        ENDM

        ASSERT WSPIN_FRAMES == 8 && WSPIN_PICS == 8, "wspin_seq lists 8 pictures"
        ASSERT FISH_PICS == 2 * FISH_FRAMES, "the fish has two facings"
        ASSERT DIVER_PICS == 2 * DIVER_FRAMES, "the diver has two facings"
        ASSERT WSPIN_WIDTH == WHEEL_WIDTH && WSPIN_HEIGHT == WHEEL_HEIGHT, "both bombs share the draw, so they are one size"
        ASSERT WSPIN_WIDE == WHEEL_WIDE, "both bombs share wheel_shift_bytes"
        ASSERT WSPIN_FRAMES == WHEEL_FRAMES, "both bombs' animations are WHEEL_FRAMES steps"
