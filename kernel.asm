; ------------------------------------------------------------------------------
;
; This is Sophia8 kernel code
;
;      Contains:
;
;      * definitions
;      * memory mappings
;      * kernel methods
;
;-------------------------------------------------------------------------------

                DEF     __VIDEO_MEM, 0xC000
                DEF     __COLOR_MEM, 0xDF40
                DEF     __CONSOLE_X, 0xE000
                DEF     __CONSOLE_Y, 0xE001
                DEF     __CURSOR_ON, 0xE002
                DEF     __VIDEO_MODE, 0xE003
                DEF     __KEY_BUF_SIZE, 0xE004
                DEF     __KEY_BUFFER, 0xE005
                DEF     __CHAR_MEM, 0xE069

                DEF     __COLUMNS, 40
                DEF     __ROWS, 20
                DEF     __VIDEO_WIDTH, 320
                DEF     __VIDEO_HEIGHT, 200
                DEF     __KEY_BUF_MAX_SIZE, 100

                DEF     __BLACK, 0
                DEF     __MARON, 1
                DEF     __GREEN, 2
                DEF     __OLIVE, 3
                DEF     __NAVY, 4
                DEF     __PURPLE, 5
                DEF     __TEAL, 6
                DEF     __SILVER, 7
                DEF     __GRAY, 8
                DEF     __RED, 9
                DEF     __LIME, 10
                DEF     __YELLOW, 11
                DEF     __BLUE, 12
                DEF     __FUCHSIA, 13
                DEF     __AQUA, 14
                DEF     __WHITE, 15

                DEF     __TEXT_MODE, 0
                DEF     __BW_MODE, 1
                DEF     __COLOR_MODE, 2

__VIDEO_MEM:    DB      0[8000]                     ; video memory 320 * 200 (BW)
__COLOR_MEM:    DB      __WHITE[1000]               ; Color Information 8x8 blocks
                                                    ; 0x00001111 - foreground color
                                                    ; 0x11110000 - background color
__CONSOLE_X:    DB      0                           ; Console cursor position X
__CONSOLE_Y:    DB      0                           ; Console cursor position Y
__CURSOR_ON:    DB      0                           ; Cursor ON/OFF
__VIDEO_MODE:   DB      __TEXT_MODE                 ; video mode:
                                                    ;     0-text (40/25)
                                                    ;     1-BW graphics (320/200)
                                                    ;     2-Color Graphics (320/200)
__KEY_BUF_SIZE: DB      0                           ; keyboard buffer size
__KEY_BUFFER:   DB      0[100]                      ; keyboard buffer
__CHAR_MEM:     DB      0[2048]                     ; characters memory 8*8*256

; console input/output methods

__kbhit:        RET                                 ; determines if key was pressed

__cgets:        RET                                 ; reads a string directly from console

__cscanf:       RET                                 ; reads formated values directly from console

__putch:        RET                                 ; writes a character to a console

__cputs:        RET                                 ; writes a string to a console

__cprintf:      RET                                 ; writes formated string to console

__clrsrc:       RET                                 ; clears screen

__getch:        RET                                 ; reads character from keyboard
