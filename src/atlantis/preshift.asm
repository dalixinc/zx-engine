;==============================================================================
; preshift.asm - the sprites' shifted copies, made at start-up
;
; The draw wants 8 copies of every picture, each shifted one more pixel
; to the right, with a mask, as gfx2asm.py makes them. That is 8 times
; the art. For three sprites the tape carries only the art, each row once
; (tools/gfx2raw.py), and preshift makes the copies when the game starts:
;
;   the fish         4 pictures (2 frames, 2 facings)   144 -> 1,728 bytes
;   the pulsar       2 pictures                          96 ->   912 bytes
;   the spinning     8 pictures                         384 -> 3,648 bytes
;   wheel
;
; The copies are byte for byte what gfx2asm.py writes, in its order, and
; PRESHIFT_TABLES (below) builds its pointer tables, so the draws are
; unchanged. The diver (5,760 bytes) is still gfx2asm.py's.
;
; WHERE. The fish and the pulsar are drawn every frame, so their copies
; are in uncontended RAM, just below the scroll buffers at $F000. The
; spinning wheel's are at $71C0-$7FFF, in contended RAM: there, while
; the beam draws the picture, the ULA delays each read by up to 6
; T-states. The draw reads 48 to 72 bytes, so that is at most a couple
; of hundred T-states, and it was measured to cost nothing at 50 (see
; docs/WHEEL-BOMB.md). The code that reads them stays above $8000.
;==============================================================================

