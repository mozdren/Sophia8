; ---------------------------------------------------------------------------
; basic_flow.s8.asm
; Flow-control statements for Sophia BASIC:
;   - GOSUB <line> / RETURN
;   - FOR <var>=<expr> TO <expr> [STEP <expr>] / NEXT
;
; This file intentionally contains only flow-control related handlers and uses
; the shared BASIC runtime state defined in basic_state.s8.asm.
;
; Dependencies:
;   - basic_state.s8.asm   (RUNNING, RUN_PTR_*, RUN_NEXT_*, GOSUB_SP, FOR_SP, JUMPED, etc.)
;   - basic_vars.s8.asm    (VAR_FIND_OR_CREATE, LOAD_VAR_INT, STORE_VAR_INT)
;   - basic_expr.s8.asm    (EVAL_EXPR, SKIPSP_CUR, PARSE_IDENT, MATCH_KW_STEP,
;                       CONSUME_KW, ADD16, CMP16_LE, CMP16_GE)
;   - basic_errors.s8.asm  (PRINT_SYNTAX_ERROR, PRINT_UNDEF_LINE)
;
; Notes:
;   - These handlers are called from the statement dispatcher (basic_stmt.s8.asm).
;   - On syntax/runtime error they print a BASIC error and RET.
; ---------------------------------------------------------------------------

; ------------------------------------------------------------
; CMD_GOSUB: only valid while RUNNING (program execution)
; ------------------------------------------------------------
CMD_GOSUB:
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX

    ; parse line number and find target record
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL PARSE_U16_DEC
    STORE R6, TMP_LINENO_H
    STORE R7, TMP_LINENO_L
    CALL FIND_LINE
    CMP R0, #0x01
    JNZ R0, FLOW_UNDEF

    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L

    ; push return ptr to 0x6E00 + sp*2
    LOAD GOSUB_SP, R0
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #16
    JZ R3, FLOW_SYNTAX
    SET #0x00, R3
    ADDR R0, R3
    SHL #1, R3
    SET #0x6E, R1
    SET #0x00, R2
    ADDR R3, R2
    LOAD RUN_NEXT_H, R7
    STORER R7, R1, R2
    INC R2
    LOAD RUN_NEXT_L, R7
    STORER R7, R1, R2
    INC R0
    STORE R0, GOSUB_SP

    ; jump
    LOAD TMP_PTR_H, R0
    STORE R0, RUN_PTR_H
    LOAD TMP_PTR_L, R0
    STORE R0, RUN_PTR_L
    SET #0x01, R0
    STORE R0, JUMPED
    RET

; ------------------------------------------------------------
; CMD_RETURN: only valid while RUNNING (program execution)
; ------------------------------------------------------------
CMD_RETURN:
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX

    LOAD GOSUB_SP, R0
    ; CMP is destructive on Sophia8, so compare a scratch copy.
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x00
    JZ R3, FLOW_SYNTAX
    DEC R0
    STORE R0, GOSUB_SP
    SHL #1, R0
    SET #0x6E, R1
    SET #0x00, R2
    ADDR R0, R2
    LOADR R7, R1, R2
    STORE R7, RUN_PTR_H
    INC R2
    LOADR R7, R1, R2
    STORE R7, RUN_PTR_L
    SET #0x01, R0
    STORE R0, JUMPED
    RET

