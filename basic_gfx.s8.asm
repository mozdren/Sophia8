; ---------------------------------------------------------------------------
; basic_gfx.s8.asm
;
; Sophia BASIC v1 - graphics statements.
;
; Provides:
;   CMD_CLS
;   CMD_PSET
;   CMD_LINE
;   CMD_RECT
;   CMD_SQUARE
;   CMD_CIRCLE
;
; The graphics backend is a C64-style 320x200 framebuffer at BASIC_GFX_BASE.
; These routines draw directly into that framebuffer using the shared BASIC
; expression parser for argument evaluation.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; CMD_CLS
;   Clear the framebuffer to zero.
; ---------------------------------------------------------------------------
CMD_CLS:
    SET #BASIC_GFX_BASE_H, R1
    SET #BASIC_GFX_BASE_L, R2
    SET #0x23, R6          ; 9000 bytes = 0x2328
    SET #0x28, R7
    SET #0x00, R0
GCLS_LOOP:
    STORER R0, R1, R2
    INC R2
    JNZ R2, GCLS_PTR_OK
    INC R1
GCLS_PTR_OK:
    DEC R7
    JNZ R7, GCLS_LOOP
    DEC R6
    JNZ R6, GCLS_LOOP
    RET

; ---------------------------------------------------------------------------
; CMD_PSET
;   PSET x, y [, color]
; ---------------------------------------------------------------------------
CMD_PSET:
    CALL GFX_PARSE_XY
    CMP R0, #0x01
    JNZ R0, GFX_SYNTAX
    CALL GFX_PARSE_COLOR_OPT
    CALL GFX_PLOT_CURRENT
    RET

; ---------------------------------------------------------------------------
; CMD_LINE
;   LINE x1, y1, x2, y2 [, color]
; ---------------------------------------------------------------------------
CMD_LINE:
    CALL GFX_PARSE_LINE_ARGS
    CMP R0, #0x01
    JNZ R0, GFX_SYNTAX
    CALL GFX_PARSE_COLOR_OPT
    CALL GFX_DRAW_LINE
    RET

; ---------------------------------------------------------------------------
; CMD_RECT
;   RECT x1, y1, x2, y2 [, color]
; ---------------------------------------------------------------------------
CMD_RECT:
    CALL GFX_PARSE_LINE_ARGS
    CMP R0, #0x01
    JNZ R0, GFX_SYNTAX
    CALL GFX_PARSE_COLOR_OPT
    CALL GFX_DRAW_RECT
    RET

; ---------------------------------------------------------------------------
; CMD_SQUARE
;   SQUARE x, y, size [, color]
;   The square is drawn from the top-left corner using `size` as the side
;   length in pixels, so size=8 draws an 8x8 outline.
; ---------------------------------------------------------------------------
CMD_SQUARE:
    CALL GFX_PARSE_XY
    CMP R0, #0x01
    JNZ R0, GFX_SYNTAX
    CALL GFX_EXPECT_COMMA
    CALL EVAL_EXPR
    STORE R6, GFX_DX_H
    STORE R7, GFX_DX_L

    ; x2 = x + size - 1
    LOAD GFX_X1_H, R6
    LOAD GFX_X1_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL ADD16
    DEC R7
    JNC GSQ_X_OK
    DEC R6
GSQ_X_OK:
    STORE R6, GFX_X2_H
    STORE R7, GFX_X2_L

    ; y2 = y + size - 1
    LOAD GFX_Y1_H, R6
    LOAD GFX_Y1_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL ADD16
    DEC R7
    JNC GSQ_Y_OK
    DEC R6
GSQ_Y_OK:
    STORE R6, GFX_Y2_H
    STORE R7, GFX_Y2_L

    CALL GFX_PARSE_COLOR_OPT_AFTER
    CALL GFX_DRAW_RECT
    RET

; ---------------------------------------------------------------------------
; CMD_CIRCLE
;   CIRCLE x, y, radius [, color]
; ---------------------------------------------------------------------------
CMD_CIRCLE:
    CALL GFX_PARSE_XY
    CMP R0, #0x01
    JNZ R0, GFX_SYNTAX
    CALL GFX_EXPECT_COMMA
    CALL EVAL_EXPR
    STORE R6, GFX_DX_H
    STORE R7, GFX_DX_L
    CALL GFX_PARSE_COLOR_OPT
    CALL GFX_DRAW_CIRCLE
    RET

