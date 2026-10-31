#!/usr/bin/env python3
"""Spec-role capability contract and nonmutating hash recipe regression.

This does not prove a launched host's tool enforcement or formal review.
"""
import hashlib
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SpecReviewerHashCapability(unittest.TestCase):
    def test_both_roles_have_hash_capability_and_retain_readonly_boundary(self):
        for role in ("a", "b"):
            with self.subTest(role=role):
                text = (ROOT / f"plugins/sdd-review-loop/agents/spec-reviewer-{role}.md").read_text()
                front = text.split("---", 2)[1]
                self.assertIn("tools: Read, Grep, Glob, Bash\n", front)
                self.assertIn("disallowedTools: Write, Edit, NotebookEdit", front)
                self.assertIn('"reports/spec-review/**/reviewer-*.json"', front)
                self.assertIn("Bash is permitted only for nonmutating SHA256 computation", text)
                self.assertIn("files already admitted by your manifest", text)
                self.assertIn("record text defined by `review-context-boundary.md`", text)
                self.assertIn("No arbitrary shell commands", text)
                self.assertIn("Never run `validate-review-context-set`", text)
                self.assertIn("No same-session fallback", text)

    def test_sha256_recipes_preserve_file_and_exact_record_bytes(self):
        utility = shutil.which("sha256sum") or shutil.which("shasum")
        self.assertIsNotNone(utility, "a SHA256 utility is required")
        command = [utility] + (["-a", "256"] if Path(utility).name == "shasum" else [])
        record = b"1|spec-review|reviewer-a|run-fixture|session-fixture|"
        with tempfile.TemporaryDirectory(prefix="spec-role-hash-") as tmp:
            path = Path(tmp) / "admitted file.md"
            data = "admitted bytes\n日本語\n".encode()
            path.write_bytes(data)
            before = path.stat()
            result = subprocess.run(command + ["--", str(path)], capture_output=True, check=True)
            self.assertEqual(result.stdout.decode().split()[0], hashlib.sha256(data).hexdigest())
            self.assertEqual(path.read_bytes(), data)
            self.assertEqual(path.stat().st_mtime_ns, before.st_mtime_ns)
            result = subprocess.run(command, input=record, capture_output=True, check=True)
            self.assertEqual(result.stdout.decode().split()[0], hashlib.sha256(record).hexdigest())
            self.assertNotEqual(result.stdout.decode().split()[0], hashlib.sha256(record + b"\n").hexdigest())

    def test_literal_record_pipeline_does_not_evaluate_shell_metacharacters(self):
        # Quoted data stays data; embedded substitutions must not execute.
        record = "record|'quote'|$(exit 91)|`exit 92`|; exit 93|日本語\nlast"
        utility = "sha256sum" if shutil.which("sha256sum") else "shasum -a 256"
        result = subprocess.run(
            ["bash", "-c", "printf '%s' " + shlex.quote(record) + " | rtk proxy " + utility],
            capture_output=True, check=True,
        )
        self.assertEqual(result.stdout.decode().split()[0], hashlib.sha256(record.encode()).hexdigest())


if __name__ == "__main__":
    unittest.main()
