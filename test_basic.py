import subprocess
import tempfile
import unittest
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')
VM = str(ROOT / 'sophia8')

BASIC_FILE = ROOT / 'sophia_basic_v1_finalfix11.s8'
LIB_FILES = [
    'kernel.s8',
    'cli.s8',
    'mem.s8',
    'fmt.s8',
    'str.s8',
]


def assemble_basic(tmpdir: Path) -> Path:
    shutil.copy(BASIC_FILE, tmpdir / BASIC_FILE.name)
    for lf in LIB_FILES:
        shutil.copy(ROOT / lf, tmpdir / lf)

    binp = tmpdir / 'basic.bin'
    subprocess.run([S8ASM, BASIC_FILE.name, '-o', binp.name], cwd=str(tmpdir), check=True, capture_output=True)
    return binp


def run_vm_with_input(image: Path, input_data: bytes, timeout: float = 1.2) -> str:
    try:
        cp = subprocess.run(
            [VM, image.name],
            cwd=str(image.parent),
            input=input_data,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
        return cp.stdout.decode('utf-8', errors='replace')
    except subprocess.TimeoutExpired as e:
        data = e.stdout or b''
        return data.decode('utf-8', errors='replace')


class TestColonStatements(unittest.TestCase):
    def test_colon_multiple_statements_immediate(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            out = run_vm_with_input(
                image,
                b'LET A%=1: PRINT A%: PRINT 2*3\n',
                timeout=1.1,
            )
            self.assertIn('\n1\n', out)
            self.assertIn('\n6\n', out)

    def test_if_then_else_with_colon_in_then(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            out = run_vm_with_input(
                image,
                b'IF 1 THEN PRINT 1: PRINT 2 ELSE PRINT 9\n',
                timeout=1.1,
            )
            # THEN part prints 1 and 2; ELSE must be skipped
            self.assertIn('\n1\n', out)
            self.assertIn('\n2\n', out)
            self.assertNotIn('\n9\n', out)


if __name__ == '__main__':
    unittest.main()