; ------------------------------------------------------------
; CMD_FOR: only valid while RUNNING (program execution)
; Stack record layout at 0x6E20 + idx*8:
;   +0..1 var ptr (H,L)
;   +2..3 end value (H,L)
;   +4..5 step value (H,L)
;   +6..7 return ptr (next program record)
; ------------------------------------------------------------
CMD_FOR:
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX

    ; parse identifier
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    CALL PARSE_IDENT
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    LOAD IDTYPE, R0
    CMP R0, #0x01
    JZ R0, FLOW_SYNTAX

    CALL VAR_FIND_OR_CREATE
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L

    ; '='
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x3D
    JNZ R0, FLOW_SYNTAX
    CALL GETCHAR_CUR

    ; start expr -> store to var
    CALL EVAL_EXPR
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    CALL STORE_VAR_INT

    ; expect "TO"
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x54
    JNZ R0, FLOW_SYNTAX
    CALL GETCHAR_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x4F
    JNZ R0, FLOW_SYNTAX
    CALL GETCHAR_CUR

    ; end expr -> TMPH/TMPL
    CALL EVAL_EXPR
    STORE R6, TMPH
    STORE R7, TMPL

    ; default step = 1 -> MULH/MULL
    SET #0x00, R0
    STORE R0, MULH
    SET #0x01, R0
    STORE R0, MULL

    ; optional STEP
    CALL SKIPSP_CUR
    CALL MATCH_KW_STEP
    CMP R0, #0x01
    JNZ R0, FOR_PUSH
    CALL CONSUME_KW
    CALL EVAL_EXPR
    STORE R6, MULH
    STORE R7, MULL

FOR_PUSH:
    LOAD FOR_SP, R0
    ; CMP is destructive on Sophia8, so compare a scratch copy.
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #8
    JZ R3, FLOW_SYNTAX

    ; addr = 0x6E20 + sp*8
    SET #0x00, R3
    ADDR R0, R3
    SHL #3, R3
    SET #0x6E, R1
    SET #0x20, R2
    ADDR R3, R2
    JNC FOR_AOK
    INC R1
FOR_AOK:
    ; var ptr
    LOAD TMP_PTR_H, R7
    STORER R7, R1, R2
    INC R2
    LOAD TMP_PTR_L, R7
    STORER R7, R1, R2
    INC R2
    ; end
    LOAD TMPH, R7
    STORER R7, R1, R2
    INC R2
    LOAD TMPL, R7
    STORER R7, R1, R2
    INC R2
    ; step
    LOAD MULH, R7
    STORER R7, R1, R2
    INC R2
    LOAD MULL, R7
    STORER R7, R1, R2
    INC R2
    ; return ptr = RUN_NEXT_*
    LOAD RUN_NEXT_H, R7
    STORER R7, R1, R2
    INC R2
    LOAD RUN_NEXT_L, R7
    STORER R7, R1, R2

    INC R0
    STORE R0, FOR_SP
    RET

; ------------------------------------------------------------
; CMD_NEXT: only valid while RUNNING (program execution)
; ------------------------------------------------------------
CMD_NEXT:
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX

    LOAD FOR_SP, R0
    ; CMP is destructive on Sophia8, so compare a scratch copy.
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x00
    JZ R3, FLOW_SYNTAX
    DEC R0              ; top index in R0

    ; addr = 0x6E20 + top*8
    SET #0x00, R3
    ADDR R0, R3
    SHL #3, R3
    SET #0x6E, R1
    SET #0x20, R2
    ADDR R3, R2
    JNC NX_AOK
    INC R1
NX_AOK:
    ; var ptr -> TMP_PTR
    LOADR R4, R1, R2
    INC R2
    LOADR R5, R1, R2
    STORE R4, TMP_PTR_H
    STORE R5, TMP_PTR_L
    INC R2
    ; end -> TMPH/TMPL
    LOADR R6, R1, R2
    INC R2
    LOADR R7, R1, R2
    STORE R6, TMPH
    STORE R7, TMPL
    INC R2
    ; step -> MULH/MULL
    LOADR R6, R1, R2
    INC R2
    LOADR R7, R1, R2
    STORE R6, MULH
    STORE R7, MULL
    INC R2
    ; return ptr -> DIVH:DIVL
    LOADR R6, R1, R2
    STORE R6, DIVH
    INC R2
    LOADR R6, R1, R2
    STORE R6, DIVL

    ; load current var value
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    CALL LOAD_VAR_INT      ; R6:R7

    ; add step
    SET #0x00, R4
    ADDR R6, R4
    SET #0x00, R5
    ADDR R7, R5
    LOAD MULH, R6
    LOAD MULL, R7
    CALL ADD16             ; result in R6:R7

    ; store back
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    CALL STORE_VAR_INT

    ; compare to end depending on step sign
    SET #0x00, R4
    ADDR R6, R4
    SET #0x00, R5
    ADDR R7, R5
    LOAD TMPH, R6
    LOAD TMPL, R7
    LOAD MULH, R1
    CMP R1, #0x80
    JC NX_POS

    CALL CMP16_GE
    JMP NX_DECIDE
