import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')
VM = str(ROOT / 'sophia8')


def assemble_and_run(src: str, input_data: bytes = b'') -> str:
    """Assemble given .s8 source and run in VM. Return stdout as text."""
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        s8 = td / 'prog.s8'
        binp = td / 'prog.bin'
        s8.write_text(src, encoding='utf-8')

        subprocess.run([S8ASM, str(s8), '-o', str(binp)], check=True, cwd=str(ROOT), capture_output=True)
        proc = subprocess.run([VM, str(binp)], check=True, cwd=str(ROOT), input=input_data, capture_output=True)
        return proc.stdout.decode('utf-8', errors='replace')


class TestMem(unittest.TestCase):
    def test_memset_memcpy_memmove_memcmp_memchr(self):
        src = r'''
.org 0x0800
.include "/mnt/data/kernel.s8"
.include "/mnt/data/fmt.s8"
.include "/mnt/data/mem.s8"

.org 0x0200
Src1:   .string "hello"
Dst1:   .byte 0,0,0,0,0,0
MovBuf: .string "ABCDE"     ; bytes: A B C D E 0

.org
START:
    ; MEMSET Dst1 with 'X' for 3 bytes then NUL and print
    SET #0x02, R1
    SET #0x06, R2          ; Dst1 @ 0x0206
    SET #0x58, R0          ; 'X'
    SET #3, R3
    CALL MEMSET
    ; write terminator at Dst1+3
    SET #0x02, R1
    SET #0x09, R2
    SET #0x00, R0
    STORER R0, R1, R2
    SET #0x02, R1
    SET #0x06, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; MEMCPY Src1 -> Dst1 (len=6 includes NUL), print
    SET #0x02, R1
    SET #0x06, R2
    SET #0x02, R3
    SET #0x00, R4
    SET #6, R5
    CALL MEMCPY
    SET #0x02, R1
    SET #0x06, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; MEMMOVE overlap: move "ABCDE\0" by +2 inside MovBuf
    ; dst = MovBuf+2 (0x020E), src = MovBuf (0x020C), len = 6
    SET #0x02, R1
    SET #0x0E, R2
    SET #0x02, R3
    SET #0x0C, R4
    SET #6, R5
    CALL MEMMOVE
    ; print MovBuf => "ABABCDE"
    SET #0x02, R1
    SET #0x0C, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; MEMCMP: compare "hello" with itself (len=5) => 00
    SET #0x02, R1
    SET #0x00, R2
    SET #0x02, R3
    SET #0x00, R4
    SET #5, R5
    CALL MEMCMP
    ; print as hex
    CALL PUTHEX8
    SET #0x0A, R0
    CALL PUTC

    ; MEMCMP: compare "hello" with "hellp" => FF or 01 depending
    ; make second buffer: Dst1 now contains "hello", change last char to 'p'
    SET #0x02, R1
    SET #0x0A, R2          ; Dst1+4
    SET #0x70, R0          ; 'p'
    STORER R0, R1, R2

    SET #0x02, R1
    SET #0x00, R2
    SET #0x02, R3
    SET #0x06, R4
    SET #5, R5
    CALL MEMCMP
    CALL PUTHEX8
    SET #0x0A, R0
    CALL PUTC

    ; MEMCHR find 'C' in MovBuf (len=7 includes NUL) => prints 'C' and '1'
    SET #0x02, R1
    SET #0x0C, R2
    SET #0x43, R0          ; 'C'
    SET #7, R3
    CALL MEMCHR
    ; R4=1 if found
    JZ R4, NOTFOUND
    LOADR R0, R1, R2
    CALL PUTC
    SET #0x31, R0
    CALL PUTC
    JMP DONECHR
NOTFOUND:
    SET #0x2D, R0          ; '-'
    CALL PUTC
    SET #0x30, R0
    CALL PUTC
DONECHR:
    SET #0x0A, R0
    CALL PUTC

    HALT
'''
        out = assemble_and_run(src)
        self.assertEqual(
            out,
            "XXX\nhello\nABABCDE\n00\nFF\nC1\n",
        )


if __name__ == '__main__':
    unittest.main()
