; ---------------------------------------------------------------------------
; Sophia BASIC: fixed-address strings + keyword strings
;
; Purpose:
;   Keep all user-visible messages and keyword text in one place.
;   These strings intentionally live at stable, fixed addresses so the BASIC
;   runtime can reference them cheaply (direct address constants) and so that
;   debug tooling can rely on deterministic layouts.
;
; Notes:
;   - Do NOT change the .org addresses unless you also update all call sites.
;   - Strings use the assembler's .string directive (NUL-terminated).
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Fixed-address strings
; ---------------------------------------------------------------------------
.org STR_BANNER
Banner: .string "        Sophia Basic v.1 (2026)\n            by Karel Mozdren\n"
.org STR_PROMPT
Prompt: .string "> "
.org STR_NL
NL: .string "\n"
.org STR_ERR_SYNTAX
ErrSyntax: .string "?SYNTAX ERROR\n"
.org STR_ERR_NOPROG
ErrNoProg: .string "?NO PROGRAM\n"
.org STR_ERR_UNDEFLINE
ErrUndefLine: .string "?UNDEFINED LINE\n"

; ---------------------------------------------------------------------------
; Keywords at stable addresses
; ---------------------------------------------------------------------------
.org KW_NEW
K_NEW:   .string "NEW"
.org KW_LIST
K_LIST:  .string "LIST"
.org KW_RUN
K_RUN:   .string "RUN"
.org KW_PRINT
K_PRINT: .string "PRINT"
.org KW_GOTO
K_GOTO:  .string "GOTO"
.org KW_IF
K_IF:    .string "IF"
.org KW_THEN
K_THEN:  .string "THEN"
.org KW_END
K_END:   .string "END"
.org KW_STOP
K_STOP:  .string "STOP"

.org KW_LET
K_LET:   .string "LET"

; Phase 5 keywords
.org KW_GOSUB
K_GOSUB: .string "GOSUB"
.org KW_RETURN
K_RETURN:.string "RETURN"
.org KW_FOR
K_FOR:   .string "FOR"
.org KW_TO
K_TO:    .string "TO"
.org KW_STEP
K_STEP:  .string "STEP"
.org KW_NEXT
K_NEXT:  .string "NEXT"
.org KW_INPUT
K_INPUT: .string "INPUT"
.org KW_POKE
K_POKE:  .string "POKE"
.org KW_RANDOMIZE
K_RANDOMIZE: .string "RANDOMIZE"
.org KW_HALT
K_HALT:  .string "HALT"
.org KW_PEEK
K_PEEK:  .string "PEEK"
.org KW_RND
K_RND:   .string "RND"

; Phase 6 keyword
.org KW_ELSE
K_ELSE:  .string "ELSE"

; Phase 7 keyword
.org KW_REM
K_REM:   .string "REM"

; Phase 13 keyword (arrays)
.org KW_DIM
K_DIM:   .string "DIM"

; Phase 14 keywords (DATA / READ / RESTORE)
.org KW_DATA
K_DATA:  .string "DATA"
.org KW_READ
K_READ:  .string "READ"
.org KW_RESTORE
K_RESTORE: .string "RESTORE"

; Phase 15 keywords (loop blocks)
.org KW_DO
K_DO: .string "DO"
.org KW_WHILE
K_WHILE: .string "WHILE"
.org KW_ENDWHILE
K_ENDWHILE: .string "ENDWHILE"

; Phase 14 error
.org STR_ERR_OUTOFDATA
ErrOutOfData: .string "?OUT OF DATA\n"
