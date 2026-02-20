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


class TestRngLib(unittest.TestCase):
    def test_rng_next16_deterministic(self):
        src = r'''
.org 0x0800
.include "/mnt/data/kernel.s8"
.include "/mnt/data/fmt.s8"
.include "/mnt/data/rng.s8"

; Minimal 16-bit helpers required by rng.s8

; ADD16: R6:R7 = R4:R5 + R6:R7
ADD16:
    ADDR R5, R7
    JNC A16_NC
    INC R6
A16_NC:
    ADDR R4, R6
    RET

; MUL16U: (R4:R5) * (R6:R7) -> R6:R7
; This implementation supports the rng.s8 use-case where multiplier fits in 8 bits (R7).
MUL16U:
    ; save multiplier (low byte) into R0
    SET #0x00, R0
    ADDR R7, R0
    ; result = 0
    SET #0x00, R6
    SET #0x00, R7
M16_LOOP:
    JZ R0, M16_DONE
    ; result += multiplicand
    ADDR R5, R7
    JNC M16_C0
    INC R6
M16_C0:
    ADDR R4, R6
    DEC R0
    JMP M16_LOOP
M16_DONE:
    RET

.org 0x0300
SeedHi: .byte 0x12
SeedLo: .byte 0x34

.org
START:
    ; ptr -> seed
    SET #0x03, R1
    SET #0x00, R2
    CALL RNG_NEXT16
    ; print R6:R7
    SET #0x00, R1
    ADDR R6, R1
    SET #0x00, R2
    ADDR R7, R2
    CALL PUTHEX16
    SET #0x0A, R0
    CALL PUTC

    ; ptr -> seed again
    SET #0x03, R1
    SET #0x00, R2
    CALL RNG_NEXT16
    SET #0x00, R1
    ADDR R6, R1
    SET #0x00, R2
    ADDR R7, R2
    CALL PUTHEX16
    SET #0x0A, R0
    CALL PUTC
    HALT
'''
        out = assemble_and_run(src)
        self.assertEqual(out, "407D\n7592\n")


if __name__ == '__main__':
    unittest.main()