; ---------------------------------------------------------------------------
; Parsing helpers
; ---------------------------------------------------------------------------
GFX_PARSE_XY:
    ; Parse x into GFX_X1 and y into GFX_Y1.
    ; Returns R0=1 on success.
    LOAD CURPTR_H, R1
    LOAD CURPTR_L, R2
    CALL SKIPSP
    STORE R1, CURPTR_H
    STORE R2, CURPTR_L

    CALL EVAL_EXPR
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    CALL GFX_EXPECT_COMMA
    CALL EVAL_EXPR
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    SET #0x01, R0
    RET

GFX_PARSE_LINE_ARGS:
    ; Parse x1,y1,x2,y2 into GFX_X1/Y1/X2/Y2.
    CALL GFX_PARSE_XY
    CMP R0, #0x01
    JNZ R0, GFX_PARSE_LINE_DONE
    CALL GFX_EXPECT_COMMA
    CALL EVAL_EXPR
    STORE R6, GFX_X2_H
    STORE R7, GFX_X2_L
    CALL GFX_EXPECT_COMMA
    CALL EVAL_EXPR
    STORE R6, GFX_Y2_H
    STORE R7, GFX_Y2_L
    SET #0x01, R0
GFX_PARSE_LINE_DONE:
    RET

GFX_EXPECT_COMMA:
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x2C
    JNZ R0, GFX_SYNTAX
    CALL GETCHAR_CUR
    RET

GFX_PARSE_COLOR_OPT:
    ; Optional trailing ", color". If absent, use default foreground color 1.
    CALL SKIPSP_CUR
    CALL PEEKCHAR_CUR
    CMP R0, #0x2C
    JNZ R0, GFX_COLOR_DEFAULT
    CALL GETCHAR_CUR
    CALL EVAL_EXPR
    STORE R7, GFX_COLOR
    RET
GFX_COLOR_DEFAULT:
    SET #0x01, R0
    STORE R0, GFX_COLOR
    RET

GFX_PARSE_COLOR_OPT_AFTER:
    CALL GFX_PARSE_COLOR_OPT
    RET

; ---------------------------------------------------------------------------
; 16-bit helpers
; ---------------------------------------------------------------------------
GFX_SHR16_1:
    ; Logical shift right by one on R4:R5.
    SHR #1, R4
    SET #0x00, R6
    JNC GSHR_HI_OK
    SET #0x01, R6
GSHR_HI_OK:
    SHR #1, R5
    SET #0x00, R7
    JNC GSHR_LO_OK
    SET #0x01, R7
GSHR_LO_OK:
    JZ R6, GSHR_DONE
    ADD #0x80, R5
GSHR_DONE:
    RET

; ---------------------------------------------------------------------------
; Pixel plotting
; ---------------------------------------------------------------------------
GFX_PLOT_CURRENT:
    ; Draw the pixel at GFX_X1/Y1 using GFX_COLOR.
    ; This routine assumes the framebuffer is already initialized.

    ; xrem = x mod 8
    LOAD GFX_X1_H, R4
    LOAD GFX_X1_L, R5
    SET #0x00, R6
    SET #0x08, R7
    CALL MOD16U
    STORE R7, GFX_AXIS          ; x remainder (0..7)

    ; yrem = y mod 8
    LOAD GFX_Y1_H, R4
    LOAD GFX_Y1_L, R5
    SET #0x00, R6
    SET #0x08, R7
    CALL MOD16U
    STORE R7, GFX_TMP_H         ; y remainder (0..7)

    ; xcell = x >> 3
    LOAD GFX_X1_H, R4
    LOAD GFX_X1_L, R5
    CALL GFX_SHR16_1
    CALL GFX_SHR16_1
    CALL GFX_SHR16_1
    STORE R5, GFX_CELL_X

    ; ycell = y >> 3
    LOAD GFX_Y1_H, R4
    LOAD GFX_Y1_L, R5
    CALL GFX_SHR16_1
    CALL GFX_SHR16_1
    CALL GFX_SHR16_1
    STORE R5, GFX_CELL_Y

    ; row_offset = ycell * 40 * 9
    SET #0x00, R4
    LOAD GFX_CELL_Y, R5
    SET #0x00, R6
    SET #40, R7
    CALL MUL16U
    SET #0x00, R4
    ADDR R6, R4
    SET #0x00, R5
    ADDR R7, R5
    SET #0x00, R6
    SET #9, R7
    CALL MUL16U
    PUSH R6
    PUSH R7

    ; cellcol = xcell * 9
    SET #0x00, R4
    LOAD GFX_CELL_X, R5
    SET #0x00, R6
    SET #9, R7
    CALL MUL16U

    ; add row_offset + cellcol
    POP R5
    POP R4
    CALL ADD16
    SET #BASIC_GFX_BASE_H, R4
    SET #BASIC_GFX_BASE_L, R5
    CALL ADD16

    ; Copy cell base to R0:R1 for the row byte address.
    SET #0x00, R0
    ADDR R6, R0
    SET #0x00, R1
    ADDR R7, R1

    ; add yrem to the bitmap row address
    LOAD GFX_TMP_H, R2
    ADDR R2, R1
    JNC GPL_ROW_OK
    INC R0
