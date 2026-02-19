import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')


class TestDeb(unittest.TestCase):
    def test_debug_map_contains_expected_addresses_and_bytes(self):
        src = r'''
.org 0x0200
Msg: .string "A"

.org
START:
    HALT
'''

        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            s8 = td / 'prog.s8'
            binp = td / 'prog.bin'
            debp = td / 'prog.deb'
            s8.write_text(src, encoding='utf-8')

            subprocess.run([S8ASM, str(s8), '-o', str(binp)], check=True, cwd=str(ROOT), capture_output=True)

            self.assertTrue(debp.exists(), "Expected .deb file to be created next to output binary")
            deb = debp.read_text(encoding='utf-8', errors='replace')

            # Entry marker is after string, so entry = 0x0202
            # Implicit stub at 0x0000 is: JMP 0x0202 => 07 02 02
            self.assertIn("0000", deb)
            self.assertIn("CODE", deb)
            self.assertIn("07 02 02", deb)

            # Data at 0x0200: 'A' 0x41 + NUL 0x00
            self.assertIn("0200", deb)
            self.assertIn("DATA", deb)
            self.assertIn("41 00", deb)

            # HALT at 0x0202: 00
            self.assertIn("0202", deb)
            # There will also be the HALT instruction line from START.
            self.assertIn("00", deb)


if __name__ == '__main__':
    unittest.main()