NX_POS:
    CALL CMP16_LE

NX_DECIDE:
    CMP R7, #0x01
    JZ R7, NX_CONT

    ; finish loop: pop FOR_SP = top index (R0)
    STORE R0, FOR_SP
    RET

NX_CONT:
    LOAD DIVH, R7
    STORE R7, RUN_PTR_H
    LOAD DIVL, R7
    STORE R7, RUN_PTR_L
    SET #0x01, R1
    STORE R1, JUMPED
    RET

; ------------------------------------------------------------
; CMD_DO / CMD_WHILE / CMD_ENDWHILE
; Line-oriented block loops:
;   DO
;     ...
;   WHILE <expr>
;
;   WHILE <expr>
;     ...
;   ENDWHILE
; ------------------------------------------------------------
CMD_DO:
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x00
    JNZ R0, FLOW_SYNTAX
    RET

CMD_WHILE:
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX

    LOAD RUN_PTR_H, R1
    LOAD RUN_PTR_L, R2
    CALL FLOW_CLASS_AT
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x02
    JZ R3, FLOW_WHILE_OPEN
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x03
    JZ R3, FLOW_WHILE_CLOSE
    JMP FLOW_SYNTAX

FLOW_WHILE_OPEN:
    CALL EVAL_EXPR
    CMP R6, #0x00
    JNZ R6, FLOW_WOPEN_TRUE
    CMP R7, #0x00
    JNZ R7, FLOW_WOPEN_TRUE

    LOAD RUN_PTR_H, R1
    LOAD RUN_PTR_L, R2
    CALL FLOW_FIND_MATCHING_ENDWHILE
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    CALL PROG_NEXT_PTR
    STORE R1, RUN_PTR_H
    STORE R2, RUN_PTR_L
    SET #0x01, R0
    STORE R0, JUMPED
    RET
FLOW_WOPEN_TRUE:
    RET

FLOW_WHILE_CLOSE:
    CALL EVAL_EXPR
    CMP R6, #0x00
    JNZ R6, FLOW_WC_TRUE
    CMP R7, #0x00
    JNZ R7, FLOW_WC_TRUE
    RET
FLOW_WC_TRUE:
    LOAD RUN_PTR_H, R1
    LOAD RUN_PTR_L, R2
    CALL FLOW_FIND_MATCHING_DO
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    STORE R1, RUN_PTR_H
    STORE R2, RUN_PTR_L
    SET #0x01, R0
    STORE R0, JUMPED
    RET

CMD_ENDWHILE:
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x00
    JNZ R0, FLOW_SYNTAX

    LOAD RUN_PTR_H, R1
    LOAD RUN_PTR_L, R2
    CALL FLOW_FIND_MATCHING_WHILE
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    STORE R1, RUN_PTR_H
    STORE R2, RUN_PTR_L
    SET #0x01, R0
    STORE R0, JUMPED
    RET

; ------------------------------------------------------------
; Flow block helpers for DO/WHILE/ENDWHILE
; ------------------------------------------------------------
; FLOW_RAW_CLASS_AT
;   Input : R1:R2 = program record pointer
;   Output: R0 = 0 other, 1 DO, 2 WHILE, 3 ENDWHILE
FLOW_RAW_CLASS_AT:
    LOAD CURPTR_H, R5
    LOAD CURPTR_L, R6
    PUSH R5
    PUSH R6

    CALL PROG_GET_TEXT_PTR
    CMP R0, #0x00
    JZ R0, FRCA_NONE

    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL GETTOKEN

    ; DO
    SET #0x68, R1
    SET #0x80, R2
    SET #0x03, R3
    SET #0x68, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, FRCA_DO

    ; WHILE
    SET #0x68, R1
    SET #0x80, R2
    SET #0x03, R3
    SET #0x70, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, FRCA_WHILE

    ; ENDWHILE
    SET #0x68, R1
    SET #0x80, R2
    SET #0x03, R3
    SET #0x78, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, FRCA_ENDWHILE

