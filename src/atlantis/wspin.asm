;==============================================================================
; wspin.asm - the spinning wheel, the second kind of bomb
;
; The art is gfx/wheel-full.txt: a ring with a cross that turns all the
; way round in 16 frames. Every other frame is kept, so 8. It is the
; pulsar's size (12 by 12), it flies the same way, and the same draw,
; restore, colour and hit code serves both. Only the pictures, the
; animation order and the ink differ. update_wheel picks the kind when a
; bomb appears (wheel_type in wheel.asm), from the level's row of
; CFG_LEVELS.
;
; WHY IT IS BUILT AT START-UP. The draw wants 8 pre-shifted copies of
; every picture, as gfx2asm.py makes them. The pulsar has only two
; different pictures (912 bytes), but the wheel has 8: 3,648 bytes, and
; with its tables 3,792. The data block has 1,669 bytes free and the code
; block 553. So the tape carries each row once (gfx/wheel_spin.asm, 384
; bytes, from tools/gfx2raw.py), and wspin_build makes the shifted copies
; when the game starts, at WSPIN_BUF.
;
; WHY $7000. Nothing else uses $6000-$7FFF: the tape's BASIC ends far
; below, and its machine stack is left behind when entry sets SP. The
; soak build keeps its own code at $6000, which ends below $7000. This
; RAM is contended: while the beam draws the picture, the ULA delays
; each read of it by up to 6 T-states. The draw reads 2 or 3 bytes of
; mask and as many of ink for each of 12 rows, 48 to 72 reads, so that
; is at most a couple of hundred T-states, and none while the beam is
; in the border. The code that reads them stays in fast RAM. See
; docs/WHEEL-BOMB.md for the measurements.
;==============================================================================

WSPIN_BUF       equ $7000
; One picture, all 8 shifts: 12 rows of 2 bytes (mask and ink) per byte
; of width, and a 12-pixel row is 2 bytes wide at shifts 0-4, 3 at 5-7.
WSPIN_FRAME_BYTES equ WHEEL_HEIGHT * 2 * (5 * 2 + 3 * 3)
WSPIN_BUF_END   equ WSPIN_BUF + WSPIN_FRAMES * WSPIN_FRAME_BYTES

;------------------------------------------------------------------------------
; wspin_build - the 8 shifted copies of the 8 pictures, into WSPIN_BUF
; Called once, by entry. Writes them in the order wspin_shifts points
; at: picture by picture, shift 0 to 7, row by row. Each row is
; widened to 24 bits (mask filled with 1s, ink with 0s), shifted right,
; and written as mask,ink pairs for as many bytes as that shift needs.
; About a sixth of a second (768 rows), once, before the menu.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
wspin_build:
        ld hl,wspin_src
        ld de,WSPIN_BUF
        ld ix,wspin_row
        ld b,WSPIN_FRAMES
.frame: push bc
        ld c,0                  ; the shift
.shift: push hl                 ; this picture's first row
        ld b,WHEEL_HEIGHT
.row:   push bc
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
        cp 5
        ld b,2
        jr c,.pair
        inc b                   ; shifts 5-7 spill into a third byte
.pair:  ld a,(ix+0)
        ld (de),a
        inc de
        ld a,(ix+3)
        ld (de),a
        inc de
        inc ix
        djnz .pair
        ld ix,wspin_row
        pop bc
        djnz .row
        pop hl                  ; the same picture again, one shift more
        inc c
        ld a,c
        cp 8
        jr c,.shift
        ld bc,WHEEL_HEIGHT * 4  ; the next picture
        add hl,bc
        pop bc
        djnz .frame
        ret

wspin_row:      ds 6            ; mask 24 bits, then ink 24 bits

;------------------------------------------------------------------------------
; The tables, in the data block. They are the same shape as gfx2asm.py's
; (wheel_images in gfx/wheel.asm), so wheel_draw reads either kind.
;------------------------------------------------------------------------------
        MACRO WSPIN_DATA
wspin_images:
wsp_f = 0
        DUP WSPIN_FRAMES
        dw wspin_shifts + wsp_f * 16
wsp_f = wsp_f + 1
        EDUP
wspin_shifts:
wsp_a = WSPIN_BUF
        DUP WSPIN_FRAMES
wsp_s = 0
        DUP 8
        dw wsp_a
wsp_a = wsp_a + WHEEL_HEIGHT * 2 * ((WHEEL_WIDTH + wsp_s + 7) / 8)
wsp_s = wsp_s + 1
        EDUP
        EDUP
        ASSERT wsp_a == WSPIN_BUF_END, "wspin_shifts and wspin_build disagree"
; Its animation: every picture in turn, the cross turning.
wspin_seq:
        db 0, 1, 2, 3, 4, 5, 6, 7
        ENDM

        ASSERT WSPIN_WIDTH == WHEEL_WIDTH && WSPIN_HEIGHT == WHEEL_HEIGHT, "both bombs share the draw, so they are one size"
        ASSERT WSPIN_FRAMES == WHEEL_FRAMES, "both bombs' animations are WHEEL_FRAMES steps"
