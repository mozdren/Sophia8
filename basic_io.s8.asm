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
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    SET #0x00, R0
    STORE R0, PRINT_SEP_KIND

CP_LOOP:
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x00
    JZ R0, CP_DONE
    CALL PEEKCHAR_CUR
    CMP R0, #0x3A
    JZ R0, CP_DONE
    CALL PEEKCHAR_CUR
    CMP R0, #0x27
    JZ R0, CP_DONE

    LOAD PRINT_SEP_KIND, R0
    CMP R0, #0x02
    JNZ R0, CP_ITEM
    SET #0x20, R0
    CALL PUTC

CP_ITEM:
    SET #0x00, R0
    STORE R0, PRINT_SEP_KIND
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL DO_PRINT_ITEM

    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x3B
    JZ R0, CP_SEMI
    CALL PEEKCHAR_CUR
    CMP R0, #0x2C
    JZ R0, CP_COMMA
    JMP CP_DONE

CP_SEMI:
    CALL GETCHAR_CUR
    SET #0x01, R0
    STORE R0, PRINT_SEP_KIND
    JMP CP_LOOP

CP_COMMA:
    CALL GETCHAR_CUR
    SET #0x02, R0
    STORE R0, PRINT_SEP_KIND
    JMP CP_LOOP

CP_DONE:
    LOAD PRINT_SEP_KIND, R0
    CMP R0, #0x00
    JNZ R0, CP_RET
    SET #0x0A, R0
    CALL PUTC
CP_RET:
    RET

CMD_INPUT:
    ; INPUT ["prompt"[;|,]] <var>[,<var>...]
    ; Dedicated input path (does not reuse the main CLI line buffer for strings).
    ; Save current CURPTR so INPUT can't corrupt parser state.
    LOAD CURPTR_H, R0
    STORE R0, SAVCUR_H
    LOAD CURPTR_L, R0
    STORE R0, SAVCUR_L
    SET #0x00, R0
    STORE R0, INPUT_VAR_COUNT

    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    ; Optional quoted prompt.
    CALL PEEKCHAR_CUR
    CMP R0, #0x22
    JNZ R0, IN_DEF_PROMPT
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL DO_PRINT_ITEM
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x3B
    JZ R0, IN_PROMPT_SEP
    CALL PEEKCHAR_CUR
    CMP R0, #0x2C
    JNZ R0, IN_SYNTAX
IN_PROMPT_SEP:
    CALL GETCHAR_CUR
    JMP IN_PARSE_VAR

IN_DEF_PROMPT:
    SET #0x3F, R0
    CALL PUTC
    SET #0x20, R0
    CALL PUTC

IN_PARSE_VAR:
    CALL INPUT_PARSE_VARLIST

    ; read full input line into 0x6E80 and assign fields
    SET #0x6E, R1
    SET #0x80, R2
    SET #96, R3
    CALL READLINE_ECHO

    ; echo newline after input line
    SET #0x02, R1
    SET #0x44, R2
    CALL PUTS

    SET #0x6E, R0
    STORE R0, CURPTR_H
    SET #0x80, R0
    STORE R0, CURPTR_L
    CALL INPUT_ASSIGN_FIELDS

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
; INPUT_PARSE_VARLIST
;   Parse <var>[,<var>...] from CURPTR into INPUT_VAR_* arrays.
; ---------------------------------------------------------------------------
INPUT_PARSE_VARLIST:
IPV_LOOP:
    CALL SKIPSP_CUR
    CALL PARSE_IDENT
    CMP R0, #0x01
    JNZ R0, IN_SYNTAX
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL VAR_FIND_OR_CREATE
    CMP R0, #0x01
    JNZ R0, IN_SYNTAX

    LOAD INPUT_VAR_COUNT, R6
    SET #0x00, R5
    ADDR R6, R5
    CMP R5, #0x08
    JZ R5, IN_SYNTAX

    LOAD INPUT_VAR_COUNT, R6
    SET #0x68, R3
    SET #0xE0, R4
    ADDR R6, R4
    STORER R1, R3, R4

    LOAD INPUT_VAR_COUNT, R6
    SET #0x68, R3
    SET #0xE8, R4
    ADDR R6, R4
    STORER R2, R3, R4

    LOAD INPUT_VAR_COUNT, R6
    SET #0x68, R3
    SET #0xF0, R4
    ADDR R6, R4
    LOAD IDTYPE, R5
    STORER R5, R3, R4

    LOAD INPUT_VAR_COUNT, R0
    INC R0
    STORE R0, INPUT_VAR_COUNT

    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x2C
    JZ R0, IPV_MORE
    RET

IPV_MORE:
    CALL GETCHAR_CUR
    JMP IPV_LOOP

; ---------------------------------------------------------------------------
; INPUT_ASSIGN_FIELDS
;   Assign one input line to the parsed INPUT_VAR_* list.
; ---------------------------------------------------------------------------
INPUT_ASSIGN_FIELDS:
    SET #0x00, R0
    STORE R0, INPUT_VAR_INDEX
