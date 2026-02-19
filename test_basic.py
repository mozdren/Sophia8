import subprocess
import tempfile
import unittest
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')
VM = str(ROOT / 'sophia8')

BASIC_FILE = ROOT / 'sophia_basic_v1_newlibs.s8'
LIB_FILES = [
    'kernel.s8',
    'cli.s8',
    'mem.s8',
    'fmt.s8',
    'str.s8',
]


def assemble_basic(tmpdir: Path) -> Path:
    """Copy BASIC + libraries into tmpdir and assemble. Returns path to .bin."""
    # Copy BASIC and its relative-includes dependencies into temp dir.
    shutil.copy(BASIC_FILE, tmpdir / BASIC_FILE.name)
    for lf in LIB_FILES:
        shutil.copy(ROOT / lf, tmpdir / lf)

    binp = tmpdir / 'basic.bin'
    subprocess.run([S8ASM, BASIC_FILE.name, '-o', str(binp.name)], cwd=str(tmpdir), check=True, capture_output=True)
    return binp


def run_vm_with_input(image: Path, input_data: bytes, timeout: float = 0.6) -> str:
    """Run the VM with the given input. Since BASIC REPL doesn't exit, we kill on timeout."""
    proc = subprocess.Popen(
        [VM, str(image.name)],
        cwd=str(image.parent),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        out, _err = proc.communicate(input=input_data, timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, _err = proc.communicate()

    return out.decode('utf-8', errors='replace')


class TestSophiaBasicV1(unittest.TestCase):
    def test_banner(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            out = run_vm_with_input(image, b'', timeout=0.25)
            self.assertIn('Sophia Basic v.1 (2026) by Karel Mozdren', out)
            self.assertIn('READY.', out)

    def test_let_and_print_string(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            out = run_vm_with_input(image, b'LET A$="TEST"\nPRINT A$\n', timeout=0.5)
            self.assertIn('\nTEST\n', out)

    def test_input_and_print_string(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            out = run_vm_with_input(image, b'INPUT A$\nhello\nPRINT A$\n', timeout=0.6)
            self.assertIn('\nhello\n', out)

    def test_input_and_print_int16(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            out = run_vm_with_input(image, b'INPUT A%\n-123\nPRINT A%\n', timeout=0.7)
            self.assertIn('\n-123\n', out)


if __name__ == '__main__':
    unittest.main()
