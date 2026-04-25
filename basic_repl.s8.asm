; ---------------------------------------------------------------------------
; basic_repl.s8.asm
;
; Sophia BASIC v1 - REPL + program run loop
;
; This module contains the interactive Read-Eval-Print loop (REPL) and the
; program execution loop (RUN_PROG). It is extracted from sophia_basic_v1.s8.asm
; to keep the main BASIC file as a focused "composition" unit.
;
; Expected include order / dependencies:
;   - kernel.s8.asm + cli.s8.asm (PUTS, READLINE_ECHO, etc.)
;   - text.s8.asm (TOUPPER_Z, SKIPSP, ISDIGIT)
;   - basic_helpers.s8.asm (COPY_INBUF_6C00_TO_6D00, ADD_ENTRY_OFFSET, etc.)
;   - basic_state.s8.asm (LINECOUNT, CURPTR_*, RUN_* state)
;   - basic_init.s8.asm (INIT_VARS)
;   - basic_progstore.s8.asm (HANDLE_PROGLINE)
;   - basic_stmt.s8.asm (EXEC_STMT)
;
; No .org directives are used here: the caller decides placement.
; ---------------------------------------------------------------------------

START:
    CALL PROG_RESET

    ; init variables + string heap
    CALL INIT_VARS

    ; banner
    SET #0x02, R1
    SET #0x00, R2
    CALL PUTS

REPL:
    ; prompt
    SET #0x02, R1
    SET #0x40, R2
    CALL PUTS

    ; read line to 0x6F00 (CLI buffer) - kept above current BASIC code
    SET #0x6F, R1
    SET #0x00, R2
    SET #96, R3
    CALL READLINE_ECHO

    ; make a stable copy to 0x6F80 so parsing is not affected by any
    ; input/echo side-effects or stray terminators
    CALL COPY_INBUF_6C00_TO_6D00

    ; newline
    SET #0x02, R1
    SET #0x44, R2
    CALL PUTS

    ; uppercase stable copy
    SET #0x6F, R1
    SET #0x80, R2
    CALL TOUPPER_Z

    ; skip spaces
    SET #0x6F, R1
    SET #0x80, R2
    CALL SKIPSP
    LOADR R0, R1, R2
    CMP R0, #0x00
    JZ R0, REPL

    ; digit? program line
    CALL ISDIGIT
    CMP R0, #0x01
    JZ R0, HANDLE_PROGLINE

    ; immediate statement
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL EXEC_STMT
    JMP REPL

; ---------------------------------------------------------------------------
; RUN_PROG: execute stored program lines
; ---------------------------------------------------------------------------
RUN_PROG:
    LOAD PROG_END_H, R1
    LOAD PROG_END_L, R2
    CMP R1, #0x40
    JNZ R1, RP_HAVE_PROG
    CMP R2, #0x00
    JZ R2, RUN_NOP

RP_HAVE_PROG:

    SET #0x00, R0
    STORE R0, RUN_STOP
    SET #0x01, R0
    STORE R0, RUNNING

    ; reset DATA/READ pointer for each RUN
    CALL DATA_RESET

    SET #0x40, R0
    STORE R0, RUN_PTR_H
    SET #0x00, R0
    STORE R0, RUN_PTR_L

RP_LOOP:
    LOAD RUN_STOP, R0
    CMP R0, #0x01
    JZ R0, RP_DONE

    LOAD RUN_PTR_H, R1
    LOAD RUN_PTR_L, R2
    LOAD PROG_END_H, R3
    LOAD PROG_END_L, R4
    SET #0x00, R5
    ADDR R1, R5
    CMPR R5, R3
    JNZ R5, RP_HAVE_LINE
    SET #0x00, R5
    ADDR R2, R5
    CMPR R5, R4
    JZ R5, RP_DONE

RP_HAVE_LINE:
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    CALL PROG_NEXT_PTR
    STORE R1, RUN_NEXT_H
    STORE R2, RUN_NEXT_L

    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    CALL PROG_GET_TEXT_PTR
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    SET #0x00, R0
    STORE R0, JUMPED

    CALL EXEC_STMT

    LOAD JUMPED, R0
    CMP R0, #0x01
    JZ R0, RP_LOOP

RP_NEXT:
    LOAD RUN_NEXT_H, R0
    STORE R0, RUN_PTR_H
    LOAD RUN_NEXT_L, R0
    STORE R0, RUN_PTR_L
    JMP RP_LOOP

RP_DONE:
    SET #0x00, R0
    STORE R0, RUNNING
    RET

RUN_NOP:
    CALL PRINT_NO_PROGRAM
    RET
