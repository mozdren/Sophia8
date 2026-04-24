; ---------------------------------------------------------------------------
; basic_expr.s8.asm
; Expression engine + identifier/number parsing + boolean ops used by Sophia BASIC.
;
; Provides:
;  - SKIPSP_CUR / PEEKCHAR_CUR / GETCHAR_CUR
;  - PARSE_IDENT (IDBUF/IDLEN in basic_state.s8.asm)
;  - VAR_* helpers (int variables)
;  - 16-bit helpers: NEG16/ADD16/SUB16, BOOL16_NOT/AND/OR
;  - keyword match/consume for expression keywords (AND/OR/NOT/STEP/PEEK/RND)
;  - numeric parsing: PARSE_NUM_DEC / PARSE_NUM_HEX
;  - EVAL_UINT8_EXPR (for POKE/PEEK params)
;  - EVAL_EXPR and PARSE_* precedence tree, including PEEK() and RND()
;
; Dependencies:
;  - basic_state.s8.asm (runtime vars, IDBUF, VAR table, CURPTR, etc.)
;  - text.s8.asm (SKIPSP, ISDIGIT, TOUPPER_Z)
;  - basic_helpers.s8.asm (PARSE_UINT8, PARSE_INT16, MOD16U, ADD_ENTRY_OFFSET, etc.)
;  - rng.s8.asm + basic_rng.s8.asm (RNG_NEXT wrapper) for RND()
;
; Notes:
;  - CMPR/CMP are destructive on Sophia8: compare on a temp copy when needed.
; ---------------------------------------------------------------------------

SKIPSP_CUR:
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    RET

PEEKCHAR_CUR:
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    LOADR R0, R1, R2
    RET

GETCHAR_CUR:
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    LOADR R0, R1, R2
    INC R2
    JNZ R2, GC_OK
    INC R1
GC_OK:
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    RET

; ---------------------------------------------------------------------------
; EVAL_UINT8_EXPR
; ---------------------------------------------------------------------------
; Parse a small uint8 expression of the form:
;   n([+-]n)*
; where n is an unsigned decimal byte.
;
; Uses CURPTR_H/CURPTR_L as the source pointer and updates it on return.
; Returns:
;   R0 = result (0..255)
; ---------------------------------------------------------------------------
EVAL_UINT8_EXPR:
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2

    CALL PARSE_UINT8
    SET #0x00, R6
    ADDR R0, R6

E8_LOOP:
    CALL SKIPSP
    LOADR R0, R1, R2

    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x2B
    JZ R7, E8_PLUS

    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x2D
    JZ R7, E8_MINUS

    JMP E8_DONE

E8_PLUS:
    INC R2
    JNZ R2, E8P1
    INC R1
E8P1:
    CALL SKIPSP
    PUSH R6
    CALL PARSE_UINT8
    POP R6
    ADDR R0, R6
    JMP E8_LOOP

E8_MINUS:
    INC R2
    JNZ R2, E8M1
    INC R1
E8M1:
    CALL SKIPSP
    PUSH R6
    CALL PARSE_UINT8
    POP R6
    SUBR R0, R6
    JMP E8_LOOP

E8_DONE:
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    SET #0x00, R0
    ADDR R6, R0
    RET

; ----------------------
; Identifier parsing
; ----------------------
PARSE_IDENT:
    ; Parse identifier into IDBUF (0x2090), max 8 chars.
    ; Accepts A-Z as first char, then A-Z or 0-9, optional trailing '$' to mark string var.
    ; Input pointer: R1:R2, advanced on return. Returns R0=1 success else 0.
    LOADR R0, R1, R2

    ; first char must be A..Z
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x41
    JC PI_FAIL
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x5B
    JC PI_START
    JMP PI_FAIL

PI_START:
    SET #0x00, R5
    STORE R5, IDLEN
    STORE R5, IDTYPE

    ; ensure IDBUF is zero-padded (VAR_FIND compares full 8 bytes)
    SET #0x68, R3
    SET #0xA0, R4
    SET #8, R7
    SET #0x00, R0
PI_ZPAD:
    STORER R0, R3, R4
    INC R4
    JNZ R4, PI_Z1
    INC R3
PI_Z1:
    DEC R7
    JNZ R7, PI_ZPAD


PI_LOOP:
    LOADR R0, R1, R2

    ; '$' => mark string and consume
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x24
    JZ R7, PI_DOLLAR

    ; '%' => integer type marker (ignore, consume)
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x25
    JZ R7, PI_PERCENT
    ; check A-Z
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x41
    JC PI_CHK_DIG
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x5B
    JC PI_STORE
    JMP PI_DONE

PI_CHK_DIG:
    ; check 0-9
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x30
    JC PI_DONE
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x3A
    JC PI_STORE
    JMP PI_DONE

PI_STORE:
    LOAD IDLEN, R5
    ; CMP is destructive, compare on a temp copy
    SET #0x00, R7
    ADDR R5, R7
    CMP R7, #8
    JZ R7, PI_ADV

    SET #0x68, R3
    SET #0xA0, R4
    ADDR R5, R4
    ; store original char in R0 (not clobbered)
    STORER R0, R3, R4

    INC R5
    STORE R5, IDLEN
PI_ADV:
    INC R2
    JNZ R2, PI_LOOP
    INC R1
    JMP PI_LOOP

PI_DOLLAR:
    SET #0x01, R5
    STORE R5, IDTYPE
    INC R2
    JNZ R2, PI_DONE
    INC R1

PI_PERCENT:
    ; integer suffix '%': keep IDTYPE=0 and consume
    INC R2
    JNZ R2, PI_DONE
    INC R1
PI_DONE:
    ; zero-pad name to 8 bytes
    LOAD IDLEN, R5
PI_PAD:
    ; CMP is destructive, compare on a temp copy
    SET #0x00, R7
    ADDR R5, R7
    CMP R7, #8
    JZ R7, PI_OK
    SET #0x68, R3
    SET #0xA0, R4
    ADDR R5, R4
    SET #0x00, R7
    STORER R7, R3, R4
    INC R5
    JMP PI_PAD

PI_OK:
    SET #0x01, R0
    RET

PI_FAIL:
    SET #0x00, R0
    RET


