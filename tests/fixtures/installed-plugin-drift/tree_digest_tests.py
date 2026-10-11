"""Bounded regressions for the fixture's read-only tree comparison."""

import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
DRIVER = Path(__file__).with_name("fixture_driver.py")
tree_digest = runpy.run_path(str(DRIVER))["tree_digest"]


class TreeDigestTests(unittest.TestCase):
    def test_regular_content_and_removal_remain_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "file"
            target.write_bytes(b"before")
            before = tree_digest([root])
            target.write_bytes(b"after")
            after = tree_digest([root])
            self.assertNotEqual(before, after)
            target.unlink()
            self.assertNotEqual(after, tree_digest([root]))

    @unittest.skipUnless(hasattr(os, "mkfifo"), "requires POSIX named pipes")
    def test_pipe_and_symlink_are_not_opened(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pipe = root / "pipe"
            os.mkfifo(pipe, 0o600)
            (root / "link").symlink_to(pipe)
            command = [sys.executable, "-B", "-c",
                       "import runpy,sys; from pathlib import Path; "
                       "print(runpy.run_path(sys.argv[1])['tree_digest']([Path(sys.argv[2])]))",
                       str(DRIVER), str(root)]
            def bounded_digest():
                return subprocess.run(command, check=True, capture_output=True,
                                      text=True, timeout=10).stdout
            before = bounded_digest()
            self.assertEqual(before, bounded_digest())
            pipe.chmod(0o400)
            after = bounded_digest()
            self.assertNotEqual(before, after)
            pipe.unlink()
            self.assertNotEqual(after, bounded_digest())


if __name__ == "__main__":
    unittest.main()
