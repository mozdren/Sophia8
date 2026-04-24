; ---------------------------------------------------------------------------
; basic_array.s8.asm
;
; Sophia BASIC v1 - DIM and 1D integer arrays.
;
; Purpose:
;   Provide a small, focused implementation of DIM and array element access.
;   Arrays are stored as dedicated entries in the existing variable table.
;
; Supported (v1):
;   - DIM <name>(<maxIndex>)       ; integer arrays only
;   - <name>(<index>) = <expr>     ; assignment
;   - PRINT <name>(<index>)        ; read in expressions
;
; Variable table encoding for integer arrays (IDTYPE = 2):
;   Entry base +10..11 : data pointer (H,L)
;   Entry base +12..13 : max index (H,L)
;
; Memory allocation:
;   Uses the same upward-growing heap pointer STRFREE as string allocations.
;   DIM A(n) allocates (n+1) elements * 2 bytes.
;
; Provides:
;   CMD_DIM                - DIM statement handler
;   ARRAY_LOAD_INT_ELEM    - load array element into R6:R7
;   ARRAY_STORE_INT_ELEM   - store R6:R7 into array element
;
; Dependencies:
;   - basic_state.s8.asm    (CURPTR_*, IDBUF/IDTYPE, STRFREE, temporaries)
;   - basic_expr.s8.asm     (PARSE_IDENT, EVAL_EXPR, SKIPSP_CUR/PEEKCHAR_CUR/GETCHAR_CUR)
;   - basic_vars.s8.asm     (VAR_FIND, VAR_FIND_OR_CREATE)
;   - basic_errors.s8.asm   (PRINT_SYNTAX_ERROR)
;
; Calling convention notes:
;   ARRAY_LOAD_INT_ELEM / ARRAY_STORE_INT_ELEM expect:
;     - IDBUF contains the array name (uppercase, padded)
;     - Index in R6:R7 (16-bit, unsigned)
;   They temporarily set IDTYPE=2 while searching the var table.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Helpers: load array meta from entry pointer
;   IN  R1:R2 = entry base
;   OUT R3:R4 = data ptr (H,L)
;       R5:R0 = max index (H,L)  (note: R0 used for low byte)
; ---------------------------------------------------------------------------
ARRAY_META_LOAD:
    ; data ptr at +10/+11
    PUSH R1
    PUSH R2
    ADD #10, R2
    JNC AML1
    INC R1
AML1:
    LOADR R3, R1, R2
    INC R2
    JNZ R2, AML2
    INC R1
AML2:
    LOADR R4, R1, R2
    INC R2
    JNZ R2, AML3
    INC R1
AML3:
    ; max index at +12/+13
    LOADR R5, R1, R2
    INC R2
    JNZ R2, AML4
    INC R1
AML4:
    LOADR R0, R1, R2
    POP R2
    POP R1
    RET

; ---------------------------------------------------------------------------
; ARRAY_LOAD_INT_ELEM
;   OUT R6:R7 = element value, or 0 if not found/out of range
; ---------------------------------------------------------------------------
ARRAY_LOAD_INT_ELEM:
    ; lookup array entry (IDTYPE=2)
    LOAD IDTYPE, R4
    SET #0x02, R0
    STORE R0, IDTYPE
    CALL VAR_FIND
    STORE R4, IDTYPE
    CMP R0, #0x01
    JNZ R0, ALE_ZERO

    ; load metadata
    CALL ARRAY_META_LOAD          ; R3:R4 base, R5:R0 max

    ; bounds check: index <= max
    ; compare high
    SET #0x00, R1
    ADDR R7, R1                   ; idxH
    CMPR R1, R5                   ; idxH - maxH
    JNZ R1, ALE_CH
    ; high equal -> compare low
    SET #0x00, R1
    ADDR R6, R1                   ; idxL
    CMPR R1, R0                   ; idxL - maxL
    JNC ALE_INR                   ; idxL <= maxL
    JMP ALE_ZERO
ALE_CH:
    ; if idxH < maxH then in range, else out
    JNC ALE_INR
    JMP ALE_ZERO

ALE_INR:
    ; address = base + index*2
    SET #0x00, R1
    ADDR R6, R1
    ADDR R6, R1                   ; idxL*2
    SET #0x00, R2
    ADDR R7, R2
    ADDR R7, R2                   ; idxH*2
    ; add to base (R3:R4)
    ADDR R1, R4
    JNC ALE_A1
    INC R3
ALE_A1:
    ADDR R2, R3

    ; load 16-bit little endian
    LOADR R6, R3, R4
    INC R4
    JNZ R4, ALE_A2
    INC R3
