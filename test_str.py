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


def assemble_and_run(src: str) -> str:
    build_tools_if_needed()
    s8_fd = tempfile.NamedTemporaryFile("w", delete=False, dir=ROOT, suffix=".s8", encoding="utf-8")
    try:
        s8_fd.write(src)
        s8_fd.close()
        s8_path = Path(s8_fd.name)
        bin_path = s8_path.with_suffix(".bin")
        subprocess.check_call([str(S8ASM), str(s8_path), "-o", str(bin_path)], cwd=ROOT)
        p = subprocess.run([str(VM), str(bin_path)], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if p.returncode != 0:
            raise RuntimeError(p.stderr.decode("utf-8", "replace"))
        return p.stdout.decode("utf-8", errors="replace")
    finally:
        try:
            s8_path = Path(s8_fd.name)
            os.unlink(s8_path)
        except Exception:
            pass
        try:
            os.unlink(str(Path(s8_fd.name).with_suffix('.bin')))
        except Exception:
            pass


class TestStrLibrary(unittest.TestCase):
    def test_str_routines(self):
        src = r'''
.org 0x0800
.include "kernel.s8"
.include "fmt.s8"
.include "str.s8"

.org 0x0300
S1: .string "HELLO"
S2: .string "HELLO"
S3: .string "HELLP"
S4: .string "HI"

.org 0x0340
Buf: .byte 0,0,0,0,0,0,0,0,0,0

.org
START:
    ; STRLEN("HELLO") => 5
    SET #0x03, R1
    SET #0x00, R2
    CALL STRLEN
    SET #0x30, R6
    ADDR R0, R6
    SET #0x00, R0
    ADDR R6, R0
    CALL PUTC
    SET #0x0A, R0
    CALL PUTC

    ; STREQ(S1,S2) => 1
    SET #0x03, R1
    SET #0x00, R2
    SET #0x03, R3
    SET #0x06, R4
    CALL STREQ
    SET #0x30, R6
    ADDR R0, R6
    SET #0x00, R0
    ADDR R6, R0
    CALL PUTC
    SET #0x0A, R0
    CALL PUTC

    ; STRCPY(Buf, S4) then print Buf => "HI"
    SET #0x03, R1
    SET #0x40, R2
    SET #0x03, R3
    SET #0x12, R4
    CALL STRCPY

    SET #0x03, R1
    SET #0x40, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; STRNCPY(Buf, S1, 4) => "HEL" (max includes NUL)
    SET #0x03, R1
    SET #0x40, R2
    SET #0x03, R3
    SET #0x00, R4
    SET #4, R5
    CALL STRNCPY

    SET #0x03, R1
    SET #0x40, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; STRCMP(S1,S3) => 1 ("HELLO" < "HELLP")
    SET #0x03, R1
    SET #0x00, R2
    SET #0x03, R3
    SET #0x0C, R4
    CALL STRCMP
    SET #0x30, R6
    ADDR R0, R6
    SET #0x00, R0
    ADDR R6, R0
    CALL PUTC
    SET #0x0A, R0
    CALL PUTC

    ; STRCHR(S1,'L') => offset 2
    SET #0x03, R1
    SET #0x00, R2
    SET #0x4C, R0
    CALL STRCHR
    JZ R1, CHR_NOTFOUND
    SET #0x00, R0
    ADDR R2, R0
    SUB #0x00, R0
    ; base low is 0x00 => offset in R0
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC
    HALT

CHR_NOTFOUND:
    SET #255, R0
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC
    HALT
'''
        out = assemble_and_run(src)
        self.assertEqual(out, "5\n1\nHI\nHEL\n1\n2\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
