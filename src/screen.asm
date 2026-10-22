;==============================================================================
; screen.asm - clearing the screen, border, and character-cell addressing
;==============================================================================

;------------------------------------------------------------------------------
; cls - clear bitmap to 0 and fill attributes with A
; In:  A = attribute byte
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
cls:
        ld hl,ATTRS
        ld de,ATTRS+1
        ld bc,ATTRS_SIZE-1
        ld (hl),a
        ldir

        ld hl,SCREEN
        ld de,SCREEN+1
        ld bc,SCREEN_SIZE-1
        ld (hl),0
        ldir
        ret

;------------------------------------------------------------------------------
; set_border - In: A = colour 0-7. Corrupts: AF
;------------------------------------------------------------------------------
set_border:
        and 7
        out (ULA_PORT),a
        ret

;------------------------------------------------------------------------------
; char_addr - bitmap address of the top pixel row of a character cell
; In:  B = row (0-23), C = column (0-31)
; Out: HL = screen address
; Layout: H = 010 RR 000 (RR = row/8 third), L = rrr CCCCC (rrr = row & 7)
; Corrupts: AF
;------------------------------------------------------------------------------
char_addr:
        ld a,b
        and %00011000
        or high SCREEN
        ld h,a
        ld a,b
        and %00000111
        rrca
        rrca
        rrca                    ; rrr into bits 7-5
        or c
        ld l,a
        ret

;------------------------------------------------------------------------------
; attr_addr - attribute address of a character cell
; In:  B = row, C = column.  Out: HL = $5800 + row*32 + col.  Corrupts: AF
;------------------------------------------------------------------------------
attr_addr:
        ld a,b
        rrca
        rrca
        rrca                    ; row*32: low 3 bits -> bits 7-5, high 2 -> 1-0
        ld l,a
        and %00000011
        or high ATTRS
        ld h,a
        ld a,l
        and %11100000
        or c
        ld l,a
        ret
