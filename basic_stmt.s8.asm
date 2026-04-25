; ---------------------------------------------------------------------------
; basic_stmt.s8.asm
;
; Sophia BASIC v1 - statement dispatcher and built-in commands.
;
; Purpose:
;   Keeps sophia_basic_v1.s8.asm focused on the REPL loop and RUN loop, while
;   statement parsing/dispatch and the built-in command handlers live here.
;
; Provides:
;   EXEC_STMT
;   CMD_* handlers (NEW, LIST, RUN, LET, assignment dispatch, REM, GOTO,
;   POKE, RANDOMIZE, IF, END/STOP)
;
; Dependencies:
;   - basic_state.s8.asm (CURPTR_*, TOKENBUF, IDBUF, stacks/state)
;   - basic_expr.s8.asm  (PARSE_IDENT, EVAL_EXPR, VAR_* helpers, etc.)
;   - basic_progstore.s8.asm (LIST_ALL)
;   - basic_io.s8.asm (CMD_PRINT, CMD_INPUT, DO_PRINT)
;   - basic_flow.s8.asm (CMD_GOSUB, CMD_RETURN, CMD_FOR, CMD_NEXT)
;   - kernel helpers: PUTS, PUTC, STREQ, PUTDEC16S, etc.
;
; Notes:
;   This file is a direct extraction from the original BASIC core to reduce
;   churn and keep behavior identical. Functional changes should be made in
;   small steps with tests.
; ---------------------------------------------------------------------------

