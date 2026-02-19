import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / 's8asm')
VM = str(ROOT / 'sophia8')


def run_cmd(args):
    proc = subprocess.run(args, cwd=str(ROOT), capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


class TestHelp(unittest.TestCase):
    def test_s8asm_help(self):
        rc, out = run_cmd([S8ASM, '--help'])
        self.assertEqual(rc, 0)
        self.assertIn('Usage:', out)
        self.assertIn('s8asm', out)
        self.assertIn('.pre.s8', out)
        self.assertIn('.deb', out)

        rc2, out2 = run_cmd([S8ASM, '-h'])
        self.assertEqual(rc2, 0)
        self.assertIn('Usage:', out2)

    def test_vm_help(self):
        rc, out = run_cmd([VM, '--help'])
        self.assertEqual(rc, 0)
        self.assertIn('Usage:', out)
        self.assertIn('debug.img', out)
        self.assertIn('.deb', out)

        rc2, out2 = run_cmd([VM, '-h'])
        self.assertEqual(rc2, 0)
        self.assertIn('Usage:', out2)


if __name__ == '__main__':
    unittest.main()
