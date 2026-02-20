import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')
VM = str(ROOT / 'sophia8')


def assemble_and_run(src: str, input_data: bytes = b'') -> str:
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        s8 = td / 'prog.s8'
        binp = td / 'prog.bin'
        s8.write_text(src, encoding='utf-8')
        subprocess.run([S8ASM, str(s8), '-o', str(binp)], check=True, cwd=str(ROOT), capture_output=True)
        proc = subprocess.run([VM, str(binp)], check=True, cwd=str(ROOT), input=input_data, capture_output=True)
        return proc.stdout.decode('utf-8', errors='replace')


class TestTextLib(unittest.TestCase):
    def test_toupper_skipsp_isdigit_parse_uint8(self):
        src = r'''
.org 0x0400
START:
    ; TOUPPER_Z on S2 => "ABC"
    SET #0x03, R1
    SET #0x06, R2
    CALL TOUPPER_Z
    SET #0x03, R1
    SET #0x06, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; SKIPSP on S1 => points to 'a'
    SET #0x03, R1
    SET #0x00, R2
    CALL SKIPSP

    ; ISDIGIT at 'a' => 0
    CALL ISDIGIT
    CALL PUTDEC8
    SET #0x7C, R0
    CALL PUTC

    ; ISDIGIT at '9' (S1+4) => 1
    SET #0x03, R1
    SET #0x04, R2
    CALL ISDIGIT
    CALL PUTDEC8
    SET #0x7C, R0
    CALL PUTC

    ; PARSE_UINT8 from "123x" at 0x0210
    SET #0x03, R1
    SET #0x10, R2
    CALL PARSE_UINT8
    PUSH R1
    PUSH R2
    CALL PUTDEC8
    ; next char should be 'x'
    POP R2
    POP R1
    LOADR R0, R1, R2
    CALL PUTC
    SET #0x0A, R0
    CALL PUTC

    HALT

.org 0x0300
S1: .string "  aZ9"
S2: .string "abC"

.org 0x0310
Num: .string "123x"

.org 0x0800
.include "/mnt/data/kernel.s8"
.include "/mnt/data/fmt.s8"
.include "/mnt/data/text.s8"
'''
        out = assemble_and_run(src)
        self.assertEqual(out, "ABC\n0|1|123x\n")


if __name__ == '__main__':
    unittest.main()
