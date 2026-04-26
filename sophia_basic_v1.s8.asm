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

; --- BASIC fixed data + state ---
.include "basic_strings.s8.asm"
.include "basic_state.s8.asm"

; Restore the original BASIC code layout after the data-only charset block.
.org 0x68FA

; --- BASIC modules ---
.include "basic_all.s8.asm"

; Keep the shared text helpers out of the low console-state region.
; They are used by the BASIC modules above, but they do not need to live
; before the BASIC state block.
.include "text.s8.asm"

; Charset is packed at the end of the BASIC image so the code block can be
; moved upward and the graphics framebuffer can use the cleared low block.
.include "text_charset.s8.asm"

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
.org
    JMP START