FRCA_NONE:
    SET #0x00, R0
    JMP FRCA_DONE
FRCA_DO:
    SET #0x01, R0
    JMP FRCA_DONE
FRCA_WHILE:
    SET #0x02, R0
    JMP FRCA_DONE
FRCA_ENDWHILE:
    SET #0x03, R0

FRCA_DONE:
    POP R6
    POP R5
    STORE R5, CURPTR_H
    STORE R6, CURPTR_L
    RET

; FLOW_SCAN_ADVANCE
;   Advance SCAN_PTR_* to the next program record.
FLOW_SCAN_ADVANCE:
    LOAD SCAN_PTR_H, R1
    LOAD SCAN_PTR_L, R2
    CALL PROG_NEXT_PTR
    STORE R1, SCAN_PTR_H
    STORE R2, SCAN_PTR_L
    RET

; FLOW_PUSH_CLASS
;   Input: R0 = class byte (1=DO, 2=WHILE)
FLOW_PUSH_CLASS:
    LOAD CLS_SP, R1
    ; ignore overflow beyond 16 nested blocks
    SET #0x00, R2
    ADDR R1, R2
    CMP R2, #16
    JZ R2, FPC_DONE
    SET #0x68, R3
    SET #0xB0, R4
    ADDR R1, R4
    STORER R0, R3, R4
    INC R1
    STORE R1, CLS_SP
FPC_DONE:
    RET

; FLOW_POP_CLASS
;   Output: R0 = popped class, or 0 if empty
FLOW_POP_CLASS:
    LOAD CLS_SP, R1
    CMP R1, #0x00
    JZ R1, FPO_EMPTY
    DEC R1
    STORE R1, CLS_SP
    SET #0x68, R3
    SET #0xB0, R4
    ADDR R1, R4
    LOADR R0, R3, R4
    RET
FPO_EMPTY:
    SET #0x00, R0
    RET

; FLOW_TOP_CLASS
;   Output: R0 = top class, or 0 if empty
FLOW_TOP_CLASS:
    LOAD CLS_SP, R1
    CMP R1, #0x00
    JZ R1, FTC_EMPTY
    DEC R1
    SET #0x68, R3
    SET #0xB0, R4
    ADDR R1, R4
    LOADR R0, R3, R4
    RET
FTC_EMPTY:
    SET #0x00, R0
    RET

; FLOW_MATCH_PUSH_PTR
;   Input : R1:R2 = pointer to push
FLOW_MATCH_PUSH_PTR:
    LOAD MATCH_SP, R0
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #16
    JZ R3, FMPP_DONE

    SET #0x68, R3
    SET #0xC0, R4
    ADDR R0, R4
    STORER R1, R3, R4

    SET #0x68, R3
    SET #0xD0, R4
    ADDR R0, R4
    STORER R2, R3, R4

    INC R0
    STORE R0, MATCH_SP
FMPP_DONE:
    RET

; FLOW_MATCH_POP_PTR
FLOW_MATCH_POP_PTR:
    LOAD MATCH_SP, R0
    CMP R0, #0x00
    JZ R0, FMP_POP_DONE
    DEC R0
    STORE R0, MATCH_SP
FMP_POP_DONE:
    RET

; FLOW_MATCH_TOP_PTR
;   Output: R0 = 1 if present and R1:R2 = top pointer, else R0 = 0
FLOW_MATCH_TOP_PTR:
    LOAD MATCH_SP, R0
    CMP R0, #0x00
    JZ R0, FMT_EMPTY
    DEC R0

    SET #0x68, R3
    SET #0xC0, R4
    ADDR R0, R4
    LOADR R1, R3, R4

    SET #0x68, R3
    SET #0xD0, R4
    ADDR R0, R4
    LOADR R2, R3, R4

    SET #0x01, R0
    RET
