"""Disposable synthetic fixtures only; never apply the on-disk batch to originals."""
import builtins
import contextlib
import hashlib
import io
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest

BATCH = Path(__file__).with_name("human-apply-v4-unreleased.py")


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="rt002-v4-recovery-")
        self.addCleanup(self.temp.cleanup)
        self.module = types.ModuleType("fixture_batch")
        exec(compile(BATCH.read_bytes(), str(BATCH), "exec"), self.module.__dict__)
        m = self.module
        helper_bytes = m.HELPER.read_bytes()
        self.assertEqual(hashlib.sha256(helper_bytes).hexdigest(), m.HELPER_SHA)
        self.assertTrue(m.RELEASED)
        m.OWNER = Path(self.temp.name).resolve()
        m.HERE = m.OWNER / "candidate"
        m.HERE.mkdir()
        m.HELPER = m.HERE / "helper.py"
        m.HELPER.write_bytes(helper_bytes)
        rows = []
        for i in range(4):
            before, after = f"before-{i}\n".encode(), f"after-{i}\n".encode()
            rel, name = f"target-{i}", f"candidate-{i}"
            (m.OWNER / rel).write_bytes(before)
            (m.OWNER / rel).chmod(0o755)
            (m.HERE / name).write_bytes(after)
            rows.append((rel, name, m.hashlib.sha256(before).hexdigest(), m.hashlib.sha256(after).hexdigest()))
        m.ROWS = tuple(rows)
        m.MODES = (0o755,) * 4
        (m.HERE / "candidate-v4.patch").write_bytes(b"fixture patch")
        m.PATCH_SHA = m.hashlib.sha256(b"fixture patch").hexdigest()
        m.git = lambda *args: m.HEAD if args[0] == "rev-parse" else "\n".join(f"1\t1\t{r[0]}" for r in m.ROWS) if "--numstat" in args else ""
        self.old_cwd = Path.cwd()
        os.chdir(m.OWNER)
        self.addCleanup(os.chdir, self.old_cwd)
        # Write-mode tests run only after OWNER/HERE have become synthetic paths.
        m.RELEASED = True

    def run_batch(self, *args, fails=False):
        output = io.StringIO()
        previous = sys.argv
        try:
            sys.argv = [str(BATCH), *map(str, args)]
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                if fails:
                    with self.assertRaises((ValueError, OSError)):
                        self.module.main()
                else:
                    self.module.main()
        finally:
            sys.argv = previous
        return output.getvalue()

    def backup(self):
        return next(self.module.HERE.glob("human-v4-backup-*"))

    def assert_state(self, after_indices=()):
        for i, row in enumerate(self.module.ROWS):
            self.assertEqual((self.module.OWNER / row[0]).read_bytes(), f"{'after' if i in after_indices else 'before'}-{i}\n".encode())
            self.assertEqual((self.module.OWNER / row[0]).stat().st_mode & 0o777, 0o755)

    def inject(self, kind):
        def execute(code, namespace):
            builtins.exec(code, namespace)
            replace, read = namespace["replace_one"], namespace["read_regular"]
            count = 0
            def wrapped(item):
                nonlocal count
                if kind == "partial" and count == 2:
                    raise OSError("fixture replace failure")
                replace(item)
                count += 1
            def readback(path):
                data, metadata = read(path)
                if kind == "readback" and count == 4 and path == self.module.OWNER / "target-0":
                    return b"fixture bad read", metadata
                return data, metadata
            namespace["replace_one"] = wrapped
            namespace["read_regular"] = readback
        self.module.exec = execute

    def test_success_and_restore(self):
        self.run_batch("--apply-human")
        self.assert_state(range(4))
        self.assertIn("RESTORED_ONCE_READBACK_OK", self.run_batch("--restore-human", self.backup()))
        self.assert_state()
        self.run_batch("--restore-human", self.backup())
        self.assert_state()

    def test_backup_mismatch_refuses_before_any_write(self):
        self.run_batch("--apply-human")
        (self.backup() / "4-target-3.original").write_bytes(b"wrong")
        self.run_batch("--restore-human", self.backup(), fails=True)
        self.assert_state(range(4))

    def test_unknown_target_refuses_before_any_write(self):
        self.run_batch("--apply-human")
        (self.module.OWNER / "target-3").write_bytes(b"unknown")
        self.run_batch("--restore-human", self.backup(), fails=True)
        for i in range(3):
            self.assertEqual((self.module.OWNER / f"target-{i}").read_bytes(), f"after-{i}\n".encode())
        self.assertEqual((self.module.OWNER / "target-3").read_bytes(), b"unknown")

    def test_partial_apply_guidance_and_restore(self):
        self.inject("partial")
        output = self.run_batch("--apply-human", fails=True)
        self.assertIn("RECOVERY_REQUIRED", output)
        self.assertIn("target-0 AFTER", output)
        self.assertIn("target-3 BEFORE", output)
        self.assert_state((0, 1))
        del self.module.exec
        self.run_batch("--restore-human", self.backup())
        self.assert_state()

    def test_mode_only_change_refuses_restore_before_any_write(self):
        self.run_batch("--apply-human")
        (self.module.OWNER / "target-3").chmod(0o644)
        self.run_batch("--restore-human", self.backup(), fails=True)
        for i in range(4):
            self.assertEqual((self.module.OWNER / f"target-{i}").read_bytes(), f"after-{i}\n".encode())
        self.assertEqual((self.module.OWNER / "target-3").stat().st_mode & 0o777, 0o644)

    def test_mode_metadata_mismatch_refuses_restore(self):
        self.run_batch("--apply-human")
        (self.backup() / "original-modes.json").write_bytes(b'{"version":1,"original_modes":[]}\n')
        self.run_batch("--restore-human", self.backup(), fails=True)
        self.assert_state(range(4))

    def test_final_readback_guidance_and_restore(self):
        self.inject("readback")
        output = self.run_batch("--apply-human", fails=True)
        self.assertIn("RECOVERY_REQUIRED", output)
        self.assertIn("target-0 UNKNOWN", output)
        self.assert_state(range(4))
        del self.module.exec
        self.run_batch("--restore-human", self.backup())
        self.assert_state()

    def test_partial_restore_can_resume_explicitly(self):
        self.run_batch("--apply-human")
        self.inject("partial")
        self.assertIn("RECOVERY_REQUIRED", self.run_batch("--restore-human", self.backup(), fails=True))
        self.assert_state((2, 3))
        del self.module.exec
        self.run_batch("--restore-human", self.backup())
        self.assert_state()

    def test_unreleased_blocks_both_write_modes(self):
        self.module.RELEASED = False
        self.run_batch("--apply-human", fails=True)
        self.run_batch("--restore-human", self.module.HERE / "missing", fails=True)
        self.assert_state()
        self.assertEqual(list(self.module.HERE.glob("human-v4-backup-*")), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
