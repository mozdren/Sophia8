; ---------------------------------------------------------------------------
; basic_layout.s8.asm
;
; Shared Sophia BASIC layout constants.
;
; Assembly-time constants only. Included by the top-level BASIC composition
; before any code/data modules so later includes can use the same addresses
; symbolically.
; ---------------------------------------------------------------------------

; Core BASIC image layout
.equ BASIC_CODE_BASE,          0x0400  ; low-memory code and kernel helpers
.equ BASIC_CODE_BASE_H,        0x04    ; high byte of BASIC_CODE_BASE
.equ BASIC_CODE_BASE_L,        0x00    ; low byte of BASIC_CODE_BASE
.equ BASIC_STATE_BASE,         0x6800  ; runtime state block
.equ BASIC_STATE_BASE_H,       0x68    ; high byte of BASIC_STATE_BASE
.equ BASIC_STATE_BASE_L,       0x00    ; low byte of BASIC_STATE_BASE
.equ BASIC_TOKENBUF_BASE,      0x6880  ; token buffer used by GETTOKEN
.equ BASIC_TOKENBUF_BASE_H,    0x68    ; high byte of BASIC_TOKENBUF_BASE
.equ BASIC_TOKENBUF_BASE_L,    0x80    ; low byte of BASIC_TOKENBUF_BASE
.equ BASIC_IDBUF_BASE,         0x68A0  ; identifier buffer
.equ BASIC_IDBUF_BASE_H,       0x68    ; high byte of BASIC_IDBUF_BASE
.equ BASIC_IDBUF_BASE_L,       0xA0    ; low byte of BASIC_IDBUF_BASE
.equ BASIC_CLS_STACK_BASE,     0x68B0  ; block classifier stack for DO/WHILE scans
.equ BASIC_CLS_STACK_BASE_H,   0x68    ; high byte of BASIC_CLS_STACK_BASE
.equ BASIC_CLS_STACK_BASE_L,   0xB0    ; low byte of BASIC_CLS_STACK_BASE
.equ BASIC_MATCH_STACK_H_BASE, 0x68C0  ; DO/WHILE pointer stack high bytes
.equ BASIC_MATCH_STACK_H_BASE_H, 0x68  ; high byte of BASIC_MATCH_STACK_H_BASE
.equ BASIC_MATCH_STACK_H_BASE_L, 0xC0  ; low byte of BASIC_MATCH_STACK_H_BASE
.equ BASIC_MATCH_STACK_L_BASE, 0x68D0  ; DO/WHILE pointer stack low bytes
.equ BASIC_MATCH_STACK_L_BASE_H, 0x68  ; high byte of BASIC_MATCH_STACK_L_BASE
.equ BASIC_MATCH_STACK_L_BASE_L, 0xD0  ; low byte of BASIC_MATCH_STACK_L_BASE
.equ BASIC_INPUT_VAR_H_BASE,   0x68E0  ; INPUT target variable high bytes
.equ BASIC_INPUT_VAR_H_BASE_H, 0x68    ; high byte of BASIC_INPUT_VAR_H_BASE
.equ BASIC_INPUT_VAR_H_BASE_L, 0xE0    ; low byte of BASIC_INPUT_VAR_H_BASE
.equ BASIC_INPUT_VAR_L_BASE,   0x68E8  ; INPUT target variable low bytes
.equ BASIC_INPUT_VAR_L_BASE_H, 0x68    ; high byte of BASIC_INPUT_VAR_L_BASE
.equ BASIC_INPUT_VAR_L_BASE_L, 0xE8    ; low byte of BASIC_INPUT_VAR_L_BASE
.equ BASIC_INPUT_VAR_T_BASE,   0x68F0  ; INPUT target variable type bytes
.equ BASIC_INPUT_VAR_T_BASE_H, 0x68    ; high byte of BASIC_INPUT_VAR_T_BASE
.equ BASIC_INPUT_VAR_T_BASE_L, 0xF0    ; low byte of BASIC_INPUT_VAR_T_BASE
.equ BASIC_INPUT_VAR_COUNT_BASE, 0x68F8 ; INPUT bookkeeping counter
.equ BASIC_INPUT_VAR_COUNT_BASE_H, 0x68 ; high byte of BASIC_INPUT_VAR_COUNT_BASE
.equ BASIC_INPUT_VAR_COUNT_BASE_L, 0xF8 ; low byte of BASIC_INPUT_VAR_COUNT_BASE
.equ BASIC_CODE_RESUME,        0x68FA  ; code resumes after runtime state
.equ BASIC_CODE_RESUME_H,      0x68    ; high byte of BASIC_CODE_RESUME
.equ BASIC_CODE_RESUME_L,      0xFA    ; low byte of BASIC_CODE_RESUME
.equ BASIC_UTIL_BASE,          0x43F4  ; free hole after text.s8, before runtime state
.equ BASIC_UTIL_BASE_H,        0x43    ; high byte of BASIC_UTIL_BASE
.equ BASIC_UTIL_BASE_L,        0xF4    ; low byte of BASIC_UTIL_BASE
.equ BASIC_PROG_BASE,          0x6C5A  ; packed program store start
.equ BASIC_PROG_BASE_H,        0x6C    ; high byte of BASIC_PROG_BASE
.equ BASIC_PROG_BASE_L,        0x5A    ; low byte of BASIC_PROG_BASE
.equ BASIC_GOSUB_STACK_BASE,   0x6E00  ; GOSUB return stack
.equ BASIC_GOSUB_STACK_BASE_H, 0x6E    ; high byte of BASIC_GOSUB_STACK_BASE
.equ BASIC_GOSUB_STACK_BASE_L, 0x00    ; low byte of BASIC_GOSUB_STACK_BASE
.equ BASIC_FOR_STACK_BASE,     0x6E20  ; FOR/NEXT frame stack
.equ BASIC_FOR_STACK_BASE_H,   0x6E    ; high byte of BASIC_FOR_STACK_BASE
.equ BASIC_FOR_STACK_BASE_L,   0x20    ; low byte of BASIC_FOR_STACK_BASE

