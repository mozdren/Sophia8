import subprocess
import tempfile
import unittest
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')
VM = str(ROOT / 'sophia8')

BASIC_FILE = ROOT / 'sophia_basic_v1_finalfix10.s8'
LIB_FILES = [
    'kernel.s8',
    'cli.s8',
    'mem.s8',
    'fmt.s8',
    'str.s8',
]


def assemble_basic(tmpdir: Path) -> Path:
    """Copy BASIC + libraries into tmpdir and assemble. Returns path to .bin."""
    shutil.copy(BASIC_FILE, tmpdir / BASIC_FILE.name)
    for lf in LIB_FILES:
        shutil.copy(ROOT / lf, tmpdir / lf)

    binp = tmpdir / 'basic.bin'
    subprocess.run([S8ASM, BASIC_FILE.name, '-o', str(binp.name)], cwd=str(tmpdir), check=True, capture_output=True)
    return binp


def run_vm_with_input(image: Path, input_data: bytes, timeout: float = 0.9) -> str:
    """Run the VM with the given input. BASIC REPL does not exit, so we use a timeout and return partial stdout."""
    try:
        cp = subprocess.run(
            [VM, str(image.name)],
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


class TestIfThenElse(unittest.TestCase):
    def test_if_then_else_statement_immediate(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            out = run_vm_with_input(
                image,
                b'IF 1 THEN PRINT 1 ELSE PRINT 2\n'
                b'IF 0 THEN PRINT 3 ELSE PRINT 4\n',
                timeout=1.0,
            )
            self.assertIn('\n1\n', out)
            self.assertNotIn('\n2\n', out)
            self.assertIn('\n4\n', out)
            self.assertNotIn('\n3\n', out)

    def test_if_then_else_line_in_program(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            prog = (
                b'NEW\n'
                b'10 LET A%=0\n'
                b'20 IF A%=1 THEN 50 ELSE 60\n'
                b'50 PRINT 111\n'
                b'55 END\n'
                b'60 PRINT 222\n'
                b'70 END\n'
                b'RUN\n'
            )
            out = run_vm_with_input(image, prog, timeout=1.2)
            self.assertIn('\n222\n', out)
            self.assertNotIn('\n111\n', out)


if __name__ == '__main__':
    unittest.main()