GPL_ROW_OK:
    LOADR R2, R0, R1

    ; build a bit mask from xrem while preserving the loaded byte.
    STORE R2, GFX_TMP_L
    SET #0x80, R3
    LOAD GFX_AXIS, R2
GPL_MASK_LOOP:
    JZ R2, GPL_MASK_DONE
    SHR #1, R3
    DEC R2
    JMP GPL_MASK_LOOP
GPL_MASK_DONE:
    LOAD GFX_TMP_L, R2
    ADDR R3, R2
    STORER R2, R0, R1

    ; write the color nibble into the cell's color byte
    SET #0x00, R0
    ADDR R6, R0
    SET #0x00, R1
    ADDR R7, R1
    ADD #8, R1
    JNC GPL_COLOR_OK
    INC R0
GPL_COLOR_OK:
    LOAD GFX_COLOR, R2
    SHL #4, R2
    STORER R2, R0, R1
    RET

; ---------------------------------------------------------------------------
; Line / rect drawing
; ---------------------------------------------------------------------------
GFX_DRAW_LINE:
    ; Fast path for axis-aligned lines used by RECT/SQUARE and the graphics test.
    LOAD GFX_X1_H, R0
    LOAD GFX_X2_H, R1
    SUBR R1, R0
    JNZ R0, GDL_CHECK_HLINE
    LOAD GFX_X1_L, R0
    LOAD GFX_X2_L, R1
    SUBR R1, R0
    JZ R0, GDL_SIMPLE_VLINE
GDL_CHECK_HLINE:
    LOAD GFX_Y1_H, R0
    LOAD GFX_Y2_H, R1
    SUBR R1, R0
    JNZ R0, GDL_DETAILED_LINE
    LOAD GFX_Y1_L, R0
    LOAD GFX_Y2_L, R1
    SUBR R1, R0
    JZ R0, GDL_SIMPLE_HLINE
GDL_DETAILED_LINE:
    ; Determine dx/sx.
    LOAD GFX_X1_H, R0
    LOAD GFX_X1_L, R1
    LOAD GFX_X2_H, R2
    LOAD GFX_X2_L, R3
    SET #0x00, R4
    ADDR R0, R4
    CMPR R4, R2
    JC GDL_X1_LE_X2
    JNZ R4, GDL_X1_GT_X2
    SET #0x00, R4
    ADDR R1, R4
    CMPR R4, R3
    JC GDL_X1_LE_X2
    JZ R4, GDL_X_EQ
GDL_SIMPLE_HLINE:
    CALL GFX_PLOT_CURRENT
    LOAD GFX_X1_H, R0
    LOAD GFX_X2_H, R1
    SUBR R1, R0
    JNZ R0, GDL_HSTEP
    LOAD GFX_X1_L, R0
    LOAD GFX_X2_L, R1
    SUBR R1, R0
    JZ R0, GDL_LINE_DONE
GDL_HSTEP:
    LOAD GFX_X1_H, R0
    LOAD GFX_X2_H, R1
    CMPR R0, R1
    JC GDL_HINC
    JNZ R0, GDL_HDEC
    LOAD GFX_X1_L, R0
    LOAD GFX_X2_L, R1
    CMPR R0, R1
    JC GDL_HINC
GDL_HDEC:
    LOAD GFX_X1_H, R0
    LOAD GFX_X1_L, R2
    DEC R2
    JNC GDL_HDEC_OK
    DEC R0
GDL_HDEC_OK:
    STORE R0, GFX_X1_H
    STORE R2, GFX_X1_L
    JMP GDL_SIMPLE_HLINE
GDL_HINC:
    LOAD GFX_X1_H, R0
    LOAD GFX_X1_L, R2
    INC R2
    JNZ R2, GDL_HINC_OK
    INC R0
GDL_HINC_OK:
    STORE R0, GFX_X1_H
    STORE R2, GFX_X1_L
    JMP GDL_SIMPLE_HLINE

GDL_SIMPLE_VLINE:
    CALL GFX_PLOT_CURRENT
    LOAD GFX_Y1_H, R0
    LOAD GFX_Y2_H, R1
    SUBR R1, R0
    JNZ R0, GDL_VSTEP
    LOAD GFX_Y1_L, R0
    LOAD GFX_Y2_L, R1
    SUBR R1, R0
    JZ R0, GDL_LINE_DONE
