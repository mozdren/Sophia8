; Sophia Basic v.1 (2026) by Karel Mozdren
; Composition unit (wiring + includes).
; Implementation lives in basic_*.s8.asm modules.

; --- Core libs ---
.org 0x0400
.include "kernel.s8.asm"
.include "cli.s8.asm"
.include "mem.s8.asm"
.include "fmt.s8.asm"
.include "str.s8.asm"
.include "text.s8.asm"

; --- BASIC fixed data + state ---
.include "basic_strings.s8.asm"
.include "basic_state.s8.asm"

; --- BASIC modules ---
.include "basic_all.s8.asm"

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
.org
    JMP START
