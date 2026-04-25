; ---------------------------------------------------------------------------
; basic_data.s8.asm
;
; Sophia BASIC v1 - DATA / READ / RESTORE support.
;
; Behavior implemented (Phase 14):
;   - DATA lines are stored as normal program lines and are ignored at runtime.
;   - READ assigns sequential DATA items into variables.
;     * Numeric variables consume numeric DATA items (decimal, optional sign).
;     * String variables (name ending with '$') consume string DATA items.
;       Supported formats: "QUOTED" or unquoted up to comma/end.
;   - RESTORE resets the DATA pointer to the start (RESTORE)
;     or to the first DATA statement at/after a given line number
;     (RESTORE <lineno>).
;
; Out-of-data handling:
;   - If READ requests an item but no further DATA exists, it prints
;     "?OUT OF DATA" and stops RUN.
;
; Dependencies:
;   - basic_state.s8.asm: PROG_END_*, DATA_*, CURPTR_*, TMP_LINENO_*
;   - basic_progstore.s8.asm: PROG_GET_TEXT_PTR, PROG_NEXT_PTR
;   - basic_helpers.s8.asm: PARSE_INT16
;   - basic_strfn.s8.asm: STR_ALLOC_AND_COPY
;   - text.s8.asm: SKIPSP
;   - basic_errors.s8.asm: PRINT_OUT_OF_DATA
; ---------------------------------------------------------------------------

; Reset DATA reader state (called at start of RUN and by RESTORE)
DATA_RESET:
    SET #0x00, R0
    STORE R0, DATA_VALID
    STORE R0, DATA_INDEX
    SET #0x40, R0
    STORE R0, DATA_LINE_H
    SET #0x00, R0
    STORE R0, DATA_LINE_L
    STORE R0, DATA_PTR_H
    STORE R0, DATA_PTR_L
    RET

; ---------------------------------------------------------------------------
; DATA_RESTORE_TO_LINE
;   Restore DATA scan starting at the first program line whose line number
;   is >= TMP_LINENO_H/L.
;   Sets DATA_LINE_* and clears DATA_VALID so next READ will rescan.
; ---------------------------------------------------------------------------
DATA_RESTORE_TO_LINE:
    SET #0x40, R1
    SET #0x00, R2
DRTL_LOOP:
    LOAD PROG_END_H, R3
    LOAD PROG_END_L, R4
    SET #0x00, R5
    ADDR R1, R5
    CMPR R5, R3
    JNZ R5, DRTL_HAVE
    SET #0x00, R5
    ADDR R2, R5
    CMPR R5, R4
    JZ R5, DRTL_DONE

DRTL_HAVE:
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L

    ; read line number
    LOADR R6, R1, R2       ; high
    INC R2
    JNZ R2, DRTL1
    INC R1
DRTL1:
    LOADR R7, R1, R2       ; low

    LOAD TMP_LINENO_H, R0
    SET #0x00, R5
    ADDR R6, R5
    CMPR R5, R0
    JC DRTL_NEXT
    JNZ R5, DRTL_PICK

    LOAD TMP_LINENO_L, R0
    SET #0x00, R5
    ADDR R7, R5
    CMPR R5, R0
    JC DRTL_NEXT
    JMP DRTL_PICK

DRTL_NEXT:
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    CALL PROG_NEXT_PTR
    JMP DRTL_LOOP

DRTL_PICK:
    LOAD TMP_PTR_H, R0
    STORE R0, DATA_LINE_H
    LOAD TMP_PTR_L, R0
    STORE R0, DATA_LINE_L
    SET #0x00, R0
    STORE R0, DATA_VALID
    RET

DRTL_DONE:
    LOAD PROG_END_H, R0
    STORE R0, DATA_LINE_H
    LOAD PROG_END_L, R0
    STORE R0, DATA_LINE_L
    SET #0x00, R0
    STORE R0, DATA_VALID
    RET

; ---------------------------------------------------------------------------
; Internal: DATA_FIND_NEXT_STATEMENT
;   Starting from DATA_LINE_*, locate the next program line that begins with
;   a DATA statement (after optional leading spaces).
;
; Outputs:
;   R0 = 1 if found, 0 if not found
;   DATA_LINE updated to the record where DATA was found
;   DATA_PTR updated to point to first byte after keyword and any spaces
;   DATA_VALID set to 1 on success
; ---------------------------------------------------------------------------
DATA_FIND_NEXT_STATEMENT:
    LOAD DATA_LINE_H, R1
    LOAD DATA_LINE_L, R2
DFNS_LOOP:
    LOAD PROG_END_H, R3
    LOAD PROG_END_L, R4
    SET #0x00, R5
    ADDR R1, R5
    CMPR R5, R3
    JNZ R5, DFNS_HAVE
    SET #0x00, R5
    ADDR R2, R5
    CMPR R5, R4
    JZ R5, DFNS_FAIL