GDL_VSTEP:
    LOAD GFX_Y1_H, R0
    LOAD GFX_Y2_H, R1
    CMPR R0, R1
    JC GDL_VINC
    JNZ R0, GDL_VDEC
    LOAD GFX_Y1_L, R0
    LOAD GFX_Y2_L, R1
    CMPR R0, R1
    JC GDL_VINC
GDL_VDEC:
    LOAD GFX_Y1_H, R0
    LOAD GFX_Y1_L, R2
    DEC R2
    JNC GDL_VDEC_OK
    DEC R0
GDL_VDEC_OK:
    STORE R0, GFX_Y1_H
    STORE R2, GFX_Y1_L
    JMP GDL_SIMPLE_VLINE
GDL_VINC:
    LOAD GFX_Y1_H, R0
    LOAD GFX_Y1_L, R2
    INC R2
    JNZ R2, GDL_VINC_OK
    INC R0
GDL_VINC_OK:
    STORE R0, GFX_Y1_H
    STORE R2, GFX_Y1_L
    JMP GDL_SIMPLE_VLINE

GDL_LINE_DONE:
    RET

GDL_X1_GT_X2:
    LOAD GFX_X1_H, R6
    LOAD GFX_X1_L, R7
    LOAD GFX_X2_H, R4
    LOAD GFX_X2_L, R5
    CALL SUB16
    STORE R6, GFX_DX_H
    STORE R7, GFX_DX_L
    SET #0x00, R0
    STORE R0, GFX_SX
    JMP GDL_Y_START
GDL_X1_LE_X2:
    LOAD GFX_X2_H, R6
    LOAD GFX_X2_L, R7
    LOAD GFX_X1_H, R4
    LOAD GFX_X1_L, R5
    CALL SUB16
    STORE R6, GFX_DX_H
    STORE R7, GFX_DX_L
    SET #0x01, R0
    STORE R0, GFX_SX
GDL_X_EQ:

GDL_Y_START:
    ; Determine dy/sy.
    LOAD GFX_Y1_H, R0
    LOAD GFX_Y1_L, R1
    LOAD GFX_Y2_H, R2
    LOAD GFX_Y2_L, R3
    SET #0x00, R4
    ADDR R0, R4
    CMPR R4, R2
    JC GDL_Y1_LE_Y2
    JNZ R4, GDL_Y1_GT_Y2
    SET #0x00, R4
    ADDR R1, R4
    CMPR R4, R3
    JC GDL_Y1_LE_Y2
    JZ R4, GDL_Y_EQ
GDL_Y1_GT_Y2:
    LOAD GFX_Y1_H, R6
    LOAD GFX_Y1_L, R7
    LOAD GFX_Y2_H, R4
    LOAD GFX_Y2_L, R5
    CALL SUB16
    STORE R6, GFX_DY_H
    STORE R7, GFX_DY_L
    SET #0x00, R0
    STORE R0, GFX_SY
    JMP GDL_ERR_INIT
GDL_Y1_LE_Y2:
    LOAD GFX_Y2_H, R6
    LOAD GFX_Y2_L, R7
    LOAD GFX_Y1_H, R4
    LOAD GFX_Y1_L, R5
    CALL SUB16
    STORE R6, GFX_DY_H
    STORE R7, GFX_DY_L
    SET #0x01, R0
    STORE R0, GFX_SY
GDL_Y_EQ:

GDL_ERR_INIT:
    LOAD GFX_DX_H, R6
    LOAD GFX_DX_L, R7
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CALL SUB16
    STORE R6, GFX_ERR_H
    STORE R7, GFX_ERR_L

GDL_LOOP:
    ; if current == target, plot once and stop
    LOAD GFX_X1_H, R0
    LOAD GFX_X2_H, R1
    SUBR R1, R0
    JNZ R0, GDL_STEP
    LOAD GFX_X1_L, R0
    LOAD GFX_X2_L, R1
    SUBR R1, R0
    JNZ R0, GDL_STEP
    LOAD GFX_Y1_H, R0
    LOAD GFX_Y2_H, R1
    SUBR R1, R0
    JNZ R0, GDL_STEP
    LOAD GFX_Y1_L, R0
    LOAD GFX_Y2_L, R1
    SUBR R1, R0
    JNZ R0, GDL_STEP
    CALL GFX_PLOT_CURRENT
    RET

