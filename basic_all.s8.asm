; Sophia BASIC v1
; Aggregate include for all BASIC modules.
;
; This file exists to keep the top-level composition unit (sophia_basic_v1.s8.asm)
; small and stable. If you add/remove BASIC modules, do it here.

.include "basic_errors.s8.asm"
.include "basic_helpers.s8.asm"
.include "basic_vars.s8.asm"
.include "basic_strfn.s8.asm"
.include "basic_expr.s8.asm"

; Core RNG helpers (library) + BASIC-specific RNG glue
.include "rng.s8.asm"
.include "basic_rng.s8.asm"

.include "basic_assign.s8.asm"
.include "basic_io.s8.asm"
.include "basic_flow.s8.asm"
.include "basic_data.s8.asm"
.include "basic_stmt.s8.asm"
.include "basic_progstore.s8.asm"
.include "basic_repl.s8.asm"
.include "basic_data_cmd.s8.asm"
.include "basic_array.s8.asm"
.include "basic_init.s8.asm"
