; BASIC program storage helpers
; Extracted from sophia_basic_v1.s8.asm to keep core slim.
;
; Provides:
;  - HANDLE_PROGLINE (parses/dispatches numbered lines in REPL)
;  - STORE_LINE / DELETE_LINE / DELETE_BY_LINENO
;  - FIND_LINE and LIST_ALL
;
; Dependencies:
;  - basic_state.s8.asm provides LINECOUNT and temp vars
;  - basic_helpers.s8.asm provides ADD_ENTRY_OFFSET
;  - kernel/cli/fmt provide PUTC/PUTS/PUTDEC8 etc.
;

HANDLE_PROGLINE:
    ; parse line number => uint16
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    CALL PARSE_U16_DEC
    STORE R6, TMP_LINENO_H
    STORE R7, TMP_LINENO_L
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2

    CALL SKIPSP
    ; if end => delete
    LOADR R0, R1, R2
    CMP R0, #0x00
    JZ R0, DELETE_LINE

    ; save src ptr
    STORE R1, CURSRC_H
    STORE R2, CURSRC_L
    CALL STORE_LINE
    JMP REPL

DELETE_LINE:
    CALL DELETE_BY_LINENO
    JMP REPL

; STORE_LINE: replace if exists else append
STORE_LINE:
    CALL FIND_LINE
    CMP R0, #0x01
    JZ R0, SL_WRITE

    LOAD LINECOUNT, R4
    SET #0x00, R7
    ADDR R4, R7
    CMP R7, #100
    JZ R7, SL_FAIL

    INC R4
    STORE R4, LINECOUNT
    DEC R4

SL_WRITE:
    ; dst = 0x4000 + index*84
    SET #0x40, R1
    SET #0x00, R2
    SET #0x00, R6
    ADDR R4, R6
    CALL ADD_ENTRY_OFFSET

    ; write lineno
    LOAD TMP_LINENO_H, R0
    STORER R0, R1, R2
    INC R2
    JNZ R2, BPS_SL1
    INC R1
BPS_SL1:
    LOAD TMP_LINENO_L, R0
    STORER R0, R1, R2
    INC R2
    JNZ R2, BPS_SL2
    INC R1
BPS_SL2:
    ; len ptr
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L

    ; advance dst past len byte
    INC R2
    JNZ R2, BPS_SL_LENOK
    INC R1
BPS_SL_LENOK:

    ; copy text
    LOAD CURSRC_H, R3
    LOAD CURSRC_L, R4
    SET #0x00, R5
BPS_SL_CPY:
    SET #0x00, R6
    ADDR R5, R6
    CMP R6, #80
    JZ R6, BPS_SL_DONE
    LOADR R0, R3, R4
    CMP R0, #0x00
    JZ R0, BPS_SL_DONE
    STORER R0, R1, R2
    INC R2
    JNZ R2, BPS_SLD1
    INC R1
BPS_SLD1:
    INC R4
    JNZ R4, BPS_SLS1
    INC R3
BPS_SLS1:
    INC R5
    JMP BPS_SL_CPY
BPS_SL_DONE:
    SET #0x00, R0
    STORER R0, R1, R2

    ; write len
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    SET #0x00, R0
    ADDR R5, R0
    STORER R0, R1, R2
    RET

SL_FAIL:
    CALL PRINT_SYNTAX_ERROR
    RET

; FIND_LINE: lineno in TMP_LINENO_H/L, returns R0=1 found, R4=index
FIND_LINE:
    SET #0x00, R4
    LOAD LINECOUNT, R5
    STORE R5, RUN_LC
BPS_FL_LOOP:
    LOAD RUN_LC, R6
    SET #0x00, R7
    ADDR R4, R7
    SUBR R6, R7
    JZ R7, BPS_FL_NO

    SET #0x40, R1
    SET #0x00, R2
    SET #0x00, R6
    ADDR R4, R6
    CALL ADD_ENTRY_OFFSET

    LOADR R6, R1, R2
    INC R2
    JNZ R2, BPS_FL1
    INC R1
BPS_FL1:
    LOADR R7, R1, R2

    LOAD TMP_LINENO_H, R0
    CMPR R6, R0
    JNZ R6, BPS_FL_NEXT
    LOAD TMP_LINENO_L, R0
    CMPR R7, R0
    JZ R7, BPS_FL_YES

BPS_FL_NEXT:
    INC R4
    JMP BPS_FL_LOOP
BPS_FL_NO:
    SET #0x00, R0
    RET
BPS_FL_YES:
    SET #0x01, R0
    RET

DELETE_BY_LINENO:
    CALL FIND_LINE
    CMP R0, #0x01
    JNZ R0, DB_DONE

    SET #0x40, R1
    SET #0x00, R2
    SET #0x00, R6
    ADDR R4, R6
    CALL ADD_ENTRY_OFFSET

    ; skip lineno
    INC R2
    JNZ R2, BPS_DB1
    INC R1
BPS_DB1:
    INC R2
    JNZ R2, BPS_DB2
    INC R1
BPS_DB2:
    ; len=0
    SET #0x00, R0
    STORER R0, R1, R2
DB_DONE:
    RET

LIST_ALL:
    SET #0x00, R4
    LOAD LINECOUNT, R5
    STORE R5, RUN_LC
BPS_LA_LOOP:
    LOAD RUN_LC, R6
    SET #0x00, R7
    ADDR R4, R7
    SUBR R6, R7
    JZ R7, BPS_LA_DONE

    SET #0x40, R1
    SET #0x00, R2
    SET #0x00, R6
    ADDR R4, R6
    CALL ADD_ENTRY_OFFSET

    ; read lineno high/low
    LOADR R6, R1, R2
    INC R2
    JNZ R2, BPS_LA1
    INC R1
BPS_LA1:
    LOADR R7, R1, R2
    INC R2
    JNZ R2, BPS_LA2
    INC R1
BPS_LA2:
    ; len
    LOADR R5, R1, R2
    CMP R5, #0x00
    JZ R5, BPS_LA_NEXT

    ; preserve loop regs + pointer across PUTDEC16U
    PUSH R4
    PUSH R5
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    CALL PUTDEC16U
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    POP R5
    POP R4

    SET #0x20, R0
    CALL PUTC

    INC R2
    JNZ R2, BPS_LA3
    INC R1
BPS_LA3:
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

BPS_LA_NEXT:
    INC R4
    JMP BPS_LA_LOOP
BPS_LA_DONE:
    RET