GDL_STEP:
    ; e2 = err + err
    LOAD GFX_ERR_H, R6
    LOAD GFX_ERR_L, R7
    LOAD GFX_ERR_H, R4
    LOAD GFX_ERR_L, R5
    CALL ADD16

    ; xstep flag in R0
    SET #0x00, R0
    CMP R6, #0x80
    JNC GDL_XSTEP_NEG
    SET #0x01, R0
    JMP GDL_XSTEP_DONE
GDL_XSTEP_NEG:
    ; negative: xstep if abs(e2) < dy
    SET #0x00, R0
    CALL NEG16
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CMPR R6, R4
    JC GDL_XSTEP_TRUE
    JNZ R6, GDL_XSTEP_DONE
    CMPR R7, R5
    JC GDL_XSTEP_TRUE
    JMP GDL_XSTEP_DONE
GDL_XSTEP_TRUE:
    SET #0x01, R0
GDL_XSTEP_DONE:

    ; ystep flag in R1
    SET #0x00, R1
    CMP R6, #0x80
    JNC GDL_YSTEP_NEG
    ; non-negative: ystep if e2 < dx
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CMPR R6, R4
    JC GDL_YSTEP_TRUE
    JNZ R6, GDL_FLAGS_DONE
    CMPR R7, R5
    JC GDL_YSTEP_TRUE
    JMP GDL_FLAGS_DONE
GDL_YSTEP_NEG:
    SET #0x01, R1
    JMP GDL_FLAGS_DONE
GDL_YSTEP_TRUE:
    SET #0x01, R1
GDL_FLAGS_DONE:
    PUSH R1
    PUSH R0
    CALL GFX_PLOT_CURRENT
    POP R0
    POP R1

    ; apply x step if requested
    CMP R0, #0x01
    JNZ R0, GDL_X_SKIP_STEP
    LOAD GFX_ERR_H, R6
    LOAD GFX_ERR_L, R7
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CALL SUB16
    STORE R6, GFX_ERR_H
    STORE R7, GFX_ERR_L
    LOAD GFX_SX, R0
    CMP R0, #0x01
    JZ R0, GDL_X_INC
    LOAD GFX_X1_H, R0
    LOAD GFX_X1_L, R2
    DEC R2
    JNC GDL_X_DEC_OK
    DEC R0
GDL_X_DEC_OK:
    STORE R0, GFX_X1_H
    STORE R2, GFX_X1_L
    JMP GDL_X_SKIP_STEP
GDL_X_INC:
    LOAD GFX_X1_H, R0
    LOAD GFX_X1_L, R2
    INC R2
    JNZ R2, GDL_X_INC_OK
    INC R0
GDL_X_INC_OK:
    STORE R0, GFX_X1_H
    STORE R2, GFX_X1_L
GDL_X_SKIP_STEP:

    ; apply y step if requested
    CMP R1, #0x01
    JNZ R1, GDL_Y_SKIP_STEP
    LOAD GFX_ERR_H, R6
    LOAD GFX_ERR_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL ADD16
    STORE R6, GFX_ERR_H
    STORE R7, GFX_ERR_L
    LOAD GFX_SY, R0
    CMP R0, #0x01
    JZ R0, GDL_Y_INC
    LOAD GFX_Y1_H, R0
    LOAD GFX_Y1_L, R2
    DEC R2
    JNC GDL_Y_DEC_OK
    DEC R0
GDL_Y_DEC_OK:
    STORE R0, GFX_Y1_H
    STORE R2, GFX_Y1_L
    JMP GDL_LOOP
GDL_Y_INC:
    LOAD GFX_Y1_H, R0
    LOAD GFX_Y1_L, R2
    INC R2
    JNZ R2, GDL_Y_INC_OK
    INC R0
GDL_Y_INC_OK:
    STORE R0, GFX_Y1_H
    STORE R2, GFX_Y1_L
    JMP GDL_LOOP
GDL_Y_SKIP_STEP:
    JMP GDL_LOOP

