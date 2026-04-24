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
    ; linecount=0
    SET #0x00, R0
    STORE R0, LINECOUNT

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

    ; read line to 0x6C00 (CLI buffer) - keep away from code region
    SET #0x6C, R1
    SET #0x00, R2
    SET #96, R3
    CALL READLINE_ECHO

    ; make a stable copy to 0x6D00 so parsing is not affected by any
    ; input/echo side-effects or stray terminators
    CALL COPY_INBUF_6C00_TO_6D00

    ; newline
    SET #0x02, R1
    SET #0x44, R2
    CALL PUTS

    ; uppercase stable copy
    SET #0x6D, R1
    SET #0x00, R2
    CALL TOUPPER_Z

    ; skip spaces
    SET #0x6D, R1
    SET #0x00, R2
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
    LOAD LINECOUNT, R0
    CMP R0, #0x00
    JZ R0, RUN_NOP

    SET #0x00, R0
    STORE R0, RUN_STOP
    SET #0x01, R0
    STORE R0, RUNNING

    ; reset DATA/READ pointer for each RUN
    CALL DATA_RESET

    SET #0x00, R4
    STORE R4, RUN_INDEX
    LOAD LINECOUNT, R5
    STORE R5, RUN_LC

RP_LOOP:
    LOAD RUN_STOP, R0
    CMP R0, #0x01
    JZ R0, RP_DONE

    LOAD RUN_INDEX, R4
    LOAD RUN_LC, R6
    SET #0x00, R7
    ADDR R4, R7
    SUBR R6, R7
    JZ R7, RP_DONE

    SET #0x40, R1
    SET #0x00, R2
    SET #0x00, R6
    ADDR R4, R6
    CALL ADD_ENTRY_OFFSET

    ; skip lineno
    INC R2
    JNZ R2, RP1
    INC R1
RP1:
    INC R2
    JNZ R2, RP2
    INC R1
RP2:
    ; len
    LOADR R0, R1, R2
    CMP R0, #0x00
    JZ R0, RP_NEXT

    ; text
    INC R2
    JNZ R2, RP3
    INC R1
RP3:
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    SET #0x00, R0
    STORE R0, JUMPED

    CALL EXEC_STMT

    LOAD JUMPED, R0
    CMP R0, #0x01
    JZ R0, RP_LOOP

RP_NEXT:
    LOAD RUN_INDEX, R4
    INC R4
    STORE R4, RUN_INDEX
    JMP RP_LOOP

RP_DONE:
    SET #0x00, R0
    STORE R0, RUNNING
    RET

RUN_NOP:
    CALL PRINT_NO_PROGRAM
    RET