NEG16:
    ; two's complement negate R6:R7
    SET #0xFF, R0
    SUBR R7, R0
    SET #0x00, R7
    ADDR R0, R7

    SET #0xFF, R0
    SUBR R6, R0
    SET #0x00, R6
    ADDR R0, R6

    INC R7
    JNZ R7, N16_RET
    INC R6
N16_RET:
    RET

ADD16:
    ADDR R5, R7
    JNC A16_NC
    INC R6
A16_NC:
    ADDR R4, R6
    RET

SUB16:
    SUBR R5, R7
    JNC S16_NB
    DEC R6
S16_NB:
    SUBR R4, R6
    RET

PUTDEC16S:
    ; Print signed 16-bit integer in R6:R7
    ; Clobbers: R0,R1,R2,R3,R4,R5,R6,R7
    ; If value is 0 => prints 0
    ; If negative => prints '-' then abs(value)

    ; check zero
    CMP R6, #0
    JNZ R6, P16S_CHKNEG
    CMP R7, #0
    JNZ R7, P16S_CHKNEG
    SET #0x30, R0
    CALL PUTC
    RET

P16S_CHKNEG:
    ; sign bit in high byte
    ; sign test: if hi < 0x80 => positive
    SET #0x00, R0
    ADDR R6, R0
    CMP R0, #0x80
    JC P16S_POS

    ; negative: print '-'
    SET #0x2D, R0
    CALL PUTC

    ; abs via negate
    CALL NEG16

P16S_POS:
    ; unsigned print of R6:R7
    CALL PUTDEC16U
    RET

PUTDEC16U:
    ; Print unsigned 16-bit integer in R6:R7 using repeated subtraction.
    ; Clobbers: R0-R5

    ; if high byte 0 -> PUTDEC8
    CMP R6, #0
    JNZ R6, P16U_DO
    SET #0, R0
    ADDR R7, R0
    CALL PUTDEC8
    RET

P16U_DO:
    SET #0, R4          ; printed flag

    ; 10000
    SET #0x27, R2
    SET #0x10, R3
    CALL P16U_DIGIT

    ; 1000
    SET #0x03, R2
    SET #0xE8, R3
    CALL P16U_DIGIT

    ; 100
    SET #0x00, R2
    SET #0x64, R3
    CALL P16U_DIGIT

    ; 10
    SET #0x00, R2
    SET #0x0A, R3
    CALL P16U_DIGIT

    ; ones (0..9) in R7 (since value < 10)
    SET #0x30, R0
    ADDR R7, R0
    CALL PUTC
    RET

P16U_DIGIT:
    ; Compute one decimal digit by subtracting denom (R2:R3) from value (R6:R7)
    ; Prints digit if printed flag set OR digit>0.
    ; Updates value to remainder.
    ; Uses R1 as digit counter.

    SET #0, R1
P16U_DLOOP:
    ; if value < denom => stop
    ; compare hi
    SET #0, R0
    ADDR R6, R0
    CMPR R0, R2          ; destructive on R0
    JC P16U_DDONE        ; carry => value_hi < denom_hi
    JNZ R0, P16U_SUBOK   ; non-zero => value_hi > denom_hi
    ; hi equal, compare lo
    SET #0, R0
    ADDR R7, R0
    CMPR R0, R3
    JC P16U_DDONE

P16U_SUBOK:
    ; value -= denom
    SUBR R3, R7
    JNC P16U_SNB
    DEC R6
P16U_SNB:
    SUBR R2, R6
    INC R1
    JMP P16U_DLOOP

P16U_DDONE:
    ; decide printing
    CMP R4, #0
    JNZ R4, P16U_PRT
    CMP R1, #0
    JZ R1, P16U_RET
P16U_PRT:
    SET #0x30, R0
    ADDR R1, R0
    CALL PUTC
    SET #1, R4
P16U_RET:
    RET

; ---------------------------------------------------------------------------
; Keyword matching for AND/OR/NOT in expressions
; ---------------------------------------------------------------------------
MATCH_KW_AND:
    CALL MATCH_KW_A3
    RET
MATCH_KW_OR:
    CALL MATCH_KW_O2
    RET
MATCH_KW_NOT:
    CALL MATCH_KW_N3
    RET

; Match helpers: non-destructive peek from CURPTR after SKIPSP_CUR
; Return R0=1 if matched, and store kw length in IDLEN for CONSUME_KW.
MATCH_KW_A3:
    ; AND
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    LOADR R0, R1, R2
    CMP R0, #0x41
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x4E
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x44
    JNZ R0, MK_NO
    SET #3, R0
    STORE R0, IDLEN
    SET #1, R0
    RET
MATCH_KW_O2:
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    LOADR R0, R1, R2
    CMP R0, #0x4F
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x52
    JNZ R0, MK_NO
    SET #2, R0
    STORE R0, IDLEN
    SET #1, R0
    RET
MATCH_KW_N3:
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    LOADR R0, R1, R2
    CMP R0, #0x4E
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x4F
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x54
    JNZ R0, MK_NO
    SET #3, R0
    STORE R0, IDLEN
    SET #1, R0
    RET

MATCH_KW_STEP:
    ; STEP (for FOR)
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    LOADR R0, R1, R2
    CMP R0, #0x53
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x54
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x45
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x50
    JNZ R0, MK_NO
    SET #4, R0
    STORE R0, IDLEN
    SET #1, R0
    RET

MATCH_KW_PEEK:
    ; PEEK
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    LOADR R0, R1, R2
    CMP R0, #0x50
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x45
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x45
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x4B
    JNZ R0, MK_NO
    SET #4, R0
    STORE R0, IDLEN
    SET #1, R0
    RET

MATCH_KW_RND:
    ; RND
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    LOADR R0, R1, R2
    CMP R0, #0x52
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x4E
    JNZ R0, MK_NO
    INC R2
    LOADR R0, R1, R2
    CMP R0, #0x44
    JNZ R0, MK_NO
    SET #3, R0
    STORE R0, IDLEN
    SET #1, R0
    RET

MK_NO:
    SET #0, R0
    RET

CONSUME_KW:
    ; advance CURPTR by IDLEN
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    LOAD IDLEN, R0
CK_LOOP:
    CMP R0, #0
    JZ R0, CK_DONE
    INC R2
    JNZ R2, CK_1
    INC R1