ALE_A2:
    LOADR R7, R3, R4
    RET

ALE_ZERO:
    SET #0x00, R6
    SET #0x00, R7
    RET

; ---------------------------------------------------------------------------
; ARRAY_STORE_INT_ELEM
;   IN  R6:R7 = value to store
;       TMPL:TMPH (0x6822/0x6821) = index (low/high)
;   Returns R0=1 on success, 0 on failure.
;
; Note:
;   Bounds are checked in the caller (CMD_ASSIGN). This routine assumes the
;   index is already validated.
; ---------------------------------------------------------------------------
ARRAY_STORE_INT_ELEM:
    ; lookup array entry (IDTYPE=2)
    LOAD IDTYPE, R2
    SET #0x02, R0
    STORE R0, IDTYPE
    CALL VAR_FIND
    STORE R2, IDTYPE
    CMP R0, #0x01
    JNZ R0, ASE_FAIL

    ; load metadata
    CALL ARRAY_META_LOAD          ; R3:R4 base, R5:R0 max (unused here)

    ; load index from TMPH/TMPL into R1:R2 (low/high)
    LOAD TMPL, R1
    LOAD TMPH, R2

    ; address = base + index*2
    ADDR R1, R1                   ; idxL*2
    JNC ASE_I1
    INC R2
ASE_I1:
    ADDR R2, R2                   ; idxH*2

    ADDR R1, R4
    JNC ASE_A1
    INC R3
ASE_A1:
    ADDR R2, R3

    STORER R6, R3, R4
    INC R4
    JNZ R4, ASE_A2
    INC R3
ASE_A2:
    STORER R7, R3, R4
    SET #0x01, R0
    RET

ASE_FAIL:
    SET #0x00, R0
    RET

; ---------------------------------------------------------------------------
; CMD_DIM
;   DIM <ident>(<expr>)
;   Integer arrays only; <expr> is max index (0..65535).
; ---------------------------------------------------------------------------
CMD_DIM:
    ; Skip spaces
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    ; Parse identifier
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL PARSE_IDENT
    CMP R0, #0x01
    JNZ R0, DIM_SYN
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    ; Only integer arrays supported (IDTYPE must be 0)
    LOAD IDTYPE, R0
    CMP R0, #0x01
    JZ R0, DIM_SYN

    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x28
    JNZ R0, DIM_SYN
    CALL GETCHAR_CUR

    CALL EVAL_EXPR              ; max index in R6:R7

    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x29
    JNZ R0, DIM_SYN
    CALL GETCHAR_CUR

    ; Set array type and allocate entry
    LOAD IDTYPE, R3
    SET #0x02, R0
    STORE R0, IDTYPE
    CALL VAR_FIND_OR_CREATE     ; entry pointer in R1:R2
    STORE R3, IDTYPE
    CMP R0, #0x01
    JNZ R0, DIM_SYN

    ; Allocate (max+1)*2 bytes at STRFREE
    ; bytes = (maxIndex + 1) * 2
    ; compute elems = max+1 in R4:R5
    SET #0x00, R4
    ADDR R6, R4
    SET #0x00, R5
    ADDR R7, R5
    INC R4
    JNZ R4, DIM_E1
    INC R5
DIM_E1:
    ; bytes = elems*2
    ADDR R4, R4
    JNC DIM_E2
    INC R5
DIM_E2:
    ; R4=bytesL, R5=bytesH

    ; base = STRFREE
    LOAD STRFREE_H, R3
    LOAD STRFREE_L, R0

    ; store base ptr and max index into entry
    ; entry+10..11 = base (H,L)
    ; entry+12..13 = max (H,L)
    PUSH R1
    PUSH R2
    ADD #10, R2
    JNC DIM_P1
    INC R1
DIM_P1:
    STORER R3, R1, R2
    INC R2
    JNZ R2, DIM_P2
    INC R1
DIM_P2:
    STORER R0, R1, R2
    INC R2
    JNZ R2, DIM_P3
    INC R1
DIM_P3:
    STORER R7, R1, R2           ; maxH
    INC R2
    JNZ R2, DIM_P4
    INC R1
DIM_P4:
    STORER R6, R1, R2           ; maxL
    POP R2
    POP R1

    ; advance STRFREE by bytes
    LOAD STRFREE_H, R3
    LOAD STRFREE_L, R0
    ADDR R4, R0
    JNC DIM_S1
    INC R3
DIM_S1:
    ADDR R5, R3
    STORE R3, STRFREE_H
    STORE R0, STRFREE_L

    RET

DIM_SYN:
    CALL PRINT_SYNTAX_ERROR
    RET
