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


class TestCli(unittest.TestCase):
    def test_skipspaces_readtoken_parse_u8_dec(self):
        src = r'''
.org 0x0800
.include "/mnt/data/kernel.s8"
.include "/mnt/data/fmt.s8"
.include "/mnt/data/cli.s8"

.org 0x0200
Line:   .string "  hello\tworld  255x"
Tok1:   .byte 0,0,0,0,0,0,0,0
Tok2:   .byte 0,0,0,0,0,0,0,0

.org
START:
    ; R1:R2 -> Line
    SET #0x02, R1
    SET #0x00, R2

    ; READTOKEN -> Tok1
    SET #0x02, R3
    SET #0x16, R4          ; Tok1 at 0x0216 (Line is 0x0200 len=17 incl NUL => Tok1 0x0211? let's set explicitly)
    ; NOTE: use fixed addresses below instead of relying on layout
    HALT
'''
        # We avoid layout pitfalls by placing data at explicit addresses.
        src = r'''
.org 0x0800
.include "/mnt/data/kernel.s8"
.include "/mnt/data/fmt.s8"
.include "/mnt/data/cli.s8"

.org 0x0200
Line: .string "  hello\tworld  255x"

.org 0x0300
Tok1: .byte 0,0,0,0,0,0,0,0
Tok2: .byte 0,0,0,0,0,0,0,0

.org
START:
    SET #0x02, R1
    SET #0x00, R2          ; Line

    ; token1 -> Tok1
    SET #0x03, R3
    SET #0x00, R4
    SET #8, R5
    CALL READTOKEN

    ; save updated src pointer
    SET #0x00, R6
    ADDR R1, R6
    SET #0x00, R7
    ADDR R2, R7

    SET #0x03, R1
    SET #0x00, R2
    CALL PUTS
    SET #0x7C, R0          ; '|'
    CALL PUTC

    ; restore src pointer
    SET #0x00, R1
    ADDR R6, R1
    SET #0x00, R2
    ADDR R7, R2

    ; token2 -> Tok2 (uses updated src pointer)
    SET #0x03, R3
    SET #0x08, R4
    SET #8, R5
    CALL READTOKEN

    ; save updated src pointer
    SET #0x00, R6
    ADDR R1, R6
    SET #0x00, R7
    ADDR R2, R7

    SET #0x03, R1
    SET #0x08, R2
    CALL PUTS
    SET #0x7C, R0
    CALL PUTC

    ; restore src pointer
    SET #0x00, R1
    ADDR R6, R1
    SET #0x00, R2
    ADDR R7, R2

    ; parse number (src pointer now at spaces before 255)
    CALL PARSE_U8_DEC

    ; save pointer before calling PUTDEC8 (it clobbers R1/R2)
    SET #0x00, R6
    ADDR R1, R6
    SET #0x00, R7
    ADDR R2, R7
    ; print value in decimal
    CALL PUTDEC8

    ; restore pointer
    SET #0x00, R1
    ADDR R6, R1
    SET #0x00, R2
    ADDR R7, R2

    ; print next char (should be 'x')
    LOADR R0, R1, R2
    CALL PUTC

    SET #0x0A, R0
    CALL PUTC

    HALT
'''
        out = assemble_and_run(src)
        self.assertEqual(out, "hello|world|255x\n")

    def test_readline_echo_basic(self):
        # Provide input "abc\n" and ensure buffer is printed.
        src = r'''
.org 0x0800
.include "/mnt/data/kernel.s8"
.include "/mnt/data/cli.s8"

.org 0x0300
Buf: .byte 0,0,0,0,0,0,0,0

.org
START:
    SET #0x03, R1
    SET #0x00, R2
    SET #8, R3
    CALL READLINE_ECHO

    ; print newline then the buffer
    SET #0x0A, R0
    CALL PUTC

    SET #0x03, R1
    SET #0x00, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    HALT
'''
        out = assemble_and_run(src, input_data=b"abc\n")
        # READLINE_ECHO echoes input, then our program prints "\nabc\n"
        self.assertEqual(out, "abc\nabc\n")


if __name__ == '__main__':
    unittest.main()
