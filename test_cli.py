import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
S8ASM = ROOT / "s8asm"
VM = ROOT / "sophia8"


def build_tools_if_needed() -> None:
    if not S8ASM.exists():
        subprocess.check_call(["g++", "-O2", "-std=c++17", "s8asm.cpp", "-o", "s8asm"], cwd=ROOT)
    if not VM.exists():
        subprocess.check_call(["g++", "-O2", "-std=c++17", "sophia8.cpp", "-o", "sophia8"], cwd=ROOT)


def assemble_and_run(src: str, stdin: bytes) -> str:
    build_tools_if_needed()
    s8_fd = tempfile.NamedTemporaryFile("w", delete=False, dir=ROOT, suffix=".s8", encoding="utf-8")
    try:
        s8_fd.write(src)
        s8_fd.close()
        s8_path = Path(s8_fd.name)
        bin_path = s8_path.with_suffix(".bin")
        subprocess.check_call([str(S8ASM), str(s8_path), "-o", str(bin_path)], cwd=ROOT)
        p = subprocess.run([str(VM), str(bin_path)], cwd=ROOT, input=stdin, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if p.returncode != 0:
            raise RuntimeError(p.stderr.decode("utf-8", "replace"))
        return p.stdout.decode("utf-8", errors="replace")
    finally:
        try:
            os.unlink(s8_fd.name)
        except OSError:
            pass
        try:
            os.unlink(str(Path(s8_fd.name).with_suffix('.bin')))
        except OSError:
            pass


class TestCliLibrary(unittest.TestCase):
    def test_readline_and_parsers(self):
        src = r'''
.org 0x0800
.include "kernel.s8"
.include "fmt.s8"
.include "cli.s8"

.org 0x0300
LineBuf: .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
TokBuf:  .byte 0,0,0,0,0,0,0,0

.org 0x0340
TestLine: .string "   42  hello\tworld"

.org
START:
    ; --- READLINE_ECHO test ---
    ; prints: ECHO(<input>) + then |<buffer>|\n
    SET #0x7C, R0   ; '|'
    CALL PUTC

    SET #0x03, R1
    SET #0x00, R2
    SET #16, R3
    CALL READLINE_ECHO

    SET #0x7C, R0
    CALL PUTC

    SET #0x03, R1
    SET #0x00, R2
    CALL PUTS

    SET #0x7C, R0
    CALL PUTC
    SET #0x0A, R0
    CALL PUTC

    ; --- SKIPSPACES + PARSE_U8_DEC + READTOKEN tests on TestLine ---
    SET #0x03, R1
    SET #0x40, R2   ; points to "   42  hello\tworld"
    CALL SKIPSPACES

    CALL PARSE_U8_DEC
    ; Save updated pointer across PUTDEC8 (PUTDEC8 clobbers R1:R2)
    SET #0x00, R6
    ADDR R1, R6
    SET #0x00, R7
    ADDR R2, R7
    ; print parsed number as decimal + '\n'
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC

    ; Restore pointer
    SET #0x00, R1
    ADDR R6, R1
    SET #0x00, R2
    ADDR R7, R2

    ; skip spaces between number and token
    CALL SKIPSPACES

    ; read token into TokBuf (max 8)
    SET #0x03, R3
    SET #0x10, R4
    SET #8, R5
    CALL READTOKEN

    ; print token + '\n'
    SET #0x03, R1
    SET #0x10, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    HALT
'''
        # Input for READLINE_ECHO: 'hi' + newline
        out = assemble_and_run(src, stdin=b"hi\n")
        # Expected:
        # 1) prints '|' then echoes 'hi' then prints '|hi|\n'
        # so first line is: |hi|hi|
        # 2) prints 42\n
        # 3) prints hello\n
        self.assertEqual(out, "|hi|hi|\n42\nhello\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