CK_1:
    DEC R0
    JMP CK_LOOP
CK_DONE:
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    RET

; ---------------------------------------------------------------------------
; Boolean helpers
; ---------------------------------------------------------------------------
BOOL16_NOT:
    ; R6:R7 => boolean NOT
    CMP R6, #0
    JNZ R6, BN_FALSE
    CMP R7, #0
    JNZ R7, BN_FALSE
    SET #0, R6
    SET #1, R7
    RET
BN_FALSE:
    SET #0, R6
    SET #0, R7
    RET

BOOL16_AND:
    ; left in R4:R5, right in R6:R7 => R6:R7 = (left!=0 && right!=0)
    ; bool(left)
    CMP R4, #0
    JNZ R4, BA_LNZ
    CMP R5, #0
    JZ R5, BA_FALSE
BA_LNZ:
    ; bool(right)
    CMP R6, #0
    JNZ R6, BA_TRUE
    CMP R7, #0
    JZ R7, BA_FALSE
BA_TRUE:
    SET #0, R6
    SET #1, R7
    RET
BA_FALSE:
    SET #0, R6
    SET #0, R7
    RET

BOOL16_OR:
    ; left in R4:R5, right in R6:R7 => R6:R7 = (left!=0 || right!=0)
    CMP R4, #0
    JNZ R4, BO_TRUE
    CMP R5, #0
    JNZ R5, BO_TRUE
    CMP R6, #0
    JNZ R6, BO_TRUE
    CMP R7, #0
    JZ R7, BO_FALSE
BO_TRUE:
    SET #0, R6
    SET #1, R7
    RET
BO_FALSE:
    SET #0, R6
    SET #0, R7
    RET

; ---------------------------------------------------------------------------
; Comparisons (signed 16-bit): left in R4:R5, right in R6:R7, result in R6:R7 (0/1)
; ---------------------------------------------------------------------------
CMP16_EQ:
    CMPR R4, R6
    JNZ R4, CE_FALSE
    CMPR R5, R7
    JNZ R5, CE_FALSE
    SET #0, R6
    SET #1, R7
    RET
CE_FALSE:
    SET #0, R6
    SET #0, R7
    RET

CMP16_NE:
    CALL CMP16_EQ
    ; invert
    CALL BOOL16_NOT
    RET

; Signed less-than: compare sign first, then magnitude
CMP16_LT:
    ; signed (R4:R5) < (R6:R7) => R6:R7 = 0/1
    ; determine sign flags: neg if hi >= 0x80
    SET #0x00, R0
    ADDR R4, R0
    CMP R0, #0x80
    JC CLT_LPOS
    SET #1, R0
    JMP CLT_LDONE
CLT_LPOS:
    SET #0, R0
CLT_LDONE:
    SET #0x00, R1
    ADDR R6, R1
    CMP R1, #0x80
    JC CLT_RPOS
    SET #1, R1
    JMP CLT_RDONE
CLT_RPOS:
    SET #0, R1
CLT_RDONE:
    ; if signs differ: negative < positive
    CMPR R0, R1
    JZ R0, CLT_SAMESIGN
    CMP R0, #1
    JZ R0, CLT_TRUE
    JMP CLT_FALSE
CLT_SAMESIGN:
    ; compare as unsigned (works for same sign)
    CMPR R4, R6
    JC CLT_TRUE
    JNZ R4, CLT_FALSE
    CMPR R5, R7
    JC CLT_TRUE
    JMP CLT_FALSE
CLT_TRUE:
    SET #0, R6
    SET #1, R7
    RET
CLT_FALSE:
    SET #0, R6
    SET #0, R7
    RET

CMP16_GT:
    ; left > right == right < left
    ; swap and reuse LT
    PUSH R4
    PUSH R5
    SET #0, R4
    ADDR R6, R4
    SET #0, R5
    ADDR R7, R5
    POP R7
    POP R6
    CALL CMP16_LT
    RET

CMP16_LE:
    CALL CMP16_GT
    CALL BOOL16_NOT
    RET

CMP16_GE:
    CALL CMP16_LT
    CALL BOOL16_NOT
    RET

; ---------------------------------------------------------------------------
; Arithmetic helpers
; ---------------------------------------------------------------------------
SUB16_LR:
    ; left in R4:R5, right in R6:R7 => result in R6:R7 = left-right
    ; move left to R6:R7, right to R4:R5 then SUB16
    STORE R6, TMPH
    STORE R7, TMPL
    SET #0, R6
    ADDR R4, R6
    SET #0, R7
    ADDR R5, R7
    LOAD TMPH, R4
    LOAD TMPL, R5
    CALL SUB16
    RET

SIGNFLAG_R45:
    ; R0 = 1 if R4:R5 is negative (signed 16), else 0
    SET #0, R0
    ADDR R4, R0
    CMP R0, #0x80
    JC SF45_POS
    SET #1, R0
    RET
SF45_POS:
    SET #0, R0
    RET

SIGNFLAG_R67:
    ; R0 = 1 if R6:R7 is negative
    SET #0, R0
    ADDR R6, R0
    CMP R0, #0x80
    JC SF67_POS
    SET #1, R0
    RET
SF67_POS:
    SET #0, R0
    RET

MUL16S:
    ; signed multiply: left in R4:R5, right in R6:R7 => result in R6:R7
    ; compute result sign flag in R0 (0/1)
    CALL SIGNFLAG_R45   ; R0=left_neg
    PUSH R0
    CALL SIGNFLAG_R67   ; R0=right_neg
    POP R1              ; R1=left_neg
    ; R0=right_neg, R1=left_neg
    CMPR R0, R1
    JZ R0, M16S_SIGN0
    SET #1, R2
    JMP M16S_SIGNDONE
M16S_SIGN0:
    SET #0, R2
M16S_SIGNDONE:
    ; abs operands
    CALL ABS16_R45
    CALL ABS16_R67
    ; unsigned multiply
    CALL MUL16U
    ; apply sign if needed
    CMP R2, #0
    JZ R2, M16S_RET
    CALL NEG16
M16S_RET:
    RET

