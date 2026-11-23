;==============================================================================
; cityhi.asm - the busier half of Finale's ending (city.asm): the circle,
; the shields, the bomb's drawing, the words and the waits, and the ZX0
; unpacker for the picture.
;
; It lives above the run-time buffers, from BSS_END to BSS_LIMIT, where
; Atlantis keeps the round fish's pictures: free in Finale, and fast
; memory. main.asm assembles it there, after bss.asm. The tape carries
; it at the end of its second block, before the city, and city_go
; (city.asm) copies it up before start-up begins (tape.asm). After it,
; the circle's table, CT_DX, which is not on the tape.
;==============================================================================

    IFDEF TRIGON_END

ct_high:
; CT_ATTRS all A. Corrupts: BC, DE, HL
ct_fill:
        ld hl,CT_ATTRS
        ld de,CT_ATTRS + 1
        ld bc,ATTRS_SIZE - 1
        ld (hl),a
        ldir
        ret

; Black, the words at HL (ct_lines), until a fresh key. Corrupts: all
ct_page:
        push hl
        xor a
        call ct_border
        xor a
        call cls                ; it corrupts HL
        pop hl
        call ct_lines
        ld hl,str_ct_key
        ld bc,(18 << 8) | 10
        call print_string       ; in the last line's colour
        ld d,0                  ; no time limit
        ; fall through

; A fresh key, or D 1/50 seconds (0: none). A key already down must go
; up first, and the last does not reach what follows. Corrupts: AF, D
ct_key:
        call keys_up
.wait:  call wait_frame
        call any_key
        jp nz,keys_up
        ld a,d
        or a
        jr z,.wait              ; no limit
        dec d
        jr nz,.wait
        ret

; The digit of bombs left, on the BOMBS line. Corrupts: AF, BC, DE, HL
ct_status:
        ld a,(ct_tries)
        add a,'0'
        ld bc,(CT_BOMBS_ROW << 8) | (CT_BOMBS_COL + 6)
        jp print_char

; Lines of words at HL: row, column, colour, the words, 0; a row of 255
; ends them (row 0 is a row). Corrupts: AF, BC, DE, HL
ct_lines:
        ld a,(hl)
        inc a
        ret z
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (text_attr),a
        call print_string
        inc hl                  ; past its 0
        jr ct_lines

; The border A, and the beeper's (it writes the border with each pass, in
; the last level's colour otherwise). Corrupts: F
ct_border:
    IFNDEF NO_SOUND
        ld (snd_border),a
    ENDIF
        jp set_border

; The frame's wait: spare_count, which plays the sound while it waits for
; the interrupt. Corrupts: AF, DE, HL
ct_wait:
        call spare_count
        xor a
        ld (vsync_flag),a
        ret

;------------------------------------------------------------------------------
; ct_bomb_on / ct_bomb_off - the bomb at (ct_by, ct_bcol), and what was
; under it back. Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
ct_bomb_on:
        ld a,(ct_by)
        ld (ct_dy),a
        ld a,(ct_bcol)
        ld (ct_dcol),a
        ld a,1
        jr ct_bomb_io
ct_bomb_off:
        ld a,(ct_drawn)
        or a
        ret z
        xor a
ct_bomb_io:
        ld (ct_drawn),a         ; 1 = drawn: save, then the picture
        ld c,a
        ld a,(ct_dy)
        ld l,a
        ld h,0
        add hl,hl
        ld de,ROW_TABLE
        add hl,de
        ld ix,ct_save
        ld b,8
.row:   ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(ct_dcol)
        add a,e                 ; a row's low byte has its column bits clear
        ld e,a
        ld a,c
        or a
        jr z,.back
        ld a,(de)
        ld (ix + 0),a
        ld a,(ix + 8)
        jr .put
