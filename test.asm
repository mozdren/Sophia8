; ---------------------------------------------------------------------------------------------------
;
;  This is a test assembly code for sophia8 8-bit virtual computer with 16-bit addressing
;
; ---------------------------------------------------------------------------------------------------

some_data:  DB 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08  ; data bytes hexa numbers
hello_s:    DB "Hello, World!"                                       ; data bytes as string
hello_s2:   DB "Hello, World!","Hello, Karel!"                       ; data bytes as string
hello_ch:   DB 'H','E','L','L','O',',',' ','W','O','R','L','D','!',0 ; data bytes characters
numbers:    DB 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15     ; data bytes numbers
mixed:      DB 1, 'A', "test", 0xFA, ','                             ; data bytes mixed
string_spc: DB "               HELLO                 "               ; data bytes string with spaces
binary:     DB 0b11110000, 0b00001111                                ; data bytes binary data

start2:                                                              ; labels on multiple lines have the same address
                                                                     ; if there are no commands in between ...
start:      SET 0x0A, R0 ; this is a comment
            STORE R0, 0xFFC0
            LOAD 0xFFC0, R1
            SET 0x01, R0
            SET 0x02, R1
            SET 0x03, R2
            SET 0x04, R3
            SET 0x05, R4
            SET 0x06, R5
            SET 0x07, R6
            SET 0x08, R7
            PUSH R0
            PUSH R1
            PUSH R2
            PUSH R3
            PUSH R4
            PUSH R5
            PUSH R6
            PUSH R7
            POP R0
            POP R1
            POP R2
            POP R3
            POP R4
            POP R5
            POP R6
            POP R7
            SET 0x00, R7
            SET 0xFF, R6
            DEC R7
            INC R6
            SET 0xBB, R0
            SET 0xFF, R1
            SET 0xC1, R2
            STORER R0,R1, R2
            CMP R0,0x10
            CMPR R0,R1
            NOP
            SET 0xFF, R0
            SET 0x0A, R1
            STORER R1, R0, R1
            DEC R1
            JNZ R1,0x00, 0x67
            SET 0xAA, R0
            ADD 0x01, R0
            ADD 0xFF, R0
            SET 0x00, R1
            ADDR R0, R1
            CALL procedure
            SET 0x09, R0
            SUB 0x0A, R0
            SET 0x09, R1
            SET 0x0A, R2
            SUBR R1, R2
            SET 0xEE, R1
            MUL 0xEE, R0, R1
            SET 0xEE, R0
            SET 0xEE, R2
            MULR R0, R1, R2
            SET 0x0A, R0
            DIV 0x06, R0, R1
            SET 0x06, R0
            SET 0x0A, R1
            DIVR R0, R1, R2
            SET 0x01, R0
            SHL 0x07, R0
            SHL 0x01, R0
            SET 0x80, R0
            SHR 0x07, R0
            SHR 0x01, R0
            JMP 0xABCD
procedure:  RET
            HALT