DIV16S:
    ; signed divide: left in R4:R5, right in R6:R7 => quotient in R6:R7
    CMP R6, #0
    JNZ R6, D16S_NZ
    CMP R7, #0
    JNZ R7, D16S_NZ
    SET #0, R6
    SET #0, R7
    RET
D16S_NZ:
    CALL SIGNFLAG_R45   ; R0=left_neg
    PUSH R0
    CALL SIGNFLAG_R67   ; R0=right_neg
    POP R1              ; left_neg
    CMPR R0, R1
    JZ R0, D16S_SIGN0
    SET #1, R2
    JMP D16S_SIGNDONE
D16S_SIGN0:
    SET #0, R2
D16S_SIGNDONE:
    CALL ABS16_R45
    CALL ABS16_R67
    CALL DIV16U
    CMP R2, #0
    JZ R2, D16S_RET
    CALL NEG16
D16S_RET:
    RET

ABS16_R45:
    ; abs for value in R4:R5
    SET #0x00, R2
    ADDR R4, R2
    CMP R2, #0x80
    JC A45_RET
    ; negative -> negate
    PUSH R6
    PUSH R7
    SET #0, R6
    ADDR R4, R6
    SET #0, R7
    ADDR R5, R7
    CALL NEG16
    SET #0, R4
    ADDR R6, R4
    SET #0, R5
    ADDR R7, R5
    POP R7
    POP R6
A45_RET:
    RET

ABS16_R67:
    ; abs for value in R6:R7
    SET #0x00, R2
    ADDR R6, R2
    CMP R2, #0x80
    JC A67_RET
    CALL NEG16
A67_RET:
    RET

MUL16U:
    ; unsigned multiply: (R4:R5) * (R6:R7) => R6:R7
    ;
    ; IMPORTANT:
    ; Use shift/add multiply only (no MULR).
    ; This avoids VM/toolchain variants where MULR encoding causes HALT
    ; when BASIC evaluates * (e.g. PRINT 2*3).
    ;
    ; Scratch:
    ;   TMPH:TMPL  accumulator (result)
    ;   MULH:MULL  shifting multiplier copy
    ; Clobbers: R0..R3

    ; store multiplier copy
    STORE R6, MULH
    STORE R7, MULL

    ; acc = 0
    SET #0, R2
    STORE R2, TMPH
    STORE R2, TMPL

    SET #16, R3
MU_LOOP:
    ; if (multiplier & 1) acc += multiplicand
    LOAD MULL, R0
    SET #0, R2
    ADDR R0, R2
    DIV #2, R2, R1          ; R1 = remainder (0/1)
    CMP R1, #0
    JZ R1, MU_SKIP_ADD

    LOAD TMPH, R6
    LOAD TMPL, R7
    CALL ADD16              ; R6:R7 += R4:R5
    STORE R6, TMPH
    STORE R7, TMPL

MU_SKIP_ADD:
    ; multiplicand <<= 1  (correct 16-bit shift)
    SHL #1, R5              ; low, carry = old bit7
    JNC MU_SHL_NO_C
    SET #1, R0
    JMP MU_SHL_C_DONE
MU_SHL_NO_C:
    SET #0, R0
MU_SHL_C_DONE:
    SHL #1, R4
    CMP R0, #0
    JZ R0, MU_SHL_DONE
    ADD #1, R4
MU_SHL_DONE:

    ; multiplier >>= 1 (stored in MULH:MULL)
    LOAD MULH, R6
    LOAD MULL, R7

    ; old high LSB -> R1 (0/1)
    SET #0, R0
    ADDR R6, R0
    DIV #2, R0, R1

    SHR #1, R6
    SHR #1, R7
    CMP R1, #0
    JZ R1, MU_SHR_DONE
    ADD #0x80, R7
MU_SHR_DONE:
    STORE R6, MULH
    STORE R7, MULL

    DEC R3
    JNZ R3, MU_LOOP

    ; return acc in R6:R7
    LOAD TMPH, R6
    LOAD TMPL, R7
    RET
DIV16U:
    ; unsigned divide (R4:R5) / (R6:R7) => quotient in R6:R7
    ; remainder discarded
    ; naive repeated subtraction (slow but OK for small BASIC)
    ;
    ; IMPORTANT: CMPR/CMP are destructive, and SUB16/ADD16 use R6:R7 as accumulator.
    ; Keep the divisor in DIVH:DIVL, and the running quotient in TMPH:TMPL.

    ; stash divisor
    STORE R6, DIVH
    STORE R7, DIVL

    ; quotient = 0
    SET #0, R2
    STORE R2, TMPH
    STORE R2, TMPL

DU_LOOP:
    ; reload divisor into R6:R7 for compare/subtract
    LOAD DIVH, R6
    LOAD DIVL, R7

    ; if dividend < divisor => done
    PUSH R4
    PUSH R5
    CMPR R4, R6
    JC DU_DONE
    JNZ R4, DU_SUB
    CMPR R5, R7
    JC DU_DONE
DU_SUB:
    ; restore original dividend into R4:R5
    POP R5
    POP R4

    ; compute dividend -= divisor
    ; set R6:R7 = dividend, R4:R5 = divisor, call SUB16, move back
    PUSH R4
    PUSH R5
    LOAD DIVH, R4
    LOAD DIVL, R5
    POP R7      ; dividend low -> R7
    POP R6      ; dividend high -> R6
    CALL SUB16
    ; move result back to dividend regs
    SET #0, R4
    ADDR R6, R4
    SET #0, R5
    ADDR R7, R5

    ; quotient++
    LOAD TMPH, R6
    LOAD TMPL, R7
    INC R7
    JNZ R7, DU_Q1
    INC R6
DU_Q1:
    STORE R6, TMPH
    STORE R7, TMPL

    JMP DU_LOOP

DU_DONE:
    ; restore stack (compare path)
    POP R5
    POP R4

    ; return quotient in R6:R7
    LOAD TMPH, R6
    LOAD TMPL, R7
    RET