.back:  ld a,(ix + 0)
.put:   ld (de),a
        inc ix
        djnz .row
        ; Its cells (two, unless it is on a cell's top row): white ink
        ; on the picture's paper, so it shows on the dark of the city;
        ; or the picture's colours back.
        ld a,(ct_dy)
        and %11111000
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl               ; its row's first cell, from ATTRS
        ld a,(ct_dcol)
        or l
        ld l,a
        ld de,ATTRS
        add hl,de
        ld b,1
        ld a,(ct_dy)
        and 7
        jr z,.cell
        inc b
.cell:  push hl
        ld de,CT_ATTRS - ATTRS
        add hl,de
        ld a,(hl)               ; the picture's
        pop hl
        dec c
        inc c
        jr z,.attr
        and %00111000           ; its paper
        or BRIGHT | WHITE
.attr:  ld (hl),a
        ld de,32
        add hl,de
        djnz .cell
        ret

;------------------------------------------------------------------------------
; ct_shields - each shield a cell on when its time comes, and its row
; painted: the shield's colour on its cells, the picture's on the rest.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
CS_ROW          equ 0
CS_LEN          equ 1
CS_SPEED        equ 2
CS_STEP         equ 3
CS_POS          equ 4
CS_CNT          equ 5
CS_SIZE         equ 6

        MACRO CT_SHIELD row?, len?, speed?, step?, start?
        ASSERT row? >= 4 && row? < CFG_GEN_ROW, "a shield is off the city, or under the generator"
        ASSERT len? >= 1 && len? < CT_WIDE && speed? >= 1 && (step? == 1 || step? == -1) && start? < CT_WIDE
        db row?, len?, speed?, (step?) & 255, start?, 1
        ENDM

ct_shields:
        ld ix,ct_shield_tab
        ld b,CT_SHIELDS
.one:   push bc
        dec (ix + CS_CNT)
        jr nz,.paint
        ld a,(ix + CS_SPEED)
        ld (ix + CS_CNT),a
        ld a,(ix + CS_POS)
        add a,(ix + CS_STEP)
        cp CT_WIDE
        jr c,.pos
        ld a,0                  ; one past the right: round to the left
        jr z,.pos
        ld a,CT_WIDE - 1        ; -1 (255), past the left: to the right
.pos:   ld (ix + CS_POS),a
.paint: ld l,(ix + CS_ROW)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or CT_LEFT
        ld l,a
        push hl
        ld de,CT_ATTRS
        add hl,de
        ex de,hl                ; DE = the picture's colours
        pop hl
        ld bc,ATTRS
        add hl,bc
        ld c,0
.cell:  ld a,c
        sub (ix + CS_POS)
        jr nc,.in
        add a,CT_WIDE
.in:    cp (ix + CS_LEN)
        ld a,CFG_SHIELD_ATTR
        jr c,.set
        ld a,(de)
.set:   ld (hl),a
        inc hl
        inc de
        inc c
        ld a,c
        cp CT_WIDE
        jr c,.cell
        ld de,CS_SIZE
        add ix,de
        pop bc
        djnz .one
        ret

ct_shield_tab:
        CFG_SHIELDS
CT_SHIELDS      equ ($ - ct_shield_tab) / CS_SIZE

;------------------------------------------------------------------------------
; ct_circle - the colours in CT_ATTRS come on in a circle that grows from
; B, C (row and column, in half cells: cell n's middle is 2n + 1), a ring
; of colour A leading it. A cell is inside when the sum of the squares of
; |2y + 1 - B| and |2x + 1 - C| is under R squared. Each ring waits for a
; frame (ct_wait), so the sound plays.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
ct_circle:
        ld (.rim + 1),a
        ld a,b
        ld (.cy + 1),a
        ; Each column's distance squared, once: CT_DX.
        ld hl,CT_DX
        ld b,0
.dx:    ld a,b
        add a,a
        inc a
        sub c
        jr nc,.dxp
        neg
.dxp:   push hl
        call ct_sq
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        inc b
        bit 5,b
        jr z,.dx
        xor a
.ring:  ld (ct_r),a
        call ct_sq
        ld (ct_in),hl
        ld a,(ct_r)
        add a,CT_RIM
        call ct_sq
        ld (ct_rim),hl
        ld hl,ATTRS
        ld de,CT_ATTRS
        ld b,0                  ; the row
.row:   ld a,b
        add a,a
        inc a
.cy:    sub 0                   ; the middle's row (patched)
        jr nc,.ydown
        neg
.ydown: push hl
        call ct_sq
        ld (ct_dy2),hl
        pop hl
        ld ix,CT_DX
        ld c,32
.cell:  push bc
        push hl
        ld l,(ix + 0)
        ld h,(ix + 1)
        ld bc,(ct_dy2)
        add hl,bc               ; the distance squared
        ld bc,(ct_in)
        or a
        sbc hl,bc
        jr c,.inside
        add hl,bc
        ld bc,(ct_rim)
        or a
        sbc hl,bc
        pop hl
        jr nc,.next             ; not reached yet
.rim:   ld (hl),0               ; the ring's colour (patched)
        jr .next
.inside:
        pop hl
        ld a,(de)               ; its own colours
        ld (hl),a
.next:  inc hl
        inc de
        inc ix
        inc ix
        pop bc
        dec c
        jr nz,.cell
        inc b
        ld a,b
        cp 24
        jr c,.row
        call ct_wait
        ld a,(ct_r)
        add a,CT_STEP
        cp CT_R_END + CT_STEP
        jr c,.ring
        ret

; HL = A squared. Corrupts: AF
ct_sq:  push bc
        push de
        ld e,a
        ld d,0
        ld h,d
        ld l,d
        ld b,8
.bit:   add hl,hl
        rla
        jr nc,.no
        add hl,de
.no:    djnz .bit
        pop de
        pop bc
        ret


        INCLUDE "../../tools/dzx0_standard.asm"

ct_high_end:
CT_HIGH_LEN     equ ct_high_end - ct_high
CT_DX           equ ct_high_end         ; 32 words: each column's distance, squared
        ASSERT CT_DX + 64 <= BSS_LIMIT, "Finale's ending has run past BSS_LIMIT"
        ASSERT ct_high == BSS_END, "cityhi.asm must start at the end of the run-time buffers"

    ENDIF
