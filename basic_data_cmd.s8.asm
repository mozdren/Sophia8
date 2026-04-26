; ---------------------------------------------------------------------------
; basic_data_cmd.s8.asm
;
; Command handlers for DATA / READ / RESTORE.
; Placed in a high code segment so BASIC user POKE at 38400 (0x9600)
; does not overwrite the READ string-assignment path.
; ---------------------------------------------------------------------------


CMD_DATA:
    ; DATA is not executed at runtime (it only provides data for READ).
    ; Skip the remainder of the current line safely (max 80 chars) to avoid
    ; issues if a stored line is not NUL-terminated for any reason.
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    SET #80, R5
CDAT_SKIP:
    JZ R5, CDAT_DONE
    LOADR R0, R1, R2
    CMP R0, #0x00
    JZ R0, CDAT_DONE
    INC R2
    JNZ R2, CDAT1
    INC R1
CDAT1:
    DEC R5
    JMP CDAT_SKIP
CDAT_DONE:
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L
    RET

CMD_READ:
    ; READ <var>[, <var> ...]
    ; For each var: consume next DATA item and assign.
CRD_LOOP:
    CALL SKIPSP_CUR

    ; parse identifier
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL PARSE_IDENT
    CMP R0, #0x01
    JNZ R0, CRD_SYNTAX
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    ; find/create variable entry
    CALL VAR_FIND_OR_CREATE
    CMP R0, #0x01
    JNZ R0, CRD_SYNTAX
    ; entry ptr in R1:R2

    LOAD IDTYPE, R0
    CMP R0, #0x01
    JZ R0, CRD_STR

    ; numeric
    PUSH R1
    PUSH R2
    CALL DATA_NEXT_NUM
    POP R2
    POP R1
    CMP R0, #0x01
    JNZ R0, CRD_DONE          ; out-of-data already handled
    CALL STORE_VAR_INT
    JMP CRD_NEXTVAR

CRD_STR:
    ; string
    STORE R1, TMP_ENTRY_H
    STORE R2, TMP_ENTRY_L
    CALL DATA_NEXT_STR
    CMP R0, #0x01
    JNZ R0, CRD_DONE          ; out-of-data already handled

    ; store ptr+len into entry (offset 12..14)
    LOAD TMP_ENTRY_H, R1
    LOAD TMP_ENTRY_L, R2
    PUSH R1
    PUSH R2
    ADD #12, R2
    JNC CRDS1
    INC R1
CRDS1:
    STORER R6, R1, R2
    INC R2
    JNZ R2, CRDS2
    INC R1
CRDS2:
    STORER R7, R1, R2
    INC R2
    JNZ R2, CRDS3
    INC R1
CRDS3:
    STORER R5, R1, R2
    POP R2
    POP R1

CRD_NEXTVAR:
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x2C
    JNZ R0, CRD_DONE
    CALL GETCHAR_CUR
    JMP CRD_LOOP

CRD_SYNTAX:
    CALL PRINT_SYNTAX_ERROR
CRD_DONE:
    RET

CMD_RESTORE:
    ; RESTORE [lineno]
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x00
    JZ R0, CRS_ALL

    ; parse line number as uint16
    CALL PARSE_U16_DEC
    STORE R6, TMP_LINENO_H
    STORE R7, TMP_LINENO_L

    CALL DATA_RESTORE_TO_LINE
    RET

CRS_ALL:
    CALL DATA_RESET
    RET