FMT_EMPTY:
    SET #0x00, R0
    RET

; FLOW_CLASS_AT
;   Input : R1:R2 = program record pointer
;   Output: R0 = 0 other, 1 DO opener, 2 WHILE opener,
;                3 DO...WHILE terminator, 4 ENDWHILE
FLOW_CLASS_AT:
    STORE R1, MATCH_PTR_H
    STORE R2, MATCH_PTR_L
    CALL FLOW_RAW_CLASS_AT
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x01
    JZ R3, FCA_RET_DO
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x03
    JZ R3, FCA_RET_ENDWHILE
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x02
    JZ R3, FCA_DECIDE_WHILE
    SET #0x00, R0
    RET

FCA_RET_DO:
    SET #0x01, R0
    RET
FCA_RET_ENDWHILE:
    SET #0x04, R0
    RET
FCA_DECIDE_WHILE:
    LOAD MATCH_PTR_H, R1
    LOAD MATCH_PTR_L, R2
    CALL FLOW_WHILE_HAS_ENDWHILE
    CMP R0, #0x01
    JZ R0, FCA_RET_WHILE
    SET #0x03, R0
    RET
FCA_RET_WHILE:
    SET #0x02, R0
    RET

; FLOW_WHILE_HAS_ENDWHILE
;   Input : R1:R2 = raw WHILE record
;   Output: R0 = 1 if a matching ENDWHILE exists ahead, else 0
FLOW_WHILE_HAS_ENDWHILE:
    CALL PROG_NEXT_PTR
    STORE R1, SCAN_PTR_H
    STORE R2, SCAN_PTR_L
    SET #0x00, R7
FWHE_LOOP:
    LOAD SCAN_PTR_H, R1
    LOAD SCAN_PTR_L, R2
    LOAD PROG_END_H, R3
    LOAD PROG_END_L, R4
    SET #0x00, R5
    ADDR R1, R5
    CMPR R5, R3
    JNZ R5, FWHE_HAVE
    SET #0x00, R5
    ADDR R2, R5
    CMPR R5, R4
    JZ R5, FWHE_NOT_FOUND

FWHE_HAVE:
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    PUSH R7
    CALL FLOW_RAW_CLASS_AT
    POP R7
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x02
    JZ R3, FWHE_WHILE
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x03
    JZ R3, FWHE_END
    JMP FWHE_NEXT

FWHE_WHILE:
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    PUSH R1
    PUSH R2
    LOAD SCAN_PTR_H, R0
    PUSH R0
    LOAD SCAN_PTR_L, R0
    PUSH R0
    PUSH R7
    CALL FLOW_WHILE_HAS_ENDWHILE
    POP R7
    STORE R0, TMPH
    POP R0
    STORE R0, SCAN_PTR_L
    POP R0
    STORE R0, SCAN_PTR_H
    POP R2
    POP R1
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    LOAD TMPH, R0
    CMP R0, #0x01
    JZ R0, FWHE_NEST
    CMP R7, #0x00
    JZ R7, FWHE_NOT_FOUND
    JMP FWHE_NEXT

FWHE_NEST:
    INC R7
    JMP FWHE_NEXT

FWHE_END:
    CMP R7, #0x00
    JZ R7, FWHE_FOUND
    DEC R7

FWHE_NEXT:
    CALL FLOW_SCAN_ADVANCE
    JMP FWHE_LOOP

FWHE_FOUND:
    SET #0x01, R0
    RET

FWHE_NOT_FOUND:
    SET #0x00, R0
    RET

