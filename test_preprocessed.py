import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')


class TestPreprocessed(unittest.TestCase):
    def test_preprocessed_sidecar_is_written_and_expands_includes(self):
        src = r'''
.org 0x0800
.include "/mnt/data/kernel.s8"

.org
START:
    HALT
'''
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            s8 = td / 'prog.s8'
            out_bin = td / 'prog.bin'
            out_pre = td / 'prog.pre.s8'
            s8.write_text(src, encoding='utf-8')

            subprocess.run([S8ASM, str(s8), '-o', str(out_bin)], check=True, cwd=str(ROOT), capture_output=True)

            self.assertTrue(out_pre.exists(), 'expected sidecar preprocessed file to exist')
            txt = out_pre.read_text(encoding='utf-8', errors='replace')

            # The preprocessed file should have expanded the include, so there
            # must be no active (non-comment) .include directives left.
            for ln in txt.splitlines():
                stripped = ln.lstrip()
                if stripped.startswith(';') or stripped == '':
                    continue
                self.assertFalse(stripped.startswith('.include'), f'unexpected active include line: {ln!r}')
            # And it should mention the included file.
            self.assertIn('BEGIN FILE:', txt)
            self.assertIn('kernel.s8', txt)


if __name__ == '__main__':
    unittest.main()
