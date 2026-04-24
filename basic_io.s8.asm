; ---------------------------------------------------------------------------
; basic_io.s8.asm
;
; Sophia BASIC v1 - PRINT / INPUT routines.
;
; Purpose:
;   Keep basic_stmt.s8.asm focused on statement dispatch and core command parsing.
;   All I/O related BASIC commands and helpers are in this module.
;
; Provides:
;   CMD_PRINT
;   CMD_INPUT
;   DO_PRINT
;
; Dependencies:
;   - basic_state.s8.asm (CURPTR_*, TOKENBUF, IDBUF, runtime variables)
;   - basic_expr.s8.asm  (PARSE_IDENT, EVAL_EXPR, PARSE_INT16)
;   - basic_vars.s8.asm  (VAR_FIND, VAR_FIND_OR_CREATE, STORE_VAR_INT)
;   - basic_errors.s8.asm (PRINT_SYNTAX_ERROR)
;   - kernel helpers: PUTC, PUTS, PUTDEC16S, READLINE_ECHO
;
; Notes:
;   This is a direct extraction from the original BASIC core. Any functional
;   changes should be done in small steps with tests.
; ---------------------------------------------------------------------------

CMD_PRINT:
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    CALL DO_PRINT
    RET

CMD_INPUT:
    ; INPUT <var>
    ; Dedicated input path (does not reuse the main CLI line buffer for strings).
    ; Save current CURPTR so INPUT can't corrupt parser state.
    LOAD CURPTR_H, R0
    STORE R0, SAVCUR_H
    LOAD CURPTR_L, R0
    STORE R0, SAVCUR_L

    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    CALL PARSE_IDENT
    CMP R0, #0x01
    JNZ R0, IN_SYNTAX
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL VAR_FIND_OR_CREATE
    CMP R0, #0x01
    JNZ R0, IN_SYNTAX
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L

    ; prompt "? "
    SET #0x3F, R0
    CALL PUTC
    SET #0x20, R0
    CALL PUTC

    ; Branch by variable type.
    LOAD IDTYPE, R0
    CMP R0, #0x01
    JZ R0, IN_READ_STR

IN_READ_NUM:
    ; numeric input: read line into 0x6E00 and parse signed integer
    SET #0x6E, R1
    SET #0x00, R2
    SET #96, R3
    CALL READLINE_ECHO

    ; echo newline after input line
    SET #0x02, R1
    SET #0x44, R2
    CALL PUTS

    SET #0x6E, R0
    STORE R0, CURPTR_H
    SET #0x00, R0
    STORE R0, CURPTR_L
    CALL SKIPSP_CUR
    CALL PARSE_INT16
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    CALL STORE_VAR_INT
    JMP IN_DONE

IN_READ_STR:
    ; string input: read directly into string heap at STRFREE
    LOAD STRFREE_H, R6
    LOAD STRFREE_L, R7
    STORE R6, TMPH          ; start pointer high
    STORE R7, TMPL          ; start pointer low

    ; R1:R2 = STRFREE, max 96 incl NUL
    SET #0x00, R1
    ADDR R6, R1
    SET #0x00, R2
    ADDR R7, R2
    SET #96, R3
    CALL READLINE_ECHO

    ; echo newline after input line
    SET #0x02, R1
    SET #0x44, R2
    CALL PUTS

    ; stash input length from READLINE_ECHO
    STORE R4, IDLEN

    ; advance STRFREE by (len + 1)
    LOAD TMPH, R1
    LOAD TMPL, R2
    LOAD IDLEN, R0
    ADDR R0, R2
    JNC IN_ADV1
    INC R1
IN_ADV1:
    ADD #1, R2
    JNC IN_ADV2
    INC R1
IN_ADV2:
    STORE R1, STRFREE_H
    STORE R2, STRFREE_L

    ; store ptr+len into entry (offset 12..14)
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    PUSH R1
    PUSH R2
    ADD #12, R2
    JNC IN_P1
    INC R1
IN_P1:
    LOAD TMPH, R0
    STORER R0, R1, R2
    INC R2
    JNZ R2, IN_P2
    INC R1
IN_P2:
    LOAD TMPL, R0
    STORER R0, R1, R2
    INC R2
    JNZ R2, IN_P3
    INC R1
IN_P3:
    LOAD IDLEN, R0
    STORER R0, R1, R2
    POP R2
    POP R1

IN_DONE:
    LOAD SAVCUR_H, R0
    STORE R0, CURPTR_H
    LOAD SAVCUR_L, R0
    STORE R0, CURPTR_L
    RET