MOD16U:
    ; unsigned modulo (R4:R5) % (R6:R7) => remainder in R6:R7
    ; Uses naive repeated subtraction (slow but acceptable for BASIC).
    ; If divisor is 0, returns 0.
    ;
    ; IMPORTANT: CMPR/CMP are destructive; SUB16 uses R6:R7 as accumulator.

    ; divisor == 0 ?
    SET #0x00, R0
    ADDR R6, R0
    JNZ R0, MU_OKDIV
    SET #0x00, R0
    ADDR R7, R0
    JNZ R0, MU_OKDIV
    SET #0x00, R6
    SET #0x00, R7
    RET
MU_OKDIV:
    ; stash divisor
    STORE R6, DIVH
    STORE R7, DIVL

MU_LOOP2:
    ; reload divisor into R6:R7 for compare/subtract
    LOAD DIVH, R6
    LOAD DIVL, R7

    ; if dividend < divisor => done
    PUSH R4
    PUSH R5
    CMPR R4, R6
    JC MU_DONE2
    JNZ R4, MU_SUB2
    CMPR R5, R7
    JC MU_DONE2
MU_SUB2:
    ; restore original dividend into R4:R5
    POP R5
    POP R4

    ; compute dividend -= divisor
    PUSH R4
    PUSH R5
    LOAD DIVH, R4
    LOAD DIVL, R5
    POP R7      ; dividend low -> R7
    POP R6      ; dividend high -> R6
    CALL SUB16
    ; move result back to dividend regs
    SET #0x00, R4
    ADDR R6, R4
    SET #0x00, R5
    ADDR R7, R5

    JMP MU_LOOP2

MU_DONE2:
    ; restore stack (compare path)
    POP R5
    POP R4

    ; return remainder in R6:R7
    SET #0x00, R6
    ADDR R4, R6
    SET #0x00, R7
    ADDR R5, R7
    RET

; ----------------------

; Number parsing
; ----------------------
PARSE_NUM_DEC:
    ; Parses unsigned decimal at CURPTR into R6:R7.
    ; Advances CURPTR.
    SET #0, R6
    SET #0, R7
PND_LOOP:
    CALL PEEKCHAR_CUR

    ; digit?
    SET #0, R4
    ADDR R0, R4
    CMP R4, #0x30
    JC PND_DONE
    SET #0, R4
    ADDR R0, R4
    CMP R4, #0x3A
    JNC PND_DONE

    ; consume digit
    CALL GETCHAR_CUR
    SUB #0x30, R0

    ; val = val*10
    PUSH R0
    SET #10, R0
    CALL MUL16U8
    POP R0

    ; val += digit
    ADDR R0, R7
    JNC PND_LOOP
    INC R6
    JMP PND_LOOP
PND_DONE:
    RET

MUL16U8:
    ; unsigned: (R6:R7) *= R0 (8-bit)
    ; result in R6:R7
    ; Uses shift-add
    SET #0, R4
    ADDR R6, R4
    SET #0, R5
    ADDR R7, R5

    SET #0, R6
    SET #0, R7

    SET #8, R3
M168_LOOP:
    ; if (R0 LSB) add multiplicand
    SET #0, R2
    ADDR R0, R2
    DIV #2, R2, R1     ; R1=remainder
    CMP R1, #0
    JZ R1, M168_SKIP
    CALL ADD16
M168_SKIP:
    ; multiplicand <<= 1
    ; Correct 16-bit left shift (see MUL16U note)
    SHL #1, R5
    JNC M168_M1
    SET #1, R1
    JMP M168_M1C
M168_M1:
    SET #0, R1
M168_M1C:
    SHL #1, R4
    CMP R1, #0
    JZ R1, M168_M1D
    ADD #1, R4
M168_M1D:
    ; multiplier >>= 1
    SHR #1, R0
    DEC R3
    JNZ R3, M168_LOOP
    RET
PARSE_NUM_HEX:
    SET #0x00, R6
    SET #0x00, R7
PNH_LOOP:
    CALL PEEKCHAR_CUR
    CMP R0, #0x30
    JC PNH_DONE
    CMP R0, #0x3A
    JC PNH_DIG
    CMP R0, #0x41
    JC PNH_DONE
    CMP R0, #0x47
    JC PNH_HEX
    JMP PNH_DONE
PNH_DIG:
    CALL GETCHAR_CUR
    SUB #0x30, R0
    JMP PNH_ACC
PNH_HEX:
    CALL GETCHAR_CUR
    SUB #0x41, R0
    ADD #10, R0
PNH_ACC:
    SHL #4, R7
    ADDR R0, R7
    JMP PNH_LOOP
PNH_DONE:
    RET

; ----------------------
; Expression evaluator (minimal but usable)
; ----------------------
; Expression evaluator (16-bit signed + relops + AND/OR/NOT)
;
; Grammar (lowest precedence last):
;   expr      := or_expr
;   or_expr   := and_expr (OR and_expr)*
;   and_expr  := rel_expr (AND rel_expr)*
;   rel_expr  := add_expr ( (=|<>|<|>|<=|>=) add_expr )?
;   add_expr  := term (("+"|"-") term)*
;   term      := factor (("*"|"/") factor)*
;   factor    := "-" factor | NOT factor | "(" expr ")" | "$"hex | number | ident
;
; Values:
;   - numeric values are signed 16-bit in R6:R7
;   - boolean results are 0 (false) or 1 (true)
; ----------------------

EVAL_EXPR:
    CALL PARSE_OR
    RET

; OR
PARSE_OR:
    CALL PARSE_AND
PO_LOOP:
    CALL SKIPSP_CUR
    CALL MATCH_KW_OR
    CMP R0, #0x01
    JNZ R0, PO_DONE
    ; consume OR
    CALL CONSUME_KW
    PUSH R6
    PUSH R7
    CALL PARSE_AND
    POP R5
    POP R4
    ; left in R4:R5, right in R6:R7
    CALL BOOL16_OR
    JMP PO_LOOP
PO_DONE:
    RET

; AND
PARSE_AND:
    CALL PARSE_REL
PA_LOOP:
    CALL SKIPSP_CUR
    CALL MATCH_KW_AND
    CMP R0, #0x01
    JNZ R0, PA_DONE
    CALL CONSUME_KW
    PUSH R6
    PUSH R7
    CALL PARSE_REL
    POP R5
    POP R4
    CALL BOOL16_AND
    JMP PA_LOOP
PA_DONE:
    RET

