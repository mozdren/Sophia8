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


class TestFmt(unittest.TestCase):
    def test_puthex8_puthex16_putdec8(self):
        src = r'''
.org 0x0800
.include "/mnt/data/kernel.s8"
.include "/mnt/data/fmt.s8"

.org
START:
    ; PUTHEX8(0xAB) => "AB"
    SET #0xAB, R0
    CALL PUTHEX8
    SET #0x0A, R0
    CALL PUTC

    ; PUTHEX16(0x1234) => "1234"
    SET #0x12, R1
    SET #0x34, R2
    CALL PUTHEX16
    SET #0x0A, R0
    CALL PUTC

    ; PUTDEC8(0) => "0"
    SET #0, R0
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC

    ; PUTDEC8(255) => "255"
    SET #255, R0
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC

    HALT
'''
        out = assemble_and_run(src)
        self.assertEqual(out, "AB\n1234\n0\n255\n")


if __name__ == '__main__':
    unittest.main()