IN_SYNTAX:
    CALL PRINT_SYNTAX_ERROR
    JMP IN_DONE

; ---------------------------------------------------------------------------
; DO_PRINT: prints string literal, string variable, or numeric expression
; ---------------------------------------------------------------------------
DO_PRINT:
    ; Try full string expression (functions, literals, vars, concatenation).
    ; STR_PARSE_EXPR_CONCAT operates on CURPTR_*.
    PUSH R1
    PUSH R2
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL STR_PARSE_EXPR_CONCAT     ; R6:R7 ptr, R5 len, R0 success
    CMP R0, #0x01
    JNZ R0, DP_STR_EXPR_FAIL

    ; discard saved original pointer (we keep CURPTR advanced by the parser)
    POP R2
    POP R1

    ; success: print exactly R5 bytes from R6:R7
DP_STR_EXPR_LOOP:
    JZ R5, DP_NL
    LOADR R0, R6, R7
    CALL PUTC
    INC R7
    JNZ R7, DP_STR_EXPR_P
    INC R6
DP_STR_EXPR_P:
    DEC R5
    JMP DP_STR_EXPR_LOOP

DP_STR_EXPR_FAIL:
    ; restore original pointer
    POP R2
    POP R1

    ; if starts with identifier, try string var first
    PUSH R1
    PUSH R2
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL PARSE_IDENT
    CMP R0, #0x01
    JNZ R0, DP_EXPR

    ; parsed ident, check if string
    LOAD IDTYPE, R0
    CMP R0, #0x01
    JNZ R0, DP_EXPR_REW

    ; update CURPTR from PARSE_IDENT advance
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL VAR_FIND
    CMP R0, #0x01
    JNZ R0, DP_EXPR_REW

    ; success: VAR_FIND returned entry pointer in R1:R2
    ; We still have the saved parse pointer on the stack (from PUSH R1/PUSH R2 earlier).
    ; Discard it now, but preserve entry pointer via TMP_PTR.
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    POP R2
    POP R1
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2

    ; print string from entry (ptr at 12/13)
    PUSH R1
    PUSH R2
    ADD #12, R2
    JNC DPS1
    INC R1
DPS1:
    LOADR R3, R1, R2
    INC R2
    JNZ R2, DPS2
    INC R1
DPS2:
    LOADR R4, R1, R2
    INC R2
    JNZ R2, DPS2B
    INC R1
DPS2B:
    LOADR R5, R1, R2        ; length byte
    POP R2
    POP R1

    ; PUTC clobbers R3 (kernel convention). Do not keep the string pointer
    ; in R3 across output. Use R6:R7 instead.
    SET #0x00, R6
    ADDR R3, R6             ; ptr high
    SET #0x00, R7
    ADDR R4, R7             ; ptr low

    ; print exactly LEN bytes (more robust than relying on NUL)
DPS_LOOP:
    JZ R5, DP_NL
    LOADR R0, R6, R7
    JZ R0, DP_NL
    CALL PUTC
    INC R7
    JNZ R7, DPS_P
    INC R6
DPS_P:
    DEC R5
    JMP DPS_LOOP

DP_EXPR_REW:
    ; restore original pointer
    POP R2
    POP R1
    JMP DP_EXPR2

DP_EXPR:
    ; failed parse ident => restore
    POP R2
    POP R1
DP_EXPR2:
    ; numeric expression
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL EVAL_EXPR
    CALL PUTDEC16S
    JMP DP_NL

DP_STR:
    INC R2
    JNZ R2, DS1
    INC R1
DS1:
DS_LOOP:
    LOADR R0, R1, R2
    ; IMPORTANT: Sophia8 CMP is destructive (it subtracts into the left operand).
    ; We must not CMP directly on R0 because we still need the original byte
    ; for output. Compare on a temp copy instead.
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x00
    JZ R7, DP_STR_DONE_NUL
    SET #0x00, R7
    ADDR R0, R7
    CMP R7, #0x22
    JZ R7, DP_STR_DONE_QUOTE
    CALL PUTC
    INC R2
    JNZ R2, DS_LOOP
    INC R1
    JMP DS_LOOP

DP_STR_DONE_NUL:
    ; store updated CURPTR (at NUL) so the statement parser can continue
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    JMP DP_NL

DP_STR_DONE_QUOTE:
    ; consume closing quote and store CURPTR
    INC R2
    JNZ R2, DSQ1
    INC R1
DSQ1:
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    JMP DP_NL

DP_NL:
    SET #0x0A, R0
    CALL PUTC
    RET
