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
;   - basic_state.s8.asm   (RUNNING, RUN_INDEX, GOSUB_SP, FOR_SP, JUMPED, etc.)
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

    ; parse line number and find index
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

    ; push return index (RUN_INDEX+1) to 0x6E00 + sp
    LOAD GOSUB_SP, R0
    ; CMP is destructive on Sophia8, so compare a scratch copy.
    SET #0x00, R3
    ADDR R0, R3
    CMP R3, #16
    JZ R3, FLOW_SYNTAX
    SET #0x6E, R1
    SET #0x00, R2
    ADDR R0, R2
    LOAD RUN_INDEX, R7
    INC R7
    STORER R7, R1, R2
    INC R0
    STORE R0, GOSUB_SP

    ; jump
    STORE R4, RUN_INDEX
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
    SET #0x6E, R1
    SET #0x00, R2
    ADDR R0, R2
    LOADR R7, R1, R2
    STORE R7, RUN_INDEX
    SET #0x01, R0
    STORE R0, JUMPED
    RET

; ------------------------------------------------------------
; CMD_FOR: only valid while RUNNING (program execution)
; Stack record layout at 0x6E20 + idx*8:
;   +0..1 var ptr (H,L)
;   +2..3 end value (H,L)
;   +4..5 step value (H,L)
;   +6    return index (RUN_INDEX+1)
;   +7    unused
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
    ; return index = RUN_INDEX+1
    LOAD RUN_INDEX, R7
    INC R7
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
    ; ret index -> DIVL
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
    LOAD DIVL, R7
    STORE R7, RUN_INDEX
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

    LOAD RUN_INDEX, R4
    CALL FLOW_CLASS_AT
    SET #0x00, R1
    ADDR R0, R1
    CMP R1, #0x02
    JZ R1, FLOW_WHILE_OPEN
    SET #0x00, R1
    ADDR R0, R1
    CMP R1, #0x03
    JZ R1, FLOW_WHILE_CLOSE
    JMP FLOW_SYNTAX

FLOW_WHILE_OPEN:
    CALL EVAL_EXPR
    CMP R6, #0x00
    JNZ R6, FLOW_WOPEN_TRUE
    CMP R7, #0x00
    JNZ R7, FLOW_WOPEN_TRUE

    LOAD RUN_INDEX, R4
    CALL FLOW_FIND_MATCHING_ENDWHILE
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    STORE R4, RUN_INDEX
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
    LOAD RUN_INDEX, R4
    CALL FLOW_FIND_MATCHING_DO
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    STORE R4, RUN_INDEX
    RET

CMD_ENDWHILE:
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x00
    JNZ R0, FLOW_SYNTAX

    LOAD RUN_INDEX, R4
    CALL FLOW_FIND_MATCHING_WHILE
    CMP R0, #0x01
    JNZ R0, FLOW_SYNTAX
    STORE R4, RUN_INDEX
    SET #0x01, R0
    STORE R0, JUMPED
    RET

; ------------------------------------------------------------
; Flow block helpers for DO/WHILE/ENDWHILE
; ------------------------------------------------------------
; FLOW_GET_LINE_PTR
;   Input : R4 = program line index
;   Output: R0 = line length byte, R1:R2 = pointer to line text
FLOW_GET_LINE_PTR:
    SET #0x40, R1
    SET #0x00, R2
    SET #0x00, R6
    ADDR R4, R6
    CALL ADD_ENTRY_OFFSET

    ; skip line number
    INC R2
    JNZ R2, FGLP1
    INC R1
FGLP1:
    INC R2
    JNZ R2, FGLP2
    INC R1
FGLP2:
    LOADR R0, R1, R2
    ; move to text start
    INC R2
    JNZ R2, FGLP3
    INC R1
FGLP3:
    RET