GFX_DRAW_RECT:
    ; Preserve the original rectangle bounds before line drawing mutates them.
    LOAD GFX_X1_H, R0
    STORE R0, GFX_RECT_X1_H
    LOAD GFX_X1_L, R0
    STORE R0, GFX_RECT_X1_L
    LOAD GFX_Y1_H, R0
    STORE R0, GFX_RECT_Y1_H
    LOAD GFX_Y1_L, R0
    STORE R0, GFX_RECT_Y1_L
    LOAD GFX_X2_H, R0
    STORE R0, GFX_RECT_X2_H
    LOAD GFX_X2_L, R0
    STORE R0, GFX_RECT_X2_L
    LOAD GFX_Y2_H, R0
    STORE R0, GFX_RECT_Y2_H
    LOAD GFX_Y2_L, R0
    STORE R0, GFX_RECT_Y2_L

    ; Top edge: (x1, y1) -> (x2, y1)
    LOAD GFX_RECT_X1_H, R0
    STORE R0, GFX_X1_H
    LOAD GFX_RECT_X1_L, R0
    STORE R0, GFX_X1_L
    LOAD GFX_RECT_Y1_H, R0
    STORE R0, GFX_Y1_H
    LOAD GFX_RECT_Y1_L, R0
    STORE R0, GFX_Y1_L
    LOAD GFX_RECT_X2_H, R0
    STORE R0, GFX_X2_H
    LOAD GFX_RECT_X2_L, R0
    STORE R0, GFX_X2_L
    LOAD GFX_RECT_Y1_H, R0
    STORE R0, GFX_Y2_H
    LOAD GFX_RECT_Y1_L, R0
    STORE R0, GFX_Y2_L
    CALL GFX_DRAW_LINE

    ; Bottom edge: (x1, y2) -> (x2, y2)
    LOAD GFX_RECT_X1_H, R0
    STORE R0, GFX_X1_H
    LOAD GFX_RECT_X1_L, R0
    STORE R0, GFX_X1_L
    LOAD GFX_RECT_X2_H, R0
    STORE R0, GFX_X2_H
    LOAD GFX_RECT_X2_L, R0
    STORE R0, GFX_X2_L
    LOAD GFX_RECT_Y2_H, R0
    STORE R0, GFX_Y1_H
    LOAD GFX_RECT_Y2_L, R0
    STORE R0, GFX_Y1_L
    LOAD GFX_RECT_Y2_H, R0
    STORE R0, GFX_Y2_H
    LOAD GFX_RECT_Y2_L, R0
    STORE R0, GFX_Y2_L
    CALL GFX_DRAW_LINE

    ; Left edge: (x1, y1+1) -> (x1, y2-1)
    LOAD GFX_RECT_X1_H, R0
    STORE R0, GFX_X1_H
    LOAD GFX_RECT_X1_L, R0
    STORE R0, GFX_X1_L
    STORE R0, GFX_X2_L
    LOAD GFX_RECT_X1_H, R0
    STORE R0, GFX_X2_H
    LOAD GFX_RECT_Y1_H, R0
    STORE R0, GFX_Y1_H
    LOAD GFX_RECT_Y1_L, R1
    INC R1
    JNZ R1, GDR_LY_OK
    INC R0
GDR_LY_OK:
    STORE R0, GFX_Y1_H
    STORE R1, GFX_Y1_L
    LOAD GFX_RECT_Y2_H, R0
    STORE R0, GFX_Y2_H
    LOAD GFX_RECT_Y2_L, R1
    DEC R1
    JNC GDR_LY2_OK
    DEC R0
GDR_LY2_OK:
    STORE R0, GFX_Y2_H
    STORE R1, GFX_Y2_L
    CALL GFX_DRAW_LINE

    ; Right edge: (x2, y1+1) -> (x2, y2-1)
    LOAD GFX_RECT_X2_H, R0
    STORE R0, GFX_X1_H
    LOAD GFX_RECT_X2_L, R0
    STORE R0, GFX_X1_L
    STORE R0, GFX_X2_L
    LOAD GFX_RECT_X2_H, R0
    STORE R0, GFX_X2_H
    LOAD GFX_RECT_Y1_H, R0
    STORE R0, GFX_Y1_H
    LOAD GFX_RECT_Y1_L, R1
    INC R1
    JNZ R1, GDR_RY_OK
    INC R0
GDR_RY_OK:
    STORE R0, GFX_Y1_H
    STORE R1, GFX_Y1_L
    LOAD GFX_RECT_Y2_H, R0
    STORE R0, GFX_Y2_H
    LOAD GFX_RECT_Y2_L, R1
    DEC R1
    JNC GDR_RY2_OK
    DEC R0
GDR_RY2_OK:
    STORE R0, GFX_Y2_H
    STORE R1, GFX_Y2_L
    CALL GFX_DRAW_LINE
    RET

; ---------------------------------------------------------------------------
; Circle drawing
; ---------------------------------------------------------------------------
GFX_DRAW_CIRCLE:
    ; Center is in GFX_X1/Y1; radius is in GFX_DX.
    ; We keep the center in GFX_X2/Y2 and use GFX_DX/GFX_DY as the current
    ; midpoint offsets (x/y) during rasterization.
    LOAD GFX_X1_H, R0
    STORE R0, GFX_X2_H
    LOAD GFX_X1_L, R0
    STORE R0, GFX_X2_L
    LOAD GFX_Y1_H, R0
    STORE R0, GFX_Y2_H
    LOAD GFX_Y1_L, R0
    STORE R0, GFX_Y2_L

    ; x = radius, y = 0
    LOAD GFX_DX_H, R0
    STORE R0, GFX_DX_H
    LOAD GFX_DX_L, R0
    STORE R0, GFX_DX_L
    SET #0x00, R0
    STORE R0, GFX_DY_H
    STORE R0, GFX_DY_L

    ; err = 1 - radius
    SET #0x00, R6
    SET #0x01, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    STORE R6, GFX_ERR_H
    STORE R7, GFX_ERR_L

