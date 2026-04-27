; ---------------------------------------------------------------------------
; basic_errors.s8.asm
;
; Sophia BASIC v1 - common error printing helpers.
;
; Purpose:
;   Consolidate repeated "load fixed-address string + PUTS" sequences used by
;   statement handlers and runtime code.
;
; Dependencies:
;   - PUTS routine from kernel.s8.asm / cli.s8.asm.
;   - Fixed-address strings live in basic_strings.s8.asm:
;       STR_ERR_SYNTAX, STR_ERR_NOPROG, STR_ERR_UNDEFLINE, STR_ERR_OUTOFDATA
;
; Calling convention:
;   - These routines clobber R1 and R2 (string pointer registers for PUTS).
;   - Other registers are preserved.
; ---------------------------------------------------------------------------

.org BASIC_UTIL_BASE

; Print "?SYNTAX ERROR\n"
PRINT_SYNTAX_ERROR:
    PUSH R1
    PUSH R2
    SET #STR_ERR_SYNTAX_H, R1
    SET #STR_ERR_SYNTAX_L, R2
    CALL PUTS
    POP R2
    POP R1
    RET

; Print "?NO PROGRAM\n"
PRINT_NO_PROGRAM:
    PUSH R1
    PUSH R2
    SET #STR_ERR_NOPROG_H, R1
    SET #STR_ERR_NOPROG_L, R2
    CALL PUTS
    POP R2
    POP R1
    RET

; Print "?UNDEFINED LINE\n"
PRINT_UNDEF_LINE:
    PUSH R1
    PUSH R2
    SET #STR_ERR_UNDEFLINE_H, R1
    SET #STR_ERR_UNDEFLINE_L, R2
    CALL PUTS
    POP R2
    POP R1
    RET

; Print "?OUT OF DATA\n"
PRINT_OUT_OF_DATA:
    PUSH R1
    PUSH R2
    SET #STR_ERR_OUTOFDATA_H, R1
    SET #STR_ERR_OUTOFDATA_L, R2
    CALL PUTS
    POP R2
    POP R1
    RET