; FLOW_RAW_CLASS_AT
;   Input : R4 = program line index
;   Output: R0 = 0 other, 1 DO, 2 WHILE, 3 ENDWHILE
FLOW_RAW_CLASS_AT:
    LOAD CURPTR_H, R5
    LOAD CURPTR_L, R6
    PUSH R5
    PUSH R6

    CALL FLOW_GET_LINE_PTR
    CMP R0, #0x00
    JZ R0, FRCA_NONE

    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    PUSH R4
    CALL GETTOKEN
    POP R4

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

; FLOW_CLASS_AT
;   Input : R4 = program line index
;   Output: R0 = 0 other, 1 DO opener, 2 WHILE opener,
;                3 DO...WHILE terminator, 4 ENDWHILE
FLOW_CLASS_AT:
    STORE R4, MATCH_INDEX
    SET #0x00, R0
    STORE R0, CLS_SP
    SET #0x00, R5
FCA_SCAN_LOOP:
    LOAD MATCH_INDEX, R0
    ; reached target yet?
    SET #0x00, R1
    ADDR R5, R1
    CMPR R1, R0
    JZ R1, FCA_DECIDE_TARGET

    SET #0x00, R4
    ADDR R5, R4
    PUSH R5
    CALL FLOW_RAW_CLASS_AT
    SET #0x00, R2
    ADDR R0, R2
    POP R5
    SET #0x00, R1
    ADDR R2, R1
    CMP R1, #0x01
    JZ R1, FCA_PUSH_DO
    SET #0x00, R1
    ADDR R2, R1
    CMP R1, #0x02
    JZ R1, FCA_HANDLE_WHILE
    SET #0x00, R1
    ADDR R2, R1
    CMP R1, #0x03
    JZ R1, FCA_HANDLE_ENDWHILE
    JMP FCA_NEXT

FCA_PUSH_DO:
    SET #0x01, R0
    CALL FLOW_PUSH_CLASS
    JMP FCA_NEXT

FCA_HANDLE_WHILE:
    CALL FLOW_TOP_CLASS
    CMP R0, #0x01
    JNZ R0, FCA_PUSH_WHILE
    CALL FLOW_POP_CLASS
    JMP FCA_NEXT
FCA_PUSH_WHILE:
    SET #0x02, R0
    CALL FLOW_PUSH_CLASS
    JMP FCA_NEXT

FCA_HANDLE_ENDWHILE:
    CALL FLOW_TOP_CLASS
    CMP R0, #0x02
    JNZ R0, FCA_NEXT
    CALL FLOW_POP_CLASS

FCA_NEXT:
    INC R5
    JMP FCA_SCAN_LOOP

FCA_DECIDE_TARGET:
    LOAD MATCH_INDEX, R4
    CALL FLOW_RAW_CLASS_AT
    SET #0x00, R1
    ADDR R0, R1
    CMP R1, #0x01
    JZ R1, FCA_RET_DO
    SET #0x00, R1
    ADDR R0, R1
    CMP R1, #0x03
    JZ R1, FCA_RET_ENDWHILE
    SET #0x00, R1
    ADDR R0, R1
    CMP R1, #0x02
    JZ R1, FCA_DECIDE_WHILE
    RET

FCA_RET_DO:
    SET #0x01, R0
    RET
FCA_RET_ENDWHILE:
    SET #0x04, R0
    RET
FCA_DECIDE_WHILE:
    CALL FLOW_TOP_CLASS
    CMP R0, #0x01
    JZ R0, FCA_RET_DOWHILE
    SET #0x02, R0
    RET
FCA_RET_DOWHILE:
    SET #0x03, R0
    RET

; FLOW_FIND_MATCHING_ENDWHILE
;   Input : R4 = WHILE opener index
;   Output: R0 = 1 found and R4 = matching ENDWHILE index, else R0 = 0
FLOW_FIND_MATCHING_ENDWHILE:
    LOAD LINECOUNT, R6
    SET #0x00, R5
    INC R4
    ADDR R4, R5
    SET #0x00, R7
