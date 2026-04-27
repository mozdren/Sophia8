.org 0x0200

.equ TEST_ADDR, 0x4300
.equ MAGIC, 0x2A
.equ MSG_ADDR, 0x4310
.equ MSG_HI, 0x43
.equ MSG_LO, 0x10

.include "kernel.s8.asm"

.org 0x0C00
.org

START:
    SET #MAGIC, R0
    STORE R0, TEST_ADDR
    LOAD TEST_ADDR, R1
    CMP R1, #MAGIC
    JZ R1, EQU_OK
    HALT

EQU_OK:
    SET #MSG_HI, R1
    SET #MSG_LO, R2
    CALL PUTS
    HALT

.org TEST_ADDR
SLOT:
    .byte 0

.org MSG_ADDR
MSG:
    .string "EQU OK"