; One picture, all 8 shifts: each row is 2 bytes (mask and ink) for each
; byte of width. A row is 2 bytes wide below the shift NAME_WIDE, and 3
; from it on (gfx2asm.py's stored_bytes).
        MACRO PRESHIFT_SIZE result?, pics?, rows?, wide?
result? equ (pics?) * (rows?) * 2 * (2 * 8 + 8 - (wide?))
        ENDM

        PRESHIFT_SIZE FISH_SHIFTED, FISH_PICS, FISH_HEIGHT, FISH_WIDE
        PRESHIFT_SIZE WHEEL_SHIFTED, WHEEL_PICS, WHEEL_HEIGHT, WHEEL_WIDE
        PRESHIFT_SIZE WSPIN_SHIFTED, WSPIN_PICS, WSPIN_HEIGHT, WSPIN_WIDE

; The fish and the pulsar end at the scroll buffers. main.asm checks that
; the pictures and tables (data_end) stop short of FISH_BUF.
WHEEL_BUF       equ SCROLL_BASE - WHEEL_SHIFTED
FISH_BUF        equ WHEEL_BUF - FISH_SHIFTED
PRESHIFT_START  equ FISH_BUF

; The spinning wheel is packed against $8000, so the cold block below it
; (main.asm) has all the room there is.
WSPIN_BUF_END   equ CODE_START
WSPIN_BUF       equ WSPIN_BUF_END - WSPIN_SHIFTED

;------------------------------------------------------------------------------
; preshift_all - every shifted copy. Called once, by boot.
; About a quarter of a second (1,104 rows), before the menu.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
preshift_all:
        ld hl,fish_src
        ld de,FISH_BUF
        ld bc,(FISH_PICS << 8) | FISH_HEIGHT
        ld a,FISH_WIDE
        call preshift
        ld hl,wheel_src
        ld de,WHEEL_BUF
        ld bc,(WHEEL_PICS << 8) | WHEEL_HEIGHT
        ld a,WHEEL_WIDE
        call preshift
        ld hl,wspin_src
        ld de,WSPIN_BUF
        ld bc,(WSPIN_PICS << 8) | WSPIN_HEIGHT
        ld a,WSPIN_WIDE
        ; fall through

;------------------------------------------------------------------------------
; preshift - the 8 shifted copies of some pictures
; In:  HL = the art, gfx2raw.py's rows (mask0, mask1, ink0, ink1)
;      DE = where the copies go
;      B  = pictures, C = rows in each
;      A  = the first shift whose rows are 3 bytes (0: all of them)
; Writes them in gfx2asm.py's order: picture by picture, shift 0 to 7,
; row by row. Each row is widened to 24 bits (the mask filled with 1s,
; the ink with 0s), shifted right, and written as mask,ink pairs for as
; many bytes as that shift needs.
; Out: DE = one past the last byte written.
; Corrupts: AF, BC, HL, IX
;------------------------------------------------------------------------------
preshift:
        ld (.wide+1),a
        ld a,c
        ld (.rows+1),a
.pic:   push bc
        ld c,0                  ; the shift
.shift: push hl                 ; this picture's first row
.rows:  ld b,0                  ; patched: rows in a picture
.row:   push bc
        ld ix,preshift_row
        ld a,(hl)
        ld (ix+0),a             ; mask, left byte
        inc hl
        ld a,(hl)
        ld (ix+1),a
        inc hl
        ld a,(hl)
        ld (ix+3),a             ; ink, left byte
        inc hl
        ld a,(hl)
        ld (ix+4),a
        inc hl
        ld (ix+2),$FF           ; past the right: background
        ld (ix+5),0
        ld a,c
        or a
        jr z,.put
        ld b,a
.sr:    scf                     ; a 1 comes into the mask
        rr (ix+0)
        rr (ix+1)
        rr (ix+2)
        or a                    ; a 0 into the ink
        rr (ix+3)
        rr (ix+4)
        rr (ix+5)
        djnz .sr
.put:   ld a,c
.wide:  cp 0                    ; patched: the first 3-byte shift
        ld b,2
        jr c,.pair
        inc b
.pair:  ld a,(ix+0)
        ld (de),a
        inc de
        ld a,(ix+3)
        ld (de),a
        inc de
        inc ix
        djnz .pair
        pop bc
        djnz .row
        inc c
        ld a,c
        cp 8
        jr nc,.next
        pop hl                  ; the same picture again, one shift more
        jr .shift
.next:  pop af                  ; drop it: HL is already the next picture
        pop bc
        djnz .pic
        ret

;------------------------------------------------------------------------------
; PRESHIFT_TABLES images, buffer, pictures, rows, wide
; gfx2asm.py's tables for copies made by preshift: images is one word per
; picture, pointing at that picture's 8 words, one per shift, which point
; into the buffer. In the data block; the copies themselves are not.
;------------------------------------------------------------------------------
        MACRO PRESHIFT_TABLES images?, buf?, pics?, rows?, wide?
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
pst_a = pst_a + (rows?) * 2 * (2 + ((pst_s >= (wide?)) & 1))
pst_s = pst_s + 1
        EDUP
        EDUP
        ENDM

; All three, and the spinning wheel's animation: every picture in turn,
; the cross turning. (The pulsar's, wheel_seq, is in gfx/wheel_raw.asm.)
        MACRO PRESHIFT_DATA
        PRESHIFT_TABLES fish_images, FISH_BUF, FISH_PICS, FISH_HEIGHT, FISH_WIDE
        ASSERT pst_a == FISH_BUF + FISH_SHIFTED, "the fish's tables and preshift disagree"
        PRESHIFT_TABLES wheel_images, WHEEL_BUF, WHEEL_PICS, WHEEL_HEIGHT, WHEEL_WIDE
        ASSERT pst_a == WHEEL_BUF + WHEEL_SHIFTED, "the pulsar's tables and preshift disagree"
        PRESHIFT_TABLES wspin_images, WSPIN_BUF, WSPIN_PICS, WSPIN_HEIGHT, WSPIN_WIDE
        ASSERT pst_a == WSPIN_BUF_END, "the spinning wheel's tables and preshift disagree"
wspin_seq:
        db 0, 1, 2, 3, 4, 5, 6, 7
        ENDM

        ASSERT WSPIN_FRAMES == 8 && WSPIN_PICS == 8, "wspin_seq lists 8 pictures"
        ASSERT FISH_PICS == 2 * FISH_FRAMES, "the fish has two facings"
        ASSERT WSPIN_WIDTH == WHEEL_WIDTH && WSPIN_HEIGHT == WHEEL_HEIGHT, "both bombs share the draw, so they are one size"
        ASSERT WSPIN_WIDE == WHEEL_WIDE, "both bombs share wheel_shift_bytes"
        ASSERT WSPIN_FRAMES == WHEEL_FRAMES, "both bombs' animations are WHEEL_FRAMES steps"