; relational
PARSE_REL:
    ; -----------------------------------------------------------------------
    ; Relational parsing.
    ;
    ; Enhancement: support string relational operators in IF and other boolean
    ; expressions using the same syntax as numeric relations:
    ;   =  <>  <  >  <=  >=
    ;
    ; Strategy:
    ;   - First attempt to parse a string expression (incl. concatenation)
    ;     using STR_PARSE_EXPR_CONCAT (from basic_strfn.s8.asm).
    ;   - Only if a relational operator follows, we treat it as string compare.
    ;   - Otherwise we restore the cursor and fall back to numeric parsing.
    ;
    ; Result:
    ;   R6:R7 = 0/1 (false/true)
    ; -----------------------------------------------------------------------

    ; Save cursor so we can safely fall back to numeric parsing.
    LOAD CURPTR_H, R0
    STORE R0, REL_SAV_H
    LOAD CURPTR_L, R0
    STORE R0, REL_SAV_L

    ; Try parse left string expression.
    CALL STR_PARSE_EXPR_CONCAT
    CMP R0, #0x01
    JNZ R0, PR_NUMERIC     ; not a string expr

    ; Save left string (ptr+len) while we look for a relop.
    PUSH R6
    PUSH R7
    PUSH R5

    CALL SKIPSP_CUR

    ; NOTE: program lines are tokenized. Relational operators can appear
    ; either as ASCII ('<','=', '>') or as single-byte tokens:
    ;   '<' => 0x1C, '=' => 0x1D, '>' => 0x1E
    ; CMP/CMPR are destructive on Sophia8, so we must re-peek before each check.

    ; '='
    CALL PEEKCHAR_CUR
    CMP R0, #0x3D
    JZ R0, PRS_EQ
    CALL PEEKCHAR_CUR
    CMP R0, #0x1D
    JZ R0, PRS_EQ

    ; '<'
    CALL PEEKCHAR_CUR
    CMP R0, #0x3C
    JZ R0, PRS_LT
    CALL PEEKCHAR_CUR
    CMP R0, #0x1C
    JZ R0, PRS_LT

    ; '>'
    CALL PEEKCHAR_CUR
    CMP R0, #0x3E
    JZ R0, PRS_GT
    CALL PEEKCHAR_CUR
    CMP R0, #0x1E
    JZ R0, PRS_GT

    ; No operator after string expression: restore cursor and fall back.
PRS_FALLBACK:
    POP R5
    POP R7
    POP R6
    LOAD REL_SAV_H, R0
    STORE R0, CURPTR_H
    LOAD REL_SAV_L, R0
    STORE R0, CURPTR_L
    JMP PR_NUMERIC_ENTRY

; -------------------------
; String relational operators
; -------------------------

PRS_EQ:
    ; consume '='
    CALL GETCHAR_CUR
    JMP PRS_PARSE_RIGHT_EQ

PRS_LT:
    ; consume '<'
    CALL GETCHAR_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x3D          ; <= (ASCII)
    JZ R0, PRS_LE
    CALL PEEKCHAR_CUR
    CMP R0, #0x1D          ; <= (token '=')
    JZ R0, PRS_LE

    CALL PEEKCHAR_CUR
    CMP R0, #0x3E          ; <> (ASCII)
    JZ R0, PRS_NE
    CALL PEEKCHAR_CUR
    CMP R0, #0x1E          ; <> (token '>')
    JZ R0, PRS_NE
    ; plain '<'
    JMP PRS_PARSE_RIGHT_LT

PRS_GT:
    ; consume '>'
    CALL GETCHAR_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x3D          ; >= (ASCII)
    JZ R0, PRS_GE
    CALL PEEKCHAR_CUR
    CMP R0, #0x1D          ; >= (token '=')
    JZ R0, PRS_GE
    ; plain '>'
    JMP PRS_PARSE_RIGHT_GT

PRS_LE:
    CALL GETCHAR_CUR       ; consume '='
    JMP PRS_PARSE_RIGHT_LE

PRS_GE:
    CALL GETCHAR_CUR       ; consume '='
    JMP PRS_PARSE_RIGHT_GE

PRS_NE:
    CALL GETCHAR_CUR       ; consume '>'
    JMP PRS_PARSE_RIGHT_NE

; Common helper: compare left (saved on stack) with right (parsed now).
; Uses STR_ALLOC_AND_COPY to create NUL-terminated copies for STRCMP.
; Returns compare result in R0: 0 (eq), 0xFF (lt), 0x01 (gt)
PRS_DO_CMP:
    ; Length-aware lexicographic compare (no NUL termination needed).
    ; Inputs:
    ;   R1:R2 = s1 ptr, R3 = len1
    ;   R6:R7 = s2 ptr, R5 = len2
    ; Output:
    ;   R0 = 0x00 equal, 0xFF if s1 < s2, 0x01 if s1 > s2
    ; Clobbers:
    ;   R4

PRS_CMP_LOOP:
    CMP R3, #0x00
    JZ R3, PRS_LEN1_DONE
    CMP R5, #0x00
    JZ R5, PRS_LEN2_DONE

    LOADR R4, R1, R2      ; c1
    LOADR R0, R6, R7      ; c2

    CMPR R4, R0
    JZ R4, PRS_CMP_EQ
    JC PRS_CMP_LT
    SET #0x01, R0
    RET
PRS_CMP_LT:
    SET #0xFF, R0
    RET
PRS_CMP_EQ:
    ; ++s1
    INC R2
    JNZ R2, PRS_S1_OK
    INC R1
PRS_S1_OK:
    ; ++s2
    INC R7
    JNZ R7, PRS_S2_OK
    INC R6
PRS_S2_OK:

    DEC R3
    DEC R5
    JMP PRS_CMP_LOOP

PRS_LEN1_DONE:
    CMP R5, #0x00
    JZ R5, PRS_CMP_EQUAL
    SET #0xFF, R0          ; s1 shorter => s1 < s2
    RET
PRS_LEN2_DONE:
    CMP R3, #0x00
    JZ R3, PRS_CMP_EQUAL
    SET #0x01, R0          ; s2 shorter => s1 > s2
    RET
PRS_CMP_EQUAL:
    SET #0x00, R0
    RET