DFNS_HAVE:
    STORE R1, TMP_PTR_H
    STORE R2, TMP_PTR_L
    CALL PROG_GET_TEXT_PTR
    ; skip spaces
    CALL SKIPSP

    ; match 'D''A''T''A'
    LOADR R0, R1, R2
    CMP R0, #0x44
    JNZ R0, DFNS_NEXTLINE
    INC R2
    JNZ R2, DFNS4
    INC R1
DFNS4:
    LOADR R0, R1, R2
    CMP R0, #0x41
    JNZ R0, DFNS_NEXTLINE
    INC R2
    JNZ R2, DFNS5
    INC R1
DFNS5:
    LOADR R0, R1, R2
    CMP R0, #0x54
    JNZ R0, DFNS_NEXTLINE
    INC R2
    JNZ R2, DFNS6
    INC R1
DFNS6:
    LOADR R0, R1, R2
    CMP R0, #0x41
    JNZ R0, DFNS_NEXTLINE

    ; advance past keyword
    INC R2
    JNZ R2, DFNS7
    INC R1
DFNS7:
    CALL SKIPSP

    ; store state
    LOAD TMP_PTR_H, R0
    STORE R0, DATA_LINE_H
    LOAD TMP_PTR_L, R0
    STORE R0, DATA_LINE_L
    STORE R1, DATA_PTR_H
    STORE R2, DATA_PTR_L
    SET #0x01, R0
    STORE R0, DATA_VALID
    SET #0x01, R0
    RET

DFNS_NEXTLINE:
    LOAD TMP_PTR_H, R1
    LOAD TMP_PTR_L, R2
    CALL PROG_NEXT_PTR
    JMP DFNS_LOOP

DFNS_FAIL:
    SET #0x00, R0
    STORE R0, DATA_VALID
    RET

; ---------------------------------------------------------------------------
; Internal: DATA_ENSURE_PTR
;   Ensure DATA_PTR points at a valid unread item.
;   Returns R0=1 ok, R0=0 out of data (and stops RUN).
; ---------------------------------------------------------------------------
DATA_ENSURE_PTR:
    LOAD DATA_VALID, R0
    CMP R0, #0x01
    JZ R0, DEP_OK

    CALL DATA_FIND_NEXT_STATEMENT
    CMP R0, #0x01
    JZ R0, DEP_OK

    ; out of data
    CALL PRINT_OUT_OF_DATA
    SET #0x01, R0
    STORE R0, RUN_STOP
    SET #0x00, R0
    RET
DEP_OK:
    SET #0x01, R0
    RET

; ---------------------------------------------------------------------------
; DATA_NEXT_NUM
;   Returns next numeric DATA item.
; Output:
;   R0=1 on success, R6:R7=value
;   R0=0 on out-of-data (RUN_STOP is set and error printed)
; ---------------------------------------------------------------------------
DATA_NEXT_NUM:
    ; IMPORTANT:
    ; PARSE_INT16 operates on the global CURPTR_* cursor. READ parsing
    ; must not be disrupted, so we save and restore CURPTR_* around
    ; the DATA item parse.
    LOAD CURPTR_H, R0
    STORE R0, SAVCUR_H
    LOAD CURPTR_L, R0
    STORE R0, SAVCUR_L

    CALL DATA_ENSURE_PTR
    CMP R0, #0x01
    JNZ R0, DNN_FAIL

    ; set CURPTR to DATA_PTR and parse int16
    LOAD DATA_PTR_H, R1
    LOAD DATA_PTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    CALL PARSE_INT16          ; value -> R6:R7, CURPTR advanced

    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP

    ; check delimiter
    LOADR R0, R1, R2
    CMP R0, #0x2C             ; ','
    JNZ R0, DNN_DELIM_DONE
    ; consume comma
    INC R2
    JNZ R2, DNN_C1
    INC R1
DNN_C1:
DNN_DELIM_DONE:
    ; if end-of-string => invalidate and move to next line
    LOADR R0, R1, R2
    CMP R0, #0x00
    JNZ R0, DNN_STORE
    LOAD DATA_LINE_H, R1
    LOAD DATA_LINE_L, R2
    CALL PROG_NEXT_PTR
    STORE R1, DATA_LINE_H
    STORE R2, DATA_LINE_L
    SET #0x00, R0
    STORE R0, DATA_VALID
    JMP DNN_OK

DNN_STORE:
    STORE R1, DATA_PTR_H
    STORE R2, DATA_PTR_L
    SET #0x01, R0
    STORE R0, DATA_VALID

