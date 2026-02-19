import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')
VM = str(ROOT / 'sophia8')


def assemble_and_run(src: str) -> str:
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        s8 = td / 'prog.s8'
        binp = td / 'prog.bin'
        s8.write_text(src, encoding='utf-8')
        subprocess.run([S8ASM, str(s8), '-o', str(binp)], check=True, cwd=str(ROOT), capture_output=True)
        proc = subprocess.run([VM, str(binp)], check=True, cwd=str(ROOT), capture_output=True)
        return proc.stdout.decode('utf-8', errors='replace')


class TestStr(unittest.TestCase):
    def test_string_routines(self):
        src = r'''
.org 0x0800
.include "/mnt/data/kernel.s8"
.include "/mnt/data/fmt.s8"
.include "/mnt/data/str.s8"

.org 0x0200
S1: .string "cat"
S2: .string "car"
S3: .string "cat"
Buf: .byte 0,0,0,0,0,0,0,0

.org
START:
    ; STRLEN("cat") => 3
    SET #0x02, R1
    SET #0x00, R2
    CALL STRLEN
    ; print decimal
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC

    ; STREQ(cat, car) => 0
    SET #0x02, R1
    SET #0x00, R2
    SET #0x02, R3
    SET #0x04, R4
    CALL STREQ
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC

    ; STREQ(cat, cat) => 1
    SET #0x02, R1
    SET #0x00, R2
    SET #0x02, R3
    SET #0x08, R4
    CALL STREQ
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC

    ; STRCPY(Buf, S2) then print Buf => "car"
    SET #0x02, R1
    SET #0x0C, R2          ; Buf
    SET #0x02, R3
    SET #0x04, R4          ; S2
    CALL STRCPY
    SET #0x02, R1
    SET #0x0C, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; STRNCPY(Buf, "cat", max=3) => writes "ca\0"
    SET #0x02, R1
    SET #0x0C, R2
    SET #0x02, R3
    SET #0x00, R4
    SET #3, R5
    CALL STRNCPY
    SET #0x02, R1
    SET #0x0C, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; STRCMP(cat, car) => 01 (since 't' > 'r') printed as hex
    SET #0x02, R1
    SET #0x00, R2
    SET #0x02, R3
    SET #0x04, R4
    CALL STRCMP
    CALL PUTHEX8
    SET #0x0A, R0
    CALL PUTC

    ; STRCHR(car, 'r') => prints found char and flag
    SET #0x02, R1
    SET #0x04, R2
    SET #0x72, R0          ; 'r'
    CALL STRCHR
    JZ R4, NOTFOUND
    LOADR R0, R1, R2
    CALL PUTC
    SET #0x31, R0
    CALL PUTC
    JMP DONE
NOTFOUND:
    SET #0x2D, R0
    CALL PUTC
    SET #0x30, R0
    CALL PUTC
DONE:
    SET #0x0A, R0
    CALL PUTC

    HALT
'''
        out = assemble_and_run(src)
        self.assertEqual(out, "3\n0\n1\ncar\nca\n01\nr1\n")


if __name__ == '__main__':
    unittest.main()