; Runtime scratch / heap
.equ BASIC_STRFREE_BASE,       0xE000  ; string heap start
.equ BASIC_STRFREE_BASE_H,     0xE0    ; high byte of BASIC_STRFREE_BASE
.equ BASIC_STRFREE_BASE_L,     0x00    ; low byte of BASIC_STRFREE_BASE

; Console input buffers
.equ BASIC_CLI_INBUF_BASE,     0xA400  ; live line-edit input buffer
.equ BASIC_CLI_INBUF_BASE_H,   0xA4    ; high byte of BASIC_CLI_INBUF_BASE
.equ BASIC_CLI_INBUF_BASE_L,   0x00    ; low byte of BASIC_CLI_INBUF_BASE
.equ BASIC_CLI_COPY_BASE,      0xA480  ; stable parse copy of the input line
.equ BASIC_CLI_COPY_BASE_H,    0xA4    ; high byte of BASIC_CLI_COPY_BASE
.equ BASIC_CLI_COPY_BASE_L,    0x80    ; low byte of BASIC_CLI_COPY_BASE
.equ BASIC_INPUT_LINE_BASE,    0x6E80  ; INPUT line-edit buffer
.equ BASIC_INPUT_LINE_BASE_H,  0x6E    ; high byte of BASIC_INPUT_LINE_BASE
.equ BASIC_INPUT_LINE_BASE_L,  0x80    ; low byte of BASIC_INPUT_LINE_BASE

