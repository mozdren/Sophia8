import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
S8ASM = str(ROOT / "s8asm")
VM = str(ROOT / "sophia8")


def assemble(src: str, name: str = "prog") -> tuple[Path, tempfile.TemporaryDirectory]:
    """Assemble src into a temp dir. Returns (.deb path, tempdir handle)."""
    td = tempfile.TemporaryDirectory()
    tdp = Path(td.name)
    s8 = tdp / f"{name}.s8"
    binp = tdp / f"{name}.bin"
    s8.write_text(src, encoding="utf-8")

    debp = tdp / f"{name}.deb"
    subprocess.run([S8ASM, str(s8), "-o", str(binp)], check=True, cwd=str(ROOT), capture_output=True)
    assert debp.exists(), "Expected s8asm to emit .deb sidecar"
    return debp, td


class TestVmDebug(unittest.TestCase):
    def test_breakpoint_rejects_data_only_line(self):
        # Line 2 emits DATA, so setting a breakpoint there must be rejected.
        src = """\
.org 0x0800
.byte 0x41
.org
START:
    HALT
"""
        debp, td = assemble(src)
        # Break on line 2 (.byte) -> should error with exact message.
        proc = subprocess.run(
            [VM, str(debp), str(debp.with_suffix(".s8")), "2"],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
        )
        td.cleanup()
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("No executable code on this line.", proc.stdout)


if __name__ == "__main__":
    unittest.main()