GDC_LOOP:
    CALL GFX_DRAW_CIRCLE_SYMS

    ; stop when x < y
    LOAD GFX_DX_H, R0
    LOAD GFX_DX_L, R1
    LOAD GFX_DY_H, R2
    LOAD GFX_DY_L, R3
    SET #0x00, R4
    ADDR R0, R4
    CMPR R4, R2
    JC GDC_DONE
    JNZ R4, GDC_STEP
    SET #0x00, R4
    ADDR R1, R4
    CMPR R4, R3
    JC GDC_DONE

GDC_STEP:
    ; y++
    LOAD GFX_DY_H, R0
    LOAD GFX_DY_L, R1
    INC R1
    JNZ R1, GDC_Y_OK
    INC R0
GDC_Y_OK:
    STORE R0, GFX_DY_H
    STORE R1, GFX_DY_L

    ; if err < 0 then err += 2*y + 1 else x-- and err += 2*(y - x) + 1
    LOAD GFX_ERR_H, R0
    CMP R0, #0x80
    JNC GDC_ERR_NONNEG

    ; err negative: delta = 2*y + 1
    LOAD GFX_DY_H, R6
    LOAD GFX_DY_L, R7
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CALL ADD16
    SET #0x00, R4
    SET #0x01, R5
    CALL ADD16
    PUSH R6
    PUSH R7
    LOAD GFX_ERR_H, R6
    LOAD GFX_ERR_L, R7
    POP R4
    POP R5
    CALL ADD16
    STORE R6, GFX_ERR_H
    STORE R7, GFX_ERR_L
    JMP GDC_LOOP

GDC_ERR_NONNEG:
    ; x--
    LOAD GFX_DX_H, R0
    LOAD GFX_DX_L, R1
    DEC R1
    JNC GDC_X_OK
    DEC R0
GDC_X_OK:
    STORE R0, GFX_DX_H
    STORE R1, GFX_DX_L

    ; delta = 2*(y - x) + 1
    LOAD GFX_DY_H, R6
    LOAD GFX_DY_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    SET #0x00, R4
    ADDR R6, R4
    SET #0x00, R5
    ADDR R7, R5
    CALL ADD16
    SET #0x00, R4
    SET #0x01, R5
    CALL ADD16
    PUSH R6
    PUSH R7
    LOAD GFX_ERR_H, R6
    LOAD GFX_ERR_L, R7
    POP R4
    POP R5
    CALL ADD16
    STORE R6, GFX_ERR_H
    STORE R7, GFX_ERR_L
    JMP GDC_LOOP

GDC_DONE:
    RET

GFX_DRAW_CIRCLE_SYMS:
    ; Unique symmetry set for current offsets in GFX_DX/GFX_DY.
    ; If y == 0, draw four cardinal points.
    LOAD GFX_DY_H, R0
    CMP R0, #0x00
    JNZ R0, GCS_NOT_Y0
    LOAD GFX_DY_L, R0
    CMP R0, #0x00
    JNZ R0, GCS_NOT_Y0
    CALL GFX_CIRCLE_PLOT_Y0
    RET

GCS_NOT_Y0:
    ; If x == y, draw four diagonal points.
    LOAD GFX_DX_H, R0
    LOAD GFX_DY_H, R1
    CMPR R0, R1
    JNZ R0, GCS_FULL
    LOAD GFX_DX_L, R0
    LOAD GFX_DY_L, R1
    CMPR R0, R1
    JNZ R0, GCS_FULL
    CALL GFX_CIRCLE_PLOT_XEQY
    RET

GCS_FULL:
    CALL GFX_CIRCLE_PLOT_8
    RET

