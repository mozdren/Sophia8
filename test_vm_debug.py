import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')
VM = str(ROOT / 'sophia8')


class TestVmDebug(unittest.TestCase):
    def test_breakpoint_and_resume(self):
        # Program: write 'X' to TTY (0xFF03) then HALT.
        # We'll break on the STORE instruction line.
        src_lines = [
            ".org 0x0800",
            ".org",
            "START:",
            "    SET #0x58, R0",          # 'X'
            "    STORE R0, 0xFF03",       # <- breakpoint here
            "    HALT",
        ]
        src = "\n".join(src_lines) + "\n"
        bp_line = src_lines.index("    STORE R0, 0xFF03") + 1  # 1-based

        # Run in a temp dir but with cwd=ROOT so the VM writes debug.img there.
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            s8 = td / 'prog.s8'
            binp = td / 'prog.bin'
            debp = td / 'prog.deb'
            s8.write_text(src, encoding='utf-8')

            subprocess.run([S8ASM, str(s8), '-o', str(binp)], check=True, cwd=str(ROOT), capture_output=True)
            self.assertTrue(debp.exists(), ".deb should be produced by s8asm")

            # Ensure no old debug image.
            dbg = ROOT / 'debug.img'
            if dbg.exists():
                dbg.unlink()

            # Break using .deb + file + line.
            proc = subprocess.run([VM, str(debp), str(s8), str(bp_line)], cwd=str(ROOT), capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0)
            self.assertIn("BREAK", proc.stdout)
            self.assertTrue(dbg.exists(), "debug.img should be created on breakpoint")
            self.assertNotIn("X", proc.stdout, "Program should not execute STORE before breakpoint")

            # Resume from debug image (no breakpoint) => should output 'X'
            proc2 = subprocess.run([VM, str(dbg)], cwd=str(ROOT), capture_output=True, text=True)
            self.assertEqual(proc2.returncode, 0)
            self.assertIn("X", proc2.stdout)

            dbg.unlink(missing_ok=True)


if __name__ == '__main__':
    unittest.main()
