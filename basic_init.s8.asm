; ---------------------------------------------------------------------------
; basic_init.s8.asm
;
; Sophia BASIC initialization routines extracted from sophia_basic_v1.s8.asm.
;
; Provides:
;   INIT_VARS  - resets variable table, string heap pointer, RNG seed defaults,
;                and FOR/GOSUB stacks.
;
; Depends on:
;   - basic_state.s8.asm: STRFREE_H/L, RNG_SEED_H/L, GOSUB_SP, FOR_SP
;   - kernel.s8.asm instruction set
;
; Notes:
;   - Variable table is fixed at 0x6000..0x63FF (64 entries * 16 bytes).
;   - An entry is considered empty when its TYPE byte (offset +8) is 0xFF.
; ---------------------------------------------------------------------------

INIT_VARS:
    ; STRFREE = 0xE000
    ; Keep the heap above the relocated BASIC code segments and the
    ; separate text-console buffer. Check the .deb map after code growth
    ; before moving this back down.
    SET #0xE0, R0
    STORE R0, STRFREE_H
    SET #0x00, R0
    STORE R0, STRFREE_L

    ; RNG seed default = 0x1234
    SET #0x12, R0
    STORE R0, RNG_SEED_H
    SET #0x34, R0
    STORE R0, RNG_SEED_L

    ; reset GOSUB / FOR stacks and loop/classifier scratch
    SET #0x00, R0
    STORE R0, GOSUB_SP
    STORE R0, FOR_SP
    STORE R0, CLS_SP
    STORE R0, MATCH_SP
    STORE R0, RUN_PTR_H
    STORE R0, RUN_PTR_L
    STORE R0, RUN_NEXT_H
    STORE R0, RUN_NEXT_L
    STORE R0, MATCH_PTR_H
    STORE R0, MATCH_PTR_L
    STORE R0, SCAN_PTR_H
    STORE R0, SCAN_PTR_L
    STORE R0, DATA_LINE_H
    STORE R0, DATA_LINE_L

    ; mark entries empty by writing 0xFF to type byte of each entry
    SET #0x60, R1
    SET #0x00, R2
    SET #64, R3
IV_LOOP:
    PUSH R1
    PUSH R2

    ; type byte offset
    ADD #8, R2
    JNC IV_T1
    INC R1
IV_T1:
    SET #0xFF, R0
    STORER R0, R1, R2

    POP R2
    POP R1

    ; next entry (+16)
    ADD #16, R2
    JNC IV_NC
    INC R1
IV_NC:
    DEC R3
    JNZ R3, IV_LOOP
    RET