PRS_PARSE_RIGHT_EQ:

    CALL STR_PARSE_EXPR_CONCAT
    CMP R0, #0x01
    JNZ R0, PRS_FAIL
    ; restore left (saved ptr+len)
    POP R3
    POP R2
    POP R1
    CALL PRS_DO_CMP
    CMP R0, #0x00
    JZ R0, PRS_TRUE
    JMP PRS_FALSE

PRS_PARSE_RIGHT_NE:
    CALL STR_PARSE_EXPR_CONCAT
    CMP R0, #0x01
    JNZ R0, PRS_FAIL
    ; restore left (saved ptr+len)
    POP R3
    POP R2
    POP R1
    CALL PRS_DO_CMP
    CMP R0, #0x00
    JZ R0, PRS_FALSE
    JMP PRS_TRUE

PRS_PARSE_RIGHT_LT:
    CALL STR_PARSE_EXPR_CONCAT
    CMP R0, #0x01
    JNZ R0, PRS_FAIL
    ; restore left (saved ptr+len)
    POP R3
    POP R2
    POP R1
    CALL PRS_DO_CMP
    CMP R0, #0xFF
    JZ R0, PRS_TRUE
    JMP PRS_FALSE

PRS_PARSE_RIGHT_GT:
    CALL STR_PARSE_EXPR_CONCAT
    CMP R0, #0x01
    JNZ R0, PRS_FAIL
    ; restore left (saved ptr+len)
    POP R3
    POP R2
    POP R1
    CALL PRS_DO_CMP
    CMP R0, #0x01
    JZ R0, PRS_TRUE
    JMP PRS_FALSE

PRS_PARSE_RIGHT_LE:
    CALL STR_PARSE_EXPR_CONCAT
    CMP R0, #0x01
    JNZ R0, PRS_FAIL
    ; restore left (saved ptr+len)
    POP R3
    POP R2
    POP R1
    CALL PRS_DO_CMP
    CMP R0, #0x01
    JZ R0, PRS_FALSE
    JMP PRS_TRUE

PRS_PARSE_RIGHT_GE:
    CALL STR_PARSE_EXPR_CONCAT
    CMP R0, #0x01
    JNZ R0, PRS_FAIL
    ; restore left (saved ptr+len)
    POP R3
    POP R2
    POP R1
    CALL PRS_DO_CMP
    CMP R0, #0xFF
    JZ R0, PRS_FALSE
    JMP PRS_TRUE

PRS_FAIL:
    ; parse failure: treat as false (caller typically prints syntax elsewhere)
PRS_FALSE:
    SET #0x00, R6
    SET #0x00, R7
    RET
PRS_TRUE:
    SET #0x00, R6
    SET #0x01, R7
    RET

; -------------------------
; Numeric relational operators (original behaviour)
; -------------------------

PR_NUMERIC:
PR_NUMERIC_ENTRY:
    CALL PARSE_ADD
    CALL SKIPSP_CUR

    ; Tokenized/ASCII relational operators (see comment in string section).

    ; '='
    CALL PEEKCHAR_CUR
    CMP R0, #0x3D
    JZ R0, PR_EQ
    CALL PEEKCHAR_CUR
    CMP R0, #0x1D
    JZ R0, PR_EQ

    ; '<'
    CALL PEEKCHAR_CUR
    CMP R0, #0x3C
    JZ R0, PR_LT
    CALL PEEKCHAR_CUR
    CMP R0, #0x1C
    JZ R0, PR_LT

    ; '>'
    CALL PEEKCHAR_CUR
    CMP R0, #0x3E
    JZ R0, PR_GT
    CALL PEEKCHAR_CUR
    CMP R0, #0x1E
    JZ R0, PR_GT

    RET

PR_EQ:
    CALL GETCHAR_CUR
    PUSH R6
    PUSH R7
    CALL PARSE_ADD
    POP R5
    POP R4
    CALL CMP16_EQ
    RET

PR_LT:
    CALL GETCHAR_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x3D      ; <= (ASCII)
    JZ R0, PR_LE
    CALL PEEKCHAR_CUR
    CMP R0, #0x1D      ; <= (token '=')
    JZ R0, PR_LE

    CALL PEEKCHAR_CUR
    CMP R0, #0x3E      ; <> (ASCII)
    JZ R0, PR_NE
    CALL PEEKCHAR_CUR
    CMP R0, #0x1E      ; <> (token '>')
    JZ R0, PR_NE
    ; '<'
    PUSH R6
    PUSH R7
    CALL PARSE_ADD
    POP R5
    POP R4
    CALL CMP16_LT
    RET

PR_GT:
    CALL GETCHAR_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x3D      ; >= (ASCII)
    JZ R0, PR_GE
    CALL PEEKCHAR_CUR
    CMP R0, #0x1D      ; >= (token '=')
    JZ R0, PR_GE
    ; '>'
    PUSH R6
    PUSH R7
    CALL PARSE_ADD
    POP R5
    POP R4
    CALL CMP16_GT
    RET

PR_LE:
    CALL GETCHAR_CUR
    PUSH R6
    PUSH R7
    CALL PARSE_ADD
    POP R5
    POP R4
    CALL CMP16_LE
    RET

PR_GE:
    CALL GETCHAR_CUR
    PUSH R6
    PUSH R7
    CALL PARSE_ADD
    POP R5
    POP R4
    CALL CMP16_GE
    RET

PR_NE:
    CALL GETCHAR_CUR
    PUSH R6
    PUSH R7
    CALL PARSE_ADD
    POP R5
    POP R4
    CALL CMP16_NE
    RET

; add/sub
PARSE_ADD:
    CALL PARSE_TERM
PA2_LOOP:
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x2B
    JZ R0, PA2_ADD
    CALL PEEKCHAR_CUR
    CMP R0, #0x2D
    JZ R0, PA2_SUB
    RET
PA2_ADD:
    CALL GETCHAR_CUR
    PUSH R6
    PUSH R7
    CALL PARSE_TERM
    POP R5
    POP R4
    ; left in R4:R5, right in R6:R7 => R6:R7 = left+right
    CALL ADD16
    JMP PA2_LOOP