; Graphics/text layout
.equ BASIC_GFX_BASE,           0x8000  ; graphics framebuffer start
.equ BASIC_GFX_BASE_H,         0x80    ; high byte of BASIC_GFX_BASE
.equ BASIC_GFX_BASE_L,         0x00    ; low byte of BASIC_GFX_BASE
.equ BASIC_TEXT_CHARSET_BASE,  0xD5CA  ; 8x8 text charset data
.equ BASIC_TEXT_CHARSET_BASE_H, 0xD5   ; high byte of BASIC_TEXT_CHARSET_BASE
.equ BASIC_TEXT_CHARSET_BASE_L, 0xCA   ; low byte of BASIC_TEXT_CHARSET_BASE
.equ BASIC_TEXT_STATE_BASE,    0xD8C5  ; text cursor / mode state
.equ BASIC_TEXT_STATE_BASE_H,  0xD8    ; high byte of BASIC_TEXT_STATE_BASE
.equ BASIC_TEXT_STATE_BASE_L,  0xC5    ; low byte of BASIC_TEXT_STATE_BASE
.equ BASIC_TEXT_BUF_BASE,      0xD8C9  ; 40x25 text console buffer
.equ BASIC_TEXT_BUF_BASE_H,    0xD8    ; high byte of BASIC_TEXT_BUF_BASE
.equ BASIC_TEXT_BUF_BASE_L,    0xC9    ; low byte of BASIC_TEXT_BUF_BASE
.equ BASIC_RNG_SEED_H_ADDR,    0x681F  ; fixed address of RNG_SEED_H
.equ BASIC_RNG_SEED_H_ADDR_H,  0x68    ; high byte of BASIC_RNG_SEED_H_ADDR
.equ BASIC_RNG_SEED_H_ADDR_L,  0x1F    ; low byte of BASIC_RNG_SEED_H_ADDR

; Fixed strings
.equ STR_BANNER,               0x0200  ; startup banner / READY text
.equ STR_BANNER_H,             0x02    ; high byte of STR_BANNER
.equ STR_BANNER_L,             0x00    ; low byte of STR_BANNER
.equ STR_PROMPT,               0x0240  ; REPL prompt string
.equ STR_PROMPT_H,             0x02    ; high byte of STR_PROMPT
.equ STR_PROMPT_L,             0x40    ; low byte of STR_PROMPT
.equ STR_NL,                   0x0244  ; newline string
.equ STR_NL_H,                 0x02    ; high byte of STR_NL
.equ STR_NL_L,                 0x44    ; low byte of STR_NL
.equ STR_ERR_SYNTAX,           0x0248  ; syntax error message
.equ STR_ERR_SYNTAX_H,         0x02    ; high byte of STR_ERR_SYNTAX
.equ STR_ERR_SYNTAX_L,         0x48    ; low byte of STR_ERR_SYNTAX
.equ STR_ERR_NOPROG,           0x0260  ; no-program message
.equ STR_ERR_NOPROG_H,         0x02    ; high byte of STR_ERR_NOPROG
.equ STR_ERR_NOPROG_L,         0x60    ; low byte of STR_ERR_NOPROG
.equ STR_ERR_UNDEFLINE,        0x026E  ; undefined-line message
.equ STR_ERR_UNDEFLINE_H,      0x02    ; high byte of STR_ERR_UNDEFLINE
.equ STR_ERR_UNDEFLINE_L,      0x6E    ; low byte of STR_ERR_UNDEFLINE
.equ STR_ERR_OUTOFDATA,        0x0388  ; out-of-data message
.equ STR_ERR_OUTOFDATA_H,      0x03    ; high byte of STR_ERR_OUTOFDATA
.equ STR_ERR_OUTOFDATA_L,      0x88    ; low byte of STR_ERR_OUTOFDATA