EXEC_STMT:
    ; save token start for potential assignment
    LOAD CURPTR_H, R0
    STORE R0, TOKSTART_H
    LOAD CURPTR_L, R0
    STORE R0, TOKSTART_L

    PUSH R4
    CALL GETTOKEN
    POP R4

    ; Apostrophe (') comment shorthand
    ; If the first token is a single quote, treat it like REM and ignore
    ; the rest of the current line.
    SET #0x68, R1
    SET #0x80, R2
    LOADR R0, R1, R2
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x27      ; '\''
    JZ R7, CMD_REM

    ; NEW
    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0x80, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, CMD_NEW

    ; LIST
    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0x88, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, CMD_LIST

    ; RUN
    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0x90, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, CMD_RUN

    ; PRINT
    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0x98, R7
    PUSH R4
    SET #0x00, R4
    ADDR R7, R4
    CALL STREQ
    POP R4
    CMP R0, #0x01
    JZ R0, CMD_PRINT

    ; GOTO
    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0xA0, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, CMD_GOTO

; GOSUB
SET #0x68, R1
    SET #0x80, R2
SET #0x02, R3
SET #0xD0, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_GOSUB

; RETURN
SET #0x68, R1
    SET #0x80, R2
SET #0x02, R3
SET #0xD8, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_RETURN

; FOR
SET #0x68, R1
    SET #0x80, R2
SET #0x02, R3
SET #0xE0, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_FOR

; NEXT
SET #0x68, R1
    SET #0x80, R2
SET #0x02, R3
SET #0xF8, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_NEXT

; INPUT
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x00, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_INPUT

; POKE
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x08, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_POKE

; RANDOMIZE
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x10, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_RANDOMIZE

; REM
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x38, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_REM


; Phase 14: DATA / READ / RESTORE
; DATA
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x48, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_DATA

; READ
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x50, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_READ

; RESTORE
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x58, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_RESTORE

; DO
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x68, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_DO

; WHILE
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x70, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_WHILE

; ENDWHILE
SET #0x68, R1
    SET #0x80, R2
SET #0x03, R3
SET #0x78, R4
CALL STREQ
CMP R0, #0x01
JZ R0, CMD_ENDWHILE

    ; IF
    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0xA8, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, CMD_IF

    ; END
    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0xB8, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, CMD_END

    ; STOP
    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0xC0, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, CMD_END

    ; LET
    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0xC8, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, CMD_LET

    ; DIM
    SET #0x68, R1
    SET #0x80, R2
    SET #0x03, R3
    SET #0x40, R4
    CALL STREQ
    CMP R0, #0x01
    JZ R0, CMD_DIM

    ; not a keyword: try assignment
    JMP CMD_ASSIGN_DISPATCH

    ; unknown -> syntax
    CALL PRINT_SYNTAX_ERROR
    RET

CMD_NEW:
    CALL PROG_RESET
    ; init variables + string heap
    CALL INIT_VARS
    RET
CMD_LIST:
    CALL LIST_ALL
    RET
CMD_RUN:
    CALL RUN_PROG
    RET


CMD_REM:
    ; Ignore the rest of the current line (BASIC comment)
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
CR_SKIP:
    LOADR R0, R1, R2
    CMP R0, #0x00
    JZ R0, CR_DONE
    INC R2
    JNZ R2, CR_SKIP
    INC R1
    JMP CR_SKIP
CR_DONE:
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    RET


; CMD_DATA / CMD_READ / CMD_RESTORE extracted to basic_data_cmd.s8.asm

; CMD_LET/CMD_ASSIGN* moved to basic_assign.s8.asm

CMD_GOTO:
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
    JNZ R0, GOTO_UNDEF
    STORE R1, RUN_PTR_H
    STORE R2, RUN_PTR_L
    SET #0x01, R0
    STORE R0, JUMPED
    RET
GOTO_UNDEF:
    CALL PRINT_UNDEF_LINE
    RET

; CMD_INPUT moved to basic_io.s8.asm
CMD_POKE:

    ; POKE addr, value
    CALL SKIPSP_CUR
    CALL EVAL_EXPR
    ; addr in R6:R7 -> save on stack (TMPH/TMPL are also used by expression engine)
    PUSH R6
    PUSH R7
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x2C
    JNZ R0, IF_SYNTAX
    CALL GETCHAR_CUR
    CALL EVAL_EXPR
    ; value in R6:R7
    POP R2
    POP R1
    SET #0x00, R0
    ADDR R7, R0
    STORER R0, R1, R2
    RET

CMD_RANDOMIZE:
    ; RANDOMIZE [seed]
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x00
    JZ R0, RZ_DEF
    ; parse signed integer seed (no full expression)
    CALL PARSE_INT16
    STORE R6, RNG_SEED_H
    STORE R7, RNG_SEED_L
    RET
RZ_DEF:
    SET #0x00, R0
    STORE R0, RNG_SEED_H
    SET #0x01, R0
    STORE R0, RNG_SEED_L
    RET

; Keep 0x9600/0x9601 free for BASIC POKE tests (screen/MMIO scratch).
.org 0xA000

CMD_IF:

    ; IF expr THEN <line> | IF expr THEN <stmt>
    ; - In RUN mode, THEN <line> performs a jump (like GOTO).
    ; - In immediate mode, THEN <stmt> executes the statement; THEN <line> is a syntax error.

    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    ; evaluate condition
    CALL EVAL_EXPR
    ; result in R6:R7 (non-zero => true)
    CMP R6, #0x00
    JNZ R6, IF_TRUE
    CMP R7, #0x00
    JZ R7, IF_FALSE

IF_TRUE:
    ; expect THEN
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    PUSH R4
    CALL GETTOKEN
    POP R4

    SET #0x68, R1
    SET #0x80, R2
    SET #0x02, R3
    SET #0xB0, R4
    CALL STREQ
    CMP R0, #0x01
    JNZ R0, IF_SYNTAX

    ; Decide: THEN <line> or THEN <stmt>
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    ; digit => line number
    CALL ISDIGIT
    CMP R0, #0x01
    JZ R0, IF_THEN_LINE

    ; otherwise execute the statement tail immediately
    CALL EXEC_STMT

    ; Optional ELSE part is ignored when condition is true.
    ; We do not error on trailing ELSE to allow: IF 1 THEN PRINT 1 ELSE PRINT 2
    RET

IF_THEN_LINE:
    ; THEN <line> is only meaningful in RUN mode
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, IF_SYNTAX

    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL PARSE_U16_DEC
    STORE R6, TMP_LINENO_H
    STORE R7, TMP_LINENO_L
    CALL FIND_LINE
    CMP R0, #0x01
    JNZ R0, GOTO_UNDEF
    STORE R1, RUN_PTR_H
    STORE R2, RUN_PTR_L
    SET #0x01, R0
    STORE R0, JUMPED
    RET

IF_FALSE:
    ; Condition is false: if there is an ELSE clause on the same line,
    ; execute/jump to it.
    ;
    ; We scan the remainder of the line for token boundary "ELSE".
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL FIND_ELSE
    CMP R0, #0x01
    JNZ R0, IF_FALSE_DONE

    ; Move CURPTR to ELSE token and consume it.
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    PUSH R4
    CALL GETTOKEN
    POP R4

    ; token must be ELSE
    SET #0x68, R1
    SET #0x80, R2
    SET #0x03, R3
    SET #0x30, R4
    CALL STREQ
    CMP R0, #0x01
    JNZ R0, IF_SYNTAX

    ; After ELSE: either <line> (RUN mode only) or <stmt>
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    CALL ISDIGIT
    CMP R0, #0x01
    JZ R0, IF_ELSE_LINE

    CALL EXEC_STMT
    RET

IF_ELSE_LINE:
    LOAD RUNNING, R0
    CMP R0, #0x01
    JNZ R0, IF_SYNTAX

    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL PARSE_U16_DEC
    STORE R6, TMP_LINENO_H
    STORE R7, TMP_LINENO_L
    CALL FIND_LINE
    CMP R0, #0x01
    JNZ R0, GOTO_UNDEF
    STORE R1, RUN_PTR_H
    STORE R2, RUN_PTR_L
    SET #0x01, R0
    STORE R0, JUMPED
    RET

IF_FALSE_DONE:
    RET

; ---------------------------------------------------------------------------
; FIND_ELSE
;   Scan from R1:R2 for a token boundary "ELSE".
;   Input:  R1:R2 start pointer
;   Output: R0=1 and R1:R2 points to the 'E' of ELSE; R0=0 if not found.
;   Notes:
;     - Input line is already uppercased.
;     - Token boundary: preceding char is space/start and following is space/NUL.
; ---------------------------------------------------------------------------
FIND_ELSE:
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7

    ; prev_is_space = 1
    SET #0x01, R7

FE_LOOP:
    LOADR R0, R1, R2
    CMP R0, #0x00
    JZ R0, FE_NOT_FOUND

    ; if prev_is_space and c == 'E'
    CMP R7, #0x01
    JNZ R7, FE_UPDATE_PREV
    CMP R0, #0x45
    JNZ R0, FE_UPDATE_PREV

    ; check sequence E L S E
    ; t = ptr
    SET #0x00, R3
    ADDR R1, R3
    SET #0x00, R4
    ADDR R2, R4

    ; +1 must be 'L'
    INC R4
    JNZ R4, FE_C1
    INC R3
FE_C1:
    LOADR R5, R3, R4
    CMP R5, #0x4C
    JNZ R5, FE_UPDATE_PREV

    ; +2 must be 'S'
    INC R4
    JNZ R4, FE_C2
    INC R3
FE_C2:
    LOADR R5, R3, R4
    CMP R5, #0x53
    JNZ R5, FE_UPDATE_PREV

    ; +3 must be 'E'
    INC R4
    JNZ R4, FE_C3
    INC R3
FE_C3:
    LOADR R5, R3, R4
    CMP R5, #0x45
    JNZ R5, FE_UPDATE_PREV

    ; +4 must be space or NUL
    INC R4
    JNZ R4, FE_C4
    INC R3
FE_C4:
    LOADR R5, R3, R4
    CMP R5, #0x00
    JZ R5, FE_FOUND
    CMP R5, #0x20
    JZ R5, FE_FOUND
    JMP FE_UPDATE_PREV

FE_FOUND:
    SET #0x01, R0
    JMP FE_DONE

FE_UPDATE_PREV:
    ; prev_is_space = (c == ' ')
    CMP R0, #0x20
    JZ R0, FE_PREV1
    SET #0x00, R7
    JMP FE_ADV
FE_PREV1:
    SET #0x01, R7

FE_ADV:
    INC R2
    JNZ R2, FE_LOOP
    INC R1
    JMP FE_LOOP

FE_NOT_FOUND:
    SET #0x00, R0
FE_DONE:
    POP R7
    POP R6
    POP R5
    POP R4
    POP R3
    RET

IF_SYNTAX:
    CALL PRINT_SYNTAX_ERROR
    RET

CMD_END:
    SET #0x01, R0
    STORE R0, RUN_STOP
    RET

; DO_PRINT moved to basic_io.s8.asm

; ---------------------------------------------------------------------------
; EVAL_UINT8_EXPR: n([+-]n)* where n is uint8 decimal
; returns R0=value, advances CURPTR
; ---------------------------------------------------------------------------
