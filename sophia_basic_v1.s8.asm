; Sophia Basic v.1 (2026) by Karel Mozdren
; Composition unit (wiring + includes).
; Implementation lives in basic_*.s8.asm modules.

; --- Shared layout constants ---
.include "basic_layout.s8.asm"

; --- Core libs ---
.org BASIC_CODE_BASE
.include "kernel.s8.asm"
.include "cli.s8.asm"
.include "mem.s8.asm"
.include "fmt.s8.asm"
.include "str.s8.asm"

; --- BASIC fixed data + state ---
.include "basic_strings.s8.asm"
.include "basic_state.s8.asm"

; Restore the original BASIC code layout after the data-only charset block.
.org BASIC_CODE_RESUME

; --- BASIC modules ---
.include "basic_all.s8.asm"

; Keep the shared text helpers out of the low console-state region.
; They are used by the BASIC modules above, but they do not need to live
; before the BASIC state block.
.include "text.s8.asm"

; Pack the small BASIC utility block into the free hole right after text.s8.
.include "basic_errors.s8.asm"
.include "basic_helpers.s8.asm"
.include "basic_vars.s8.asm"

; Charset is packed at the end of the BASIC image so the code block can be
; moved upward and the graphics framebuffer can use the cleared low block.
.include "text_charset.s8.asm"

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
.org
    JMP START
