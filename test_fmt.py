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
            os.unlink(s8_fd.name)
        except OSError:
            pass
        try:
            os.unlink(str(Path(s8_fd.name).with_suffix('.bin')))
        except OSError:
            pass


class TestFmtLibrary(unittest.TestCase):
    def test_fmt(self):
        src = r'''
.org 0x0800
.include "kernel.s8"
.include "fmt.s8"

.org
START:
    ; PUTHEX8 0xAB => AB
    SET #0xAB, R0
    CALL PUTHEX8
    SET #0x0A, R0
    CALL PUTC

    ; PUTHEX16 0x1234 => 1234
    SET #0x12, R1
    SET #0x34, R2
    CALL PUTHEX16
    SET #0x0A, R0
    CALL PUTC

    ; PUTDEC8 0 => 0
    SET #0, R0
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC

    ; PUTDEC8 255 => 255
    SET #255, R0
    CALL PUTDEC8
    SET #0x0A, R0
    CALL PUTC

    HALT
'''
        out = assemble_and_run(src)
        self.assertEqual(out, "AB\n1234\n0\n255\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