FFE_LOOP:
    ; if scan index == linecount => not found
    SET #0x00, R0
    ADDR R5, R0
    CMPR R0, R6
    JZ R0, FFE_NOT_FOUND

    SET #0x00, R4
    ADDR R5, R4
    PUSH R5
    PUSH R6
    PUSH R7
    CALL FLOW_CLASS_AT
    SET #0x00, R1
    ADDR R0, R1
    POP R7
    POP R6
    POP R5
    SET #0x00, R0
    ADDR R1, R0
    CMP R0, #0x02
    JZ R0, FFE_NEST
    SET #0x00, R0
    ADDR R1, R0
    CMP R0, #0x04
    JZ R0, FFE_END
    JMP FFE_NEXT
FFE_NEST:
    INC R7
    JMP FFE_NEXT
FFE_END:
    CMP R7, #0x00
    JZ R7, FFE_FOUND
    DEC R7
FFE_NEXT:
    INC R5
    JMP FFE_LOOP
FFE_FOUND:
    SET #0x00, R4
    ADDR R5, R4
    SET #0x01, R0
    RET
FFE_NOT_FOUND:
    SET #0x00, R0
    RET

; FLOW_FIND_MATCHING_DO
;   Input : R4 = DO...WHILE terminator index
;   Output: R0 = 1 found and R4 = matching DO index, else R0 = 0
FLOW_FIND_MATCHING_DO:
    CMP R4, #0x00
    JZ R4, FFD_NOT_FOUND
    SET #0x00, R5
    ADDR R4, R5
    DEC R5
    SET #0x00, R7
FFD_LOOP:
    SET #0x00, R4
    ADDR R5, R4
    PUSH R5
    PUSH R7
    CALL FLOW_CLASS_AT
    SET #0x00, R1
    ADDR R0, R1
    POP R7
    POP R5
    SET #0x00, R0
    ADDR R1, R0
    CMP R0, #0x03
    JZ R0, FFD_NEST
    SET #0x00, R0
    ADDR R1, R0
    CMP R0, #0x01
    JZ R0, FFD_DO
    JMP FFD_STEP
FFD_NEST:
    INC R7
    JMP FFD_STEP
FFD_DO:
    CMP R7, #0x00
    JZ R7, FFD_FOUND
    DEC R7
FFD_STEP:
    CMP R5, #0x00
    JZ R5, FFD_NOT_FOUND
    DEC R5
    JMP FFD_LOOP
FFD_FOUND:
    SET #0x00, R4
    ADDR R5, R4
    SET #0x01, R0
    RET
FFD_NOT_FOUND:
    SET #0x00, R0
    RET

; FLOW_FIND_MATCHING_WHILE
;   Input : R4 = ENDWHILE index
;   Output: R0 = 1 found and R4 = matching WHILE opener index, else R0 = 0
FLOW_FIND_MATCHING_WHILE:
    CMP R4, #0x00
    JZ R4, FFW_NOT_FOUND
    SET #0x00, R5
    ADDR R4, R5
    DEC R5
    SET #0x00, R7
FFW_LOOP:
    SET #0x00, R4
    ADDR R5, R4
    PUSH R5
    PUSH R7
    CALL FLOW_CLASS_AT
    SET #0x00, R1
    ADDR R0, R1
    POP R7
    POP R5
    SET #0x00, R0
    ADDR R1, R0
    CMP R0, #0x04
    JZ R0, FFW_NEST
    SET #0x00, R0
    ADDR R1, R0
    CMP R0, #0x02
    JZ R0, FFW_WHILE
    JMP FFW_STEP
FFW_NEST:
    INC R7
    JMP FFW_STEP
FFW_WHILE:
    CMP R7, #0x00
    JZ R7, FFW_FOUND
    DEC R7
FFW_STEP:
    CMP R5, #0x00
    JZ R5, FFW_NOT_FOUND
    DEC R5
    JMP FFW_LOOP
FFW_FOUND:
    SET #0x00, R4
    ADDR R5, R4
    SET #0x01, R0
    RET
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