DNN_OK:
    ; restore READ cursor
    LOAD SAVCUR_H, R0
    STORE R0, CURPTR_H
    LOAD SAVCUR_L, R0
    STORE R0, CURPTR_L
    SET #0x01, R0
    RET
DNN_FAIL:
    ; restore READ cursor (best-effort)
    LOAD SAVCUR_H, R0
    STORE R0, CURPTR_H
    LOAD SAVCUR_L, R0
    STORE R0, CURPTR_L
    SET #0x00, R0
    RET

.org 0x9A00

; ---------------------------------------------------------------------------
; DATA_NEXT_STR
;   Returns next string DATA item. Always returns a heap-owned string.
; Output:
;   R0=1 on success, R6:R7=heap ptr, R5=len
;   R0=0 on out-of-data (RUN_STOP is set and error printed)
; ---------------------------------------------------------------------------
DATA_NEXT_STR:
    CALL DATA_ENSURE_PTR
    CMP R0, #0x01
    JNZ R0, DNS_FAIL

    LOAD DATA_PTR_H, R1
    LOAD DATA_PTR_L, R2
    CALL SKIPSP

    ; check for quoted string
    LOADR R0, R1, R2
    CMP R0, #0x22             ; '"'
    JNZ R0, DNS_UNQUOTED

    ; start = after quote
    INC R2
    JNZ R2, DNS_Q0
    INC R1
DNS_Q0:
    SET #0x00, R5             ; len
    SET #0x00, R6
    ADDR R1, R6               ; src hi
    SET #0x00, R7
    ADDR R2, R7               ; src lo

    ; scan until closing quote or NUL
DNS_QSCAN:
    LOADR R0, R1, R2
    CMP R0, #0x00
    JZ R0, DNS_QEND
    CMP R0, #0x22
    JZ R0, DNS_QEND
    INC R5
    INC R2
    JNZ R2, DNS_QSCAN
    INC R1
    JMP DNS_QSCAN
DNS_QEND:
    ; allocate & copy exact len from (R6:R7)
    SET #0x00, R0
    SET #0x00, R1
    ADDR R5, R1               ; requested len
    CALL STR_ALLOC_AND_COPY   ; returns dest in R6:R7, len in R5

    ; advance parser ptr past closing quote if present
    LOAD DATA_PTR_H, R1
    LOAD DATA_PTR_L, R2
    CALL SKIPSP
    ; consume opening quote
    INC R2
    JNZ R2, DNS_QADV1
    INC R1
DNS_QADV1:
    ; advance by length
    ADDR R5, R2
    JNC DNS_QADV2
    INC R1
DNS_QADV2:
    ; if current is closing quote, consume
    LOADR R0, R1, R2
    CMP R0, #0x22
    JNZ R0, DNS_POST
    INC R2
    JNZ R2, DNS_POST
    INC R1
    JMP DNS_POST

DNS_UNQUOTED:
    ; unquoted: read until comma or NUL
    SET #0x00, R5
    SET #0x00, R6
    ADDR R1, R6
    SET #0x00, R7
    ADDR R2, R7
DNS_USCAN:
    LOADR R0, R1, R2
    CMP R0, #0x00
    JZ R0, DNS_UEND
    CMP R0, #0x2C
    JZ R0, DNS_UEND
    INC R5
    INC R2
    JNZ R2, DNS_USCAN
    INC R1
    JMP DNS_USCAN
DNS_UEND:
    SET #0x00, R0
    SET #0x00, R1
    ADDR R5, R1
    CALL STR_ALLOC_AND_COPY

    ; advance parser ptr by len (no extra terminator)
    LOAD DATA_PTR_H, R1
    LOAD DATA_PTR_L, R2
    CALL SKIPSP
    ADDR R5, R2
    JNC DNS_POST
    INC R1

DNS_POST:
    ; skip spaces
    CALL SKIPSP
    ; consume comma if present
    LOADR R0, R1, R2
    CMP R0, #0x2C
    JNZ R0, DNS_POST2
    INC R2
    JNZ R2, DNS_POST2
    INC R1
DNS_POST2:
    ; if end-of-string => invalidate and move to next line
    LOADR R0, R1, R2
    CMP R0, #0x00
    JNZ R0, DNS_STORE
    LOAD DATA_LINE_H, R1
    LOAD DATA_LINE_L, R2
    CALL PROG_NEXT_PTR
    STORE R1, DATA_LINE_H
    STORE R2, DATA_LINE_L
    SET #0x00, R0
    STORE R0, DATA_VALID
    JMP DNS_OK

DNS_STORE:
    STORE R1, DATA_PTR_H
    STORE R2, DATA_PTR_L
    SET #0x01, R0
    STORE R0, DATA_VALID

DNS_OK:
    SET #0x01, R0
    RET
DNS_FAIL:
    SET #0x00, R0
    RET
