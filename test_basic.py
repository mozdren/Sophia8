import subprocess
import tempfile
import unittest
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')
VM = str(ROOT / 'sophia8')

BASIC_FILE = ROOT / 'sophia_basic_v1_finalfix9.s8'
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


def run_vm_with_input(image: Path, input_data: bytes, timeout: float = 0.8) -> str:
    """Run the VM with the given input. BASIC REPL does not exit, so we use a timeout and return partial stdout."""
    try:
        cp = subprocess.run([VM, str(image.name)],
            cwd=str(image.parent),
            input=input_data,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
        return cp.stdout.decode("utf-8", errors="replace")
    except subprocess.TimeoutExpired as e:
        data = e.stdout or b""
        return data.decode("utf-8", errors="replace")

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


    def test_print_mul(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            out = run_vm_with_input(image, b'PRINT 2*3\n', timeout=0.6)
            self.assertIn('\n6\n', out)

    def test_if_then_statement_immediate(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            out = run_vm_with_input(image, b'IF 1 THEN PRINT 7\nIF 0 THEN PRINT 8\n', timeout=0.7)
            # should print 7, should not print 8
            self.assertIn('\n7\n', out)
            self.assertNotIn('\n8\n', out)

    def test_if_then_line_in_program(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            prog = (
                b'NEW\n'
                b'10 LET A%=0\n'
                b'20 IF A%=0 THEN 50\n'
                b'30 PRINT 111\n'
                b'40 END\n'
                b'50 PRINT 222\n'
                b'60 END\n'
                b'RUN\n'
            )
            out = run_vm_with_input(image, prog, timeout=1.2)
            self.assertIn('\n222\n', out)
            self.assertNotIn('\n111\n', out)

    def test_rnd_range_and_determinism(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            image = assemble_basic(td)
            # Seed, generate two numbers, reseed, generate again - first should match.
            out = run_vm_with_input(image, b'RANDOMIZE 1\nPRINT RND(10)\nPRINT RND(10)\nRANDOMIZE 1\nPRINT RND(10)\n', timeout=0.9)
            # Extract printed integers (lines that are just digits or -digits)
            nums = []
            for line in out.splitlines():
                s = line.strip()
                if s.lstrip('-').isdigit():
                    nums.append(int(s))
            self.assertGreaterEqual(len(nums), 3)
            a,b,c = nums[0], nums[1], nums[2]
            self.assertTrue(0 <= a < 10)
            self.assertTrue(0 <= b < 10)
            self.assertEqual(a, c)
if __name__ == '__main__':
    unittest.main()
