;==============================================================================
; codes.asm - level codes: six letters that start a game at a later level
;
; Everything about the codes is in this file: how they are made, the
; table, showing one, and checking one typed on the menu.
;
; A code is 24 bits, shown as six letters of four bits each. The
; letters are the 16 in code_alpha: no I, O, Q, V, W, X, Y, Z, M or N,
; which are the hardest to read, or to tell apart, in the banner's
; three-by-five blocks.
;
; HOW ONE IS MADE (at assembly time, by LEVEL_CODES below):
;   1. The level number (5 bits) on top, a 19-bit checksum of it below.
;      The checksum is the level times a constant plus a key.
;   2. The 24 bits are stirred: times an odd number, XOR with itself
;      shifted right, twice, then XOR with a second key. Every step
;      can be undone, so two levels can never get the same code, but
;      every bit of the result depends on every bit of the level.
;   3. Each four bits is a letter.
; So the codes for two levels in a row look nothing alike, and changing
; a letter gives a code that is not in the table. No two codes share
; more than three letters in the same places, so changing one or two
; letters of a real code can never make another real code. Guessing is
; one in about 880,000 for each try.
;
; The game never undoes the stirring. A typed code is turned back into
; its 24 bits and looked up in the table, 3 bytes a level, which is
; smaller than the code to reverse it.
;
; Levels 2 to CFG_CODE_LEVELS have codes (Atlantis is 1 to 20, then the
; city interlude; Trigon comes after). Level 1 is the menu's "Start game".
;==============================================================================

    IFDEF TRIGON
; Trigon's own keys: its codes are nothing like Atlantis's, so a code
; from one game opens nothing in the other.
CODE_KEY_SUM    equ $2C6F1      ; the checksum's key, 19 bits
CODE_KEY_MIX    equ $4D93A7     ; the last XOR, 24 bits
    ELSE
CODE_KEY_SUM    equ $5A3C9      ; the checksum's key, 19 bits
CODE_KEY_MIX    equ $B7E21D     ; the last XOR, 24 bits
    ENDIF
CODE_LEN        equ 6

; The Trigon code: the Atlantis ending shows it (interlude.asm), and
; Trigon's menu asks for it before level 1 (src/trigon/). Not a level
; code: it has letters (N) that code_alpha has not, so it is never one.
; Kept out of docs/ and the README: notes/LEVEL-CODES-LIST.md.
        MACRO GATE_WORD
        db "KRAKEN"
        ENDM

; The table, in the data block: code_alpha, then 3 bytes a level, top
; byte first. The multipliers are below 128, so a 24-bit value times
; one stays inside the assembler's 32-bit signed numbers.
        MACRO LEVEL_CODES
code_alpha:
        db "ABCDEFGHJKLPRSTU"
code_tab:
code_lvl = 2
        DUP CFG_CODE_LEVELS - 1
code_v = (code_lvl << 19) | ((code_lvl * 24631 + CODE_KEY_SUM) & $7FFFF)
code_v = (code_v * 107) & $FFFFFF
code_v = code_v ^ (code_v >> 11)
code_v = (code_v * 79) & $FFFFFF
code_v = code_v ^ (code_v >> 13) ^ CODE_KEY_MIX
        db code_v >> 16, (code_v >> 8) & 255, code_v & 255
code_lvl = code_lvl + 1
        EDUP
code_tab_end:
        ; The 40 keys, as the ULA's half-rows give them: $FEFE first,
        ; bit 0 first. 0 is a shift key, which types nothing.
key_map:
        db 0,   "ZXCV"
        db "ASDFG"
        db "QWERT"
        db "12345"
        db "09876"
        db "POIUY"
        db 13,  "LKJH"
        db " ", 0, "MNB"
        ENDM

        ASSERT CFG_CODE_LEVELS >= 2 && CFG_CODE_LEVELS <= 31, "a level is 5 bits of the code"

; code_buf: in bss.asm (zeroed at start-up, not on the tape)  ; six letters and a 0, for print_string
; code_in: in bss.asm (zeroed at start-up, not on the tape)  ; a typed code, as 24 bits

;------------------------------------------------------------------------------
; code_text - the letters of a level's code into code_buf
; In: A = level, binary, 2 to CFG_CODE_LEVELS. Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
code_text:
        sub 2
        ld l,a
        add a,a
        add a,l                 ; 3 bytes a level
        ld l,a
        ld h,0
        ld de,code_tab
        add hl,de
        ld de,code_buf
        ld b,3
.byte:  ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        call .letter
        ld a,(hl)
        call .letter
        inc hl
        djnz .byte
        xor a
        ld (de),a
        ret
.letter:
        push hl
        and 15
        ld hl,code_alpha
        add a,l
        ld l,a
        jr nc,.in
        inc h
.in:    ld a,(hl)
        ld (de),a
        inc de
        pop hl
        ret

;------------------------------------------------------------------------------
; code_level - the level whose code is in code_buf
; Out: A = the level, or 0 if code_buf is not a code.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
code_level:
        ; Letters back to four bits each, two to a byte.
        ld hl,code_buf
        ld de,code_in
        ld b,3
.pack:  call .nibble
        ret c
        rlca
        rlca
        rlca
        rlca
        ld (de),a
        call .nibble
        ret c
        ex de,hl
        or (hl)
        ld (hl),a
        ex de,hl
        inc de
        djnz .pack
        ; Then the table, one level at a time.
        ld hl,code_tab
        ld c,2
.level: ld de,code_in
        ld b,3
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.miss
        inc de
        inc hl
        djnz .cmp
        ld a,c
        ret
.miss:  inc hl                  ; B counts the byte that missed and the
        djnz .miss              ; rest of the entry: on to the next
        inc c
        ld a,c
        cp CFG_CODE_LEVELS + 1
        jr c,.level
        xor a
        ret
; (HL) = a letter. Out: A = its number, HL on the next letter, or carry
; and A = 0 if it is not one of code_alpha's.
.nibble:
        push bc
        push de
        ld a,(hl)
        inc hl
        ld de,code_alpha
        ld b,16
.find:  ex de,hl
        cp (hl)
        ex de,hl
        jr z,.found
        inc de
        djnz .find
        pop de
        pop bc
        xor a
        scf
        ret
.found: ld a,16
        sub b
        pop de
        pop bc
        or a
        ret

;------------------------------------------------------------------------------
; key_char - the character of a key that is down, or 0 for none
; The first key found, in half-row order. The shift keys type nothing.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
key_char:
        ld hl,key_map
        ld bc,$FE00 | ULA_PORT
.row:   in a,(c)
        ld d,5
.bit:   rra
        jr nc,.down
.next:  inc hl
        dec d
        jr nz,.bit
        rlc b
        jr c,.row
        xor a
        ret
.down:  ld e,a
        ld a,(hl)
        or a
        ret nz
        ld a,e
        jr .next

; Out: zero flag set when no key at all is down. Corrupts: AF
any_key:
        xor a
        in a,(ULA_PORT)
        cpl
        and %00011111
        ret

; Wait for every key to be let go. Corrupts: AF
keys_up:
        call wait_frame
        call any_key
        jr nz,keys_up
        ret