; FLOW_FIND_MATCHING_ENDWHILE
;   Input : R1:R2 = WHILE opener record
;   Output: R0 = 1 found and R1:R2 = matching ENDWHILE record, else R0 = 0
FLOW_FIND_MATCHING_ENDWHILE:
    CALL PROG_NEXT_PTR
    STORE R1, SCAN_PTR_H
    STORE R2, SCAN_PTR_L
    SET #0x00, R7
FFE_LOOP:
    LOAD SCAN_PTR_H, R1
    LOAD SCAN_PTR_L, R2
    LOAD PROG_END_H, R3
    LOAD PROG_END_L, R4
    SET #0x00, R5
    ADDR R1, R5
    CMPR R5, R3
    JNZ R5, FFE_HAVE
    SET #0x00, R5
    ADDR R2, R5
    CMPR R5, R4
    JZ R5, FFE_NOT_FOUND

FFE_HAVE:
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    PUSH R7
    CALL FLOW_RAW_CLASS_AT
    POP R7
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x02
    JZ R3, FFE_WHILE
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x03
    JZ R3, FFE_END
    JMP FFE_NEXT

FFE_WHILE:
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    PUSH R1
    PUSH R2
    LOAD SCAN_PTR_H, R0
    PUSH R0
    LOAD SCAN_PTR_L, R0
    PUSH R0
    PUSH R7
    CALL FLOW_WHILE_HAS_ENDWHILE
    POP R7
    STORE R0, TMPH
    POP R0
    STORE R0, SCAN_PTR_L
    POP R0
    STORE R0, SCAN_PTR_H
    POP R2
    POP R1
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    LOAD TMPH, R0
    CMP R0, #0x01
    JZ R0, FFE_NEST
    JMP FFE_NEXT

FFE_NEST:
    INC R7
    JMP FFE_NEXT
FFE_END:
    CMP R7, #0x00
    JZ R7, FFE_FOUND
    DEC R7
FFE_NEXT:
    CALL FLOW_SCAN_ADVANCE
    JMP FFE_LOOP
FFE_FOUND:
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    SET #0x01, R0
    RET
FFE_NOT_FOUND:
    SET #0x00, R0
    RET

; FLOW_FIND_MATCHING_DO
;   Input : R1:R2 = DO...WHILE terminator record
;   Output: R0 = 1 found and R1:R2 = matching DO record, else R0 = 0
FLOW_FIND_MATCHING_DO:
    STORE R1, MATCH_PTR_H
    STORE R2, MATCH_PTR_L
    SET #0x00, R0
    STORE R0, MATCH_SP
    SET #0x40, R0
    STORE R0, SCAN_PTR_H
    SET #0x00, R0
    STORE R0, SCAN_PTR_L
FFD_LOOP:
    LOAD SCAN_PTR_H, R1
    LOAD SCAN_PTR_L, R2
    LOAD PROG_END_H, R3
    LOAD PROG_END_L, R4
    SET #0x00, R5
    ADDR R1, R5
    CMPR R5, R3
    JNZ R5, FFD_HAVE
    SET #0x00, R5
    ADDR R2, R5
    CMPR R5, R4
    JZ R5, FFD_NOT_FOUND

FFD_HAVE:
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    CALL FLOW_RAW_CLASS_AT
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x01
    JZ R3, FFD_PUSH
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x02
    JZ R3, FFD_WHILE
    JMP FFD_STEP

FFD_PUSH:
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    CALL FLOW_MATCH_PUSH_PTR
    JMP FFD_STEP

FFD_WHILE:
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    PUSH R1
    PUSH R2
    LOAD SCAN_PTR_H, R0
    PUSH R0
    LOAD SCAN_PTR_L, R0
    PUSH R0
    CALL FLOW_WHILE_HAS_ENDWHILE
    STORE R0, TMPH
    POP R0
    STORE R0, SCAN_PTR_L
    POP R0
    STORE R0, SCAN_PTR_H
    POP R2
    POP R1
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    LOAD TMPH, R0
    CMP R0, #0x01
    JZ R0, FFD_STEP
    JMP FFD_TERM

