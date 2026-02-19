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


def assemble_and_run(src: str, stdin: bytes = b"") -> str:
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
            raise RuntimeError(f"VM failed: {p.returncode}\nSTDERR:\n{p.stderr.decode('utf-8', 'replace')}")
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


class TestMemLibrary(unittest.TestCase):
    def test_mem_routines(self):
        src = r'''
.org 0x0800
.include "kernel.s8"
.include "fmt.s8"
.include "mem.s8"

.org 0x0300
Src1: .string "ABC"         ; bytes: 41 42 43 00
Src2: .string "ABD"         ; 41 42 44 00

.org 0x0340
BufA: .byte 0,0,0,0,0,0,0,0,0,0,0,0

.org 0x0400
MovBuf: .string "0123456789"  ; will be modified in-place

.org
START:
    ; MEMSET BufA[0..4] = 'X'
    SET #0x03, R1
    SET #0x40, R2
    SET #0x58, R0
    SET #5, R3
    CALL MEMSET

    ; MEMCPY BufA = "ABC\0" (4 bytes)
    SET #0x03, R1
    SET #0x40, R2
    SET #0x03, R3
    SET #0x00, R4
    SET #4, R5
    CALL MEMCPY

    ; Print BufA as string => "ABC"
    SET #0x03, R1
    SET #0x40, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; MEMMOVE overlapping: dst = MovBuf+2, src = MovBuf, len=5
    SET #0x04, R1
    SET #0x02, R2
    SET #0x04, R3
    SET #0x00, R4
    SET #5, R5
    CALL MEMMOVE

    ; Print MovBuf => expect "0101234789"
    SET #0x04, R1
    SET #0x00, R2
    CALL PUTS
    SET #0x0A, R0
    CALL PUTC

    ; MEMCMP("ABC","ABD",3) => 1
    SET #0x03, R1
    SET #0x00, R2
    SET #0x03, R3
    SET #0x04, R4
    SET #3, R5
    CALL MEMCMP
    ; print digit '0'+R0
    SET #0x30, R6
    ADDR R0, R6
    SET #0x00, R0
    ADDR R6, R0
    CALL PUTC
    SET #0x0A, R0
    CALL PUTC

    ; MEMCHR in MovBuf find '3' within 10 bytes; print offset as decimal
    SET #0x04, R1
    SET #0x00, R2
    SET #0x33, R0
    SET #10, R3
    CALL MEMCHR

    ; If not found => prints 255
    JZ R1, NOTFOUND

    ; offset = R2 - base_low (0x00)
    SET #0x00, R0
    ADDR R2, R0
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC
    HALT

NOTFOUND:
    SET #255, R0
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC
    HALT
'''
        out = assemble_and_run(src)
        self.assertEqual(out, "ABC\n0101234789\n1\n5\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
