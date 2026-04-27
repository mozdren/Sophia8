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
.equ BASIC_PROG_BASE,          0x6C5A  ; packed program store start
.equ BASIC_PROG_BASE_H,        0x6C    ; high byte of BASIC_PROG_BASE
.equ BASIC_PROG_BASE_L,        0x5A    ; low byte of BASIC_PROG_BASE

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
