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

;==============================================================================
; Pixel-row addressing
;
; The bitmap is NOT stored top-to-bottom. For a pixel row y (0-191) split into
; bits  y7 y6 | y5 y4 y3 | y2 y1 y0  the address of its leftmost byte is
;
;     H = 0 1 0 y7 y6 y2 y1 y0       L = y5 y4 y3 0 0 0 0 0
;
;   y7 y6 = which third of the screen (top, middle, bottom: 2048 bytes each)
;   y5 y4 y3 = which character row inside that third (0-7)
;   y2 y1 y0 = which pixel line inside the character cell (0-7)
;
; So moving down one pixel inside a cell is "INC H" (+256), but crossing into
; the next cell or third needs more work. Rather than handle that in every
; drawing routine, we work it out once for all 192 rows and keep a table.
; See docs/SPRITES.md for a worked example.
;==============================================================================

;------------------------------------------------------------------------------
; screen_row_addr - address of the leftmost byte of pixel row y
; In:  A = y (0-191)
; Out: HL = screen address
; Corrupts: AF, C
;------------------------------------------------------------------------------
screen_row_addr:
        ld c,a                  ; keep y; we need three different slices of it

        ; H, part 1: y2 y1 y0 (line within the cell) go in H bits 2-0
        and %00000111
        ld h,a

        ; H, part 2: y7 y6 (which third) go in H bits 4-3
        ld a,c
        and %11000000           ; y7 y6 in bits 7-6
        rrca
        rrca
        rrca                    ; now in bits 4-3
        or h
        or high SCREEN          ; + $40 -> 010 in bits 7-5
        ld h,a

        ; L: y5 y4 y3 (character row within the third) go in L bits 7-5
        ld a,c
        and %00111000           ; y5 y4 y3 in bits 5-3
        rlca
        rlca                    ; now in bits 7-5; bits 4-0 (column) are 0
        ld l,a
        ret

;------------------------------------------------------------------------------
; build_row_table - fill ROW_TABLE with the address of every pixel row
; Run once at start-up. Afterwards, the address of row y is the word at
; ROW_TABLE + y*2, and the byte at column c (0-31) is that address + c.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
build_row_table:
        ld de,ROW_TABLE
        ld b,0                  ; B = y, counting 0..191
.next:  ld a,b
        push bc
        call screen_row_addr    ; HL = address of row y
        pop bc
        ex de,hl                ; HL -> table entry, DE = address
        ld (hl),e               ; store little-endian (low byte first)
        inc hl
        ld (hl),d
        inc hl
        ex de,hl                ; DE -> next table entry again
        inc b
        ld a,b
        cp 192
        jr nz,.next
        ret

;------------------------------------------------------------------------------
; row_table_entry - point IX at the table entry for pixel row y
; In:  A = y.  Out: IX -> ROW_TABLE + y*2.  Corrupts: AF, DE, HL
; IX is used so that (ix+0)/(ix+1) read the two address bytes and the caller
; can step to the next row with two INC IX, leaving HL and DE free for the
; actual drawing. (IX is slower than HL, but there aren't enough registers.)
;------------------------------------------------------------------------------
row_table_entry:
        ld l,a                  ; HL = y
        ld h,0
        add hl,hl               ; * 2, because each entry is a 16-bit word
        ld de,ROW_TABLE
        add hl,de
        push hl                 ; there is no "LD IX,HL", so go via the stack
        pop ix
        ret