IAF_LOOP:
    LOAD INPUT_VAR_INDEX, R6
    LOAD INPUT_VAR_COUNT, R0
    SET #0x00, R5
    ADDR R6, R5
    CMPR R5, R0
    JZ R5, IAF_DONE

    ; load current entry pointer into TMP_PTR
    LOAD INPUT_VAR_INDEX, R6
    SET #0x68, R3
    SET #0xE0, R4
    ADDR R6, R4
    LOADR R1, R3, R4
    STORE R1, TMP_PTR_H

    LOAD INPUT_VAR_INDEX, R6
    SET #0x68, R3
    SET #0xE8, R4
    ADDR R6, R4
    LOADR R2, R3, R4
    STORE R2, TMP_PTR_L

    ; dispatch by stored type
    LOAD INPUT_VAR_INDEX, R6
    SET #0x68, R3
    SET #0xF0, R4
    ADDR R6, R4
    LOADR R0, R3, R4
    CMP R0, #0x01
    JZ R0, IAF_STR

IAF_NUM:
    CALL SKIPSP_CUR
    CALL PARSE_INT16
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    CALL STORE_VAR_INT
    JMP IAF_POST

IAF_STR:
    CALL INPUT_PARSE_STR_FIELD
    CALL INPUT_STORE_STR_FIELD

IAF_POST:
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x2C
    JNZ R0, IAF_NEXT
    CALL GETCHAR_CUR

IAF_NEXT:
    LOAD INPUT_VAR_INDEX, R0
    INC R0
    STORE R0, INPUT_VAR_INDEX
    JMP IAF_LOOP

IAF_DONE:
    RET

; ---------------------------------------------------------------------------
; INPUT_PARSE_STR_FIELD
;   Parse one string field from CURPTR.
;   Output: TMPH:TMPL = source pointer, IDLEN = length, CURPTR advanced.
; ---------------------------------------------------------------------------
INPUT_PARSE_STR_FIELD:
    CALL SKIPSP_CUR
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    STORE R1, TMPH
    STORE R2, TMPL
    SET #0x00, R5

    CALL PEEKCHAR_CUR
    CMP R0, #0x22
    JZ R0, IPS_QUOTED

IPS_RAW_LOOP:
    CALL PEEKCHAR_CUR
    CMP R0, #0x00
    JZ R0, IPS_DONE
    CALL PEEKCHAR_CUR
    CMP R0, #0x2C
    JZ R0, IPS_DONE
    CALL GETCHAR_CUR
    INC R5
    JMP IPS_RAW_LOOP

IPS_QUOTED:
    CALL GETCHAR_CUR
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    STORE R1, TMPH
    STORE R2, TMPL
    SET #0x00, R5
IPS_Q_LOOP:
    CALL PEEKCHAR_CUR
    CMP R0, #0x00
    JZ R0, IPS_DONE
    CALL PEEKCHAR_CUR
    CMP R0, #0x22
    JZ R0, IPS_Q_END
    CALL GETCHAR_CUR
    INC R5
    JMP IPS_Q_LOOP
IPS_Q_END:
    CALL GETCHAR_CUR

IPS_DONE:
    STORE R5, IDLEN
    RET

; ---------------------------------------------------------------------------
; INPUT_STORE_STR_FIELD
;   Store source string TMPH:TMPL / IDLEN into heap and current TMP_PTR entry.
; ---------------------------------------------------------------------------
INPUT_STORE_STR_FIELD:
    LOAD TMPH, R6
    LOAD TMPL, R7
    LOAD IDLEN, R5

    LOAD STRFREE_H, R3
    LOAD STRFREE_L, R4
    STORE R3, DIVH
    STORE R4, DIVL

ISS_COPY_LOOP:
    JZ R5, ISS_TERM
    LOADR R0, R6, R7
    STORER R0, R3, R4
    INC R7
    JNZ R7, ISS_S1
    INC R6
ISS_S1:
    INC R4
    JNZ R4, ISS_D1
    INC R3
ISS_D1:
    DEC R5
    JMP ISS_COPY_LOOP

ISS_TERM:
    SET #0x00, R0
    STORER R0, R3, R4
    INC R4
    JNZ R4, ISS_ADV1
    INC R3
ISS_ADV1:
    STORE R3, STRFREE_H
    STORE R4, STRFREE_L

    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    PUSH R1
    PUSH R2
    ADD #12, R2
    JNC ISS_P1
    INC R1
ISS_P1:
    LOAD DIVH, R0
    STORER R0, R1, R2
    INC R2
    JNZ R2, ISS_P2
    INC R1
ISS_P2:
    LOAD DIVL, R0
    STORER R0, R1, R2
    INC R2
    JNZ R2, ISS_P3
    INC R1
ISS_P3:
    LOAD IDLEN, R0
    STORER R0, R1, R2
    POP R2
    POP R1
    RET

; ---------------------------------------------------------------------------
; DO_PRINT: compatibility wrapper for printing one item followed by newline
; ---------------------------------------------------------------------------
DO_PRINT:
    CALL DO_PRINT_ITEM
    SET #0x0A, R0
    CALL PUTC
    RET

; ---------------------------------------------------------------------------
; DO_PRINT_ITEM: prints one string/numeric item without forcing a newline
; ---------------------------------------------------------------------------
DO_PRINT_ITEM:
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
    JZ R5, DP_DONE
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
    JZ R5, DP_DONE
    LOADR R0, R6, R7
    JZ R0, DP_DONE
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
    JMP DP_DONE

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
    JMP DP_DONE

DP_STR_DONE_QUOTE:
    ; consume closing quote and store CURPTR
    INC R2
    JNZ R2, DSQ1
    INC R1
DSQ1:
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    JMP DP_DONE

DP_DONE:
    RET