GFX_CIRCLE_PLOT_Y0:
    ; Points: (cx +/- x, cy) and (cx, cy +/- x)
    ; cx + x
    LOAD GFX_X2_H, R4
    LOAD GFX_X2_L, R5
    LOAD GFX_DX_H, R6
    LOAD GFX_DX_L, R7
    CALL ADD16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R0
    STORE R0, GFX_Y1_H
    LOAD GFX_Y2_L, R0
    STORE R0, GFX_Y1_L
    CALL GFX_PLOT_CURRENT

    ; cx - x
    LOAD GFX_X2_H, R6
    LOAD GFX_X2_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    CALL GFX_PLOT_CURRENT

    ; cx, cy + x
    LOAD GFX_X2_H, R0
    STORE R0, GFX_X1_H
    LOAD GFX_X2_L, R0
    STORE R0, GFX_X1_L
    LOAD GFX_Y2_H, R4
    LOAD GFX_Y2_L, R5
    LOAD GFX_DX_H, R6
    LOAD GFX_DX_L, R7
    CALL ADD16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT

    ; cx, cy - x
    LOAD GFX_Y2_H, R6
    LOAD GFX_Y2_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT
    RET

GFX_CIRCLE_PLOT_XEQY:
    ; Points: (cx +/- x, cy +/- y) where x == y
    ; cx + x, cy + y
    LOAD GFX_X2_H, R4
    LOAD GFX_X2_L, R5
    LOAD GFX_DX_H, R6
    LOAD GFX_DX_L, R7
    CALL ADD16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R4
    LOAD GFX_Y2_L, R5
    LOAD GFX_DY_H, R6
    LOAD GFX_DY_L, R7
    CALL ADD16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT

    ; cx - x, cy + y
    LOAD GFX_X2_H, R6
    LOAD GFX_X2_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    CALL GFX_PLOT_CURRENT

    ; cx + x, cy - y
    LOAD GFX_X2_H, R4
    LOAD GFX_X2_L, R5
    LOAD GFX_DX_H, R6
    LOAD GFX_DX_L, R7
    CALL ADD16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R6
    LOAD GFX_Y2_L, R7
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CALL SUB16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT

    ; cx - x, cy - y
    LOAD GFX_X2_H, R6
    LOAD GFX_X2_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R6
    LOAD GFX_Y2_L, R7
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CALL SUB16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT
    RET

GFX_CIRCLE_PLOT_8:
    ; cx + x, cy + y
    LOAD GFX_X2_H, R4
    LOAD GFX_X2_L, R5
    LOAD GFX_DX_H, R6
    LOAD GFX_DX_L, R7
    CALL ADD16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R4
    LOAD GFX_Y2_L, R5
    LOAD GFX_DY_H, R6
    LOAD GFX_DY_L, R7
    CALL ADD16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT

    ; cx - x, cy + y
    LOAD GFX_X2_H, R6
    LOAD GFX_X2_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    CALL GFX_PLOT_CURRENT

    ; cx + x, cy - y
    LOAD GFX_X2_H, R4
    LOAD GFX_X2_L, R5
    LOAD GFX_DX_H, R6
    LOAD GFX_DX_L, R7
    CALL ADD16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R6
    LOAD GFX_Y2_L, R7
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CALL SUB16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT

    ; cx - x, cy - y
    LOAD GFX_X2_H, R6
    LOAD GFX_X2_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R6
    LOAD GFX_Y2_L, R7
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CALL SUB16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT

    ; cx + y, cy + x
    LOAD GFX_X2_H, R4
    LOAD GFX_X2_L, R5
    LOAD GFX_DY_H, R6
    LOAD GFX_DY_L, R7
    CALL ADD16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R4
    LOAD GFX_Y2_L, R5
    LOAD GFX_DX_H, R6
    LOAD GFX_DX_L, R7
    CALL ADD16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT

    ; cx - y, cy + x
    LOAD GFX_X2_H, R6
    LOAD GFX_X2_L, R7
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CALL SUB16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    CALL GFX_PLOT_CURRENT

    ; cx + y, cy - x
    LOAD GFX_X2_H, R4
    LOAD GFX_X2_L, R5
    LOAD GFX_DY_H, R6
    LOAD GFX_DY_L, R7
    CALL ADD16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R6
    LOAD GFX_Y2_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT

    ; cx - y, cy - x
    LOAD GFX_X2_H, R6
    LOAD GFX_X2_L, R7
    LOAD GFX_DY_H, R4
    LOAD GFX_DY_L, R5
    CALL SUB16
    STORE R6, GFX_X1_H
    STORE R7, GFX_X1_L
    LOAD GFX_Y2_H, R6
    LOAD GFX_Y2_L, R7
    LOAD GFX_DX_H, R4
    LOAD GFX_DX_L, R5
    CALL SUB16
    STORE R6, GFX_Y1_H
    STORE R7, GFX_Y1_L
    CALL GFX_PLOT_CURRENT
    RET

GFX_SYNTAX:
    CALL PRINT_SYNTAX_ERROR
    RET