; Keyword strings used by the statement dispatcher
.equ KW_NEW,                   0x0280  ; NEW
.equ KW_NEW_H,                 0x02
.equ KW_NEW_L,                 0x80
.equ KW_LIST,                  0x0288  ; LIST
.equ KW_LIST_H,                0x02
.equ KW_LIST_L,                0x88
.equ KW_RUN,                   0x0290  ; RUN
.equ KW_RUN_H,                 0x02
.equ KW_RUN_L,                 0x90
.equ KW_PRINT,                 0x0298  ; PRINT
.equ KW_PRINT_H,               0x02
.equ KW_PRINT_L,               0x98
.equ KW_GOTO,                  0x02A0  ; GOTO
.equ KW_GOTO_H,                0x02
.equ KW_GOTO_L,                0xA0
.equ KW_IF,                    0x02A8  ; IF
.equ KW_IF_H,                  0x02
.equ KW_IF_L,                  0xA8
.equ KW_THEN,                  0x02B0  ; THEN
.equ KW_THEN_H,                0x02
.equ KW_THEN_L,                0xB0
.equ KW_END,                   0x02B8  ; END
.equ KW_END_H,                 0x02
.equ KW_END_L,                 0xB8
.equ KW_STOP,                  0x02C0  ; STOP
.equ KW_STOP_H,                0x02
.equ KW_STOP_L,                0xC0
.equ KW_LET,                   0x02C8  ; LET
.equ KW_LET_H,                 0x02
.equ KW_LET_L,                 0xC8
.equ KW_GOSUB,                 0x02D0  ; GOSUB
.equ KW_GOSUB_H,               0x02
.equ KW_GOSUB_L,               0xD0
.equ KW_RETURN,                0x02D8  ; RETURN
.equ KW_RETURN_H,              0x02
.equ KW_RETURN_L,              0xD8
.equ KW_FOR,                   0x02E0  ; FOR
.equ KW_FOR_H,                 0x02
.equ KW_FOR_L,                 0xE0
.equ KW_TO,                    0x02E8  ; TO
.equ KW_TO_H,                  0x02
.equ KW_TO_L,                  0xE8
.equ KW_STEP,                  0x02F0  ; STEP
.equ KW_STEP_H,                0x02
.equ KW_STEP_L,                0xF0
.equ KW_NEXT,                  0x02F8  ; NEXT
.equ KW_NEXT_H,                0x02
.equ KW_NEXT_L,                0xF8
.equ KW_INPUT,                 0x0300  ; INPUT
.equ KW_INPUT_H,               0x03
.equ KW_INPUT_L,               0x00
.equ KW_POKE,                  0x0308  ; POKE
.equ KW_POKE_H,                0x03
.equ KW_POKE_L,                0x08
.equ KW_RANDOMIZE,             0x0310  ; RANDOMIZE
.equ KW_RANDOMIZE_H,           0x03
.equ KW_RANDOMIZE_L,           0x10
.equ KW_HALT,                  0x031B  ; HALT
.equ KW_HALT_H,                0x03
.equ KW_HALT_L,                0x1B
.equ KW_PEEK,                  0x0320  ; PEEK
.equ KW_PEEK_H,                0x03
.equ KW_PEEK_L,                0x20
.equ KW_RND,                   0x0328  ; RND
.equ KW_RND_H,                 0x03
.equ KW_RND_L,                 0x28
.equ KW_ELSE,                  0x0330  ; ELSE
.equ KW_ELSE_H,                0x03
.equ KW_ELSE_L,                0x30
.equ KW_REM,                   0x0338  ; REM
.equ KW_REM_H,                 0x03
.equ KW_REM_L,                 0x38
.equ KW_DIM,                   0x0340  ; DIM
.equ KW_DIM_H,                 0x03
.equ KW_DIM_L,                 0x40
.equ KW_DATA,                  0x0348  ; DATA
.equ KW_DATA_H,                0x03
.equ KW_DATA_L,                0x48
.equ KW_READ,                  0x0350  ; READ
.equ KW_READ_H,                0x03
.equ KW_READ_L,                0x50
.equ KW_RESTORE,               0x0358  ; RESTORE
.equ KW_RESTORE_H,             0x03
.equ KW_RESTORE_L,             0x58
.equ KW_DO,                    0x0368  ; DO
.equ KW_DO_H,                  0x03
.equ KW_DO_L,                  0x68
.equ KW_WHILE,                 0x0370  ; WHILE
.equ KW_WHILE_H,               0x03
.equ KW_WHILE_L,               0x70
.equ KW_ENDWHILE,              0x0378  ; ENDWHILE
.equ KW_ENDWHILE_H,            0x03
.equ KW_ENDWHILE_L,            0x78