PA2_SUB:
    CALL GETCHAR_CUR
    PUSH R6
    PUSH R7
    CALL PARSE_TERM
    POP R5
    POP R4
    ; R6:R7 = left-right
    CALL SUB16_LR
    JMP PA2_LOOP

; term mul/div
PARSE_TERM:
    CALL PARSE_FACTOR
PT2_LOOP:
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x2A
    JZ R0, PT2_MUL
    CALL PEEKCHAR_CUR
    CMP R0, #0x2F
    JZ R0, PT2_DIV
    RET
PT2_MUL:
    CALL GETCHAR_CUR
    PUSH R6
    PUSH R7
    CALL PARSE_FACTOR
    POP R5
    POP R4
    CALL MUL16S
    JMP PT2_LOOP
PT2_DIV:
    CALL GETCHAR_CUR
    PUSH R6
    PUSH R7
    CALL PARSE_FACTOR
    POP R5
    POP R4
    CALL DIV16S
    JMP PT2_LOOP

PARSE_FACTOR:
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x2D
    JZ R0, PF2_NEG
    CALL MATCH_KW_NOT
    CMP R0, #0x01
    JZ R0, PF2_NOT
    ; refresh char after keyword probe
    CALL PEEKCHAR_CUR
    CMP R0, #0x28
    JZ R0, PF2_PAR
    CALL PEEKCHAR_CUR
    CMP R0, #0x24
    JZ R0, PF2_HEX
    CALL ISDIGIT
    CMP R0, #0x01
    JZ R0, PF2_DEC

	; LEN(...)
	CALL MATCH_KW_LEN
	CMP R0, #0x01
	JZ R0, PF2_LEN

	; ASC(...)
	CALL MATCH_KW_ASC
	CMP R0, #0x01
	JZ R0, PF2_ASC

	; INSTR(...)
	CALL MATCH_KW_INSTR
	CMP R0, #0x01
	JZ R0, PF2_INSTR

	; VAL(...)
	CALL MATCH_KW_VAL
	CMP R0, #0x01
	JZ R0, PF2_VAL
	
	; PEEK(...)
CALL MATCH_KW_PEEK
CMP R0, #0x01
JZ R0, PF2_PEEK
; RND()
CALL MATCH_KW_RND
CMP R0, #0x01
JZ R0, PF2_RND

; identifier
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL PARSE_IDENT
    CMP R0, #0x01
    JNZ R0, PF2_ZERO
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    LOAD IDTYPE, R0
    CMP R0, #0x01
    JZ R0, PF2_ZERO

    ; array reference: <ident>(<expr>)
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x28
    JNZ R0, PF2_SCALAR
    CALL GETCHAR_CUR
    CALL EVAL_EXPR              ; index in R6:R7
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x29
    JNZ R0, PF2_ZERO
    CALL GETCHAR_CUR
    CALL ARRAY_LOAD_INT_ELEM    ; loads into R6:R7
    RET

PF2_SCALAR:
    CALL VAR_FIND
    CMP R0, #0x01
    JNZ R0, PF2_ZERO
    CALL LOAD_VAR_INT
    RET
PF2_ZERO:
    SET #0x00, R6
    SET #0x00, R7
    RET
PF2_NEG:
    CALL GETCHAR_CUR
    CALL PARSE_FACTOR
    CALL NEG16
    RET
PF2_NOT:
    CALL CONSUME_KW
    CALL PARSE_FACTOR
    CALL BOOL16_NOT
    RET
PF2_PAR:
    CALL GETCHAR_CUR
    CALL EVAL_EXPR
    CALL SKIPSP_CUR
    CALL GETCHAR_CUR
    RET
PF2_HEX:
    CALL GETCHAR_CUR
    CALL PARSE_NUM_HEX
    RET
PF2_DEC:
    CALL PARSE_NUM_DEC
    RET

PF2_LEN:
    CALL STRFN_LEN
    RET

PF2_ASC:
    CALL STRFN_ASC
    RET

PF2_INSTR:
    CALL STRFN_INSTR
    RET

PF2_VAL:
    CALL STRFN_VAL
    RET

PF2_PEEK:
    CALL CONSUME_KW
    CALL SKIPSP_CUR
    CALL GETCHAR_CUR       ; '('
    CALL EVAL_EXPR
    CALL SKIPSP_CUR
    CALL GETCHAR_CUR       ; ')'
    ; address in R6:R7
    SET #0x00, R1
    ADDR R6, R1
    SET #0x00, R2
    ADDR R7, R2
    LOADR R7, R1, R2
    SET #0x00, R6
    RET

PF2_RND:
    ; RND() or RND(<n>) => integer in 0..n-1 (if n>0), else raw RNG_NEXT
    CALL CONSUME_KW
    CALL SKIPSP_CUR

    ; divisor in R4:R5 (0 => no modulo)
    SET #0x00, R4
    SET #0x00, R5
    STORE R4, DIVH
    STORE R5, DIVL

    CALL PEEKCHAR_CUR
    CMP R0, #0x28
    JNZ R0, RND_GEN

    ; consume '(' and parse expression
    CALL GETCHAR_CUR
    CALL SKIPSP_CUR
    CALL EVAL_EXPR          ; result in R6:R7
    ; save divisor
    SET #0x00, R4
    ADDR R6, R4
    SET #0x00, R5
    ADDR R7, R5
    STORE R4, DIVH
    STORE R5, DIVL

    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x29
    JNZ R0, RND_GEN
    CALL GETCHAR_CUR

RND_GEN:
    ; generate raw random in R6:R7
    CALL RNG_NEXT
    ; reload divisor (RNG_NEXT may clobber regs)
    LOAD DIVH, R4
    LOAD DIVL, R5

    ; if divisor == 0, return raw
    SET #0x00, R0
    ADDR R4, R0
    JNZ R0, RND_MOD
    SET #0x00, R0
    ADDR R5, R0
    JZ R0, RND_RET

RND_MOD:
    ; remainder = rand % divisor
    ; save divisor
    PUSH R4
    PUSH R5
    ; move rand -> dividend R4:R5
    SET #0x00, R4
    ADDR R6, R4
    SET #0x00, R5
    ADDR R7, R5
    ; restore divisor -> R6:R7
    POP R7
    POP R6
    CALL MOD16U

RND_RET:
    RET
