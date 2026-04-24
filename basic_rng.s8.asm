; basic_rng.s8.asm
; BASIC-specific RNG wrapper extracted from sophia_basic_v1.s8.asm.
;
; Provides:
;   RNG_NEXT
;     Uses BASIC's fixed seed variables RNG_SEED_H/RNG_SEED_L (defined in basic_state.s8.asm)
;     and returns a pseudo-random value in R6:R7 (0..32767).
;
; Depends on:
;   rng.s8.asm (RNG_NEXT16)
;   16-bit helpers: ADD16, MUL16U
;
; NOTE: Sophia8 assembler currently has limited support for computing label addresses.
;       We therefore use the fixed address of RNG_SEED_H (0x681F), which is defined
;       by the layout in basic_state.s8.asm.

RNG_NEXT:
    ; point R1:R2 at RNG_SEED_H (0x681F)
    SET #0x68, R1
    SET #0x1F, R2
    CALL RNG_NEXT16
    RET