FFD_TERM:
    LOAD TMP_PTR_H, R3
    LOAD TMP_PTR_L, R4
    LOAD MATCH_PTR_H, R1
    LOAD MATCH_PTR_L, R2
    SET #0x00, R5
    ADDR R3, R5
    CMPR R5, R1
    JNZ R5, FFD_POP_ONLY
    SET #0x00, R5
    ADDR R4, R5
    CMPR R5, R2
    JZ R5, FFD_TARGET

FFD_POP_ONLY:
    CALL FLOW_MATCH_POP_PTR
    JMP FFD_STEP

FFD_TARGET:
    CALL FLOW_MATCH_TOP_PTR
    CMP R0, #0x01
    JNZ R0, FFD_NOT_FOUND
    SET #0x01, R0
    RET

FFD_STEP:
    CALL FLOW_SCAN_ADVANCE
    JMP FFD_LOOP
FFD_NOT_FOUND:
    SET #0x00, R0
    RET

; FLOW_FIND_MATCHING_WHILE
;   Input : R1:R2 = ENDWHILE record
;   Output: R0 = 1 found and R1:R2 = matching WHILE opener, else R0 = 0
FLOW_FIND_MATCHING_WHILE:
    STORE R1, MATCH_PTR_H
    STORE R2, MATCH_PTR_L
    SET #0x00, R0
    STORE R0, MATCH_SP
    SET #0x40, R0
    STORE R0, SCAN_PTR_H
    SET #0x00, R0
    STORE R0, SCAN_PTR_L
FFW_LOOP:
    LOAD SCAN_PTR_H, R1
    LOAD SCAN_PTR_L, R2
    LOAD PROG_END_H, R3
    LOAD PROG_END_L, R4
    SET #0x00, R5
    ADDR R1, R5
    CMPR R5, R3
    JNZ R5, FFW_HAVE
    SET #0x00, R5
    ADDR R2, R5
    CMPR R5, R4
    JZ R5, FFW_NOT_FOUND

FFW_HAVE:
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    CALL FLOW_RAW_CLASS_AT
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x02
    JZ R3, FFW_WHILE
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #0x03
    JZ R3, FFW_END
    JMP FFW_STEP

FFW_WHILE:
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    PUSH R1
    PUSH R2
    LOAD SCAN_PTR_H, R0
    PUSH R0
    LOAD SCAN_PTR_L, R0
    PUSH R0
    CALL FLOW_WHILE_HAS_ENDWHILE
    STORE R0, TMPH
    POP R0
    STORE R0, SCAN_PTR_L
    POP R0
    STORE R0, SCAN_PTR_H
    POP R2
    POP R1
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    LOAD TMPH, R0
    CMP R0, #0x01
    JNZ R0, FFW_STEP
    CALL FLOW_MATCH_PUSH_PTR
    JMP FFW_STEP

FFW_END:
    LOAD TMP_PTR_H, R3
    LOAD TMP_PTR_L, R4
    LOAD MATCH_PTR_H, R1
    LOAD MATCH_PTR_L, R2
    SET #0x00, R5
    ADDR R3, R5
    CMPR R5, R1
    JNZ R5, FFW_POP_ONLY
    SET #0x00, R5
    ADDR R4, R5
    CMPR R5, R2
    JZ R5, FFW_TARGET

FFW_POP_ONLY:
    CALL FLOW_MATCH_POP_PTR
    JMP FFW_STEP

FFW_TARGET:
    CALL FLOW_MATCH_TOP_PTR
    CMP R0, #0x01
    JNZ R0, FFW_NOT_FOUND
    SET #0x01, R0
    RET

FFW_STEP:
    CALL FLOW_SCAN_ADVANCE
    JMP FFW_LOOP
FFW_NOT_FOUND:
    SET #0x00, R0
    RET

; ------------------------------------------------------------
; Local helpers
; ------------------------------------------------------------
FLOW_SYNTAX:
    CALL PRINT_SYNTAX_ERROR
    RET

FLOW_UNDEF:
    CALL PRINT_UNDEF_LINE
    RET
