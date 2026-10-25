#!/usr/bin/env python3
"""Offline checks for the weekly audit's read-only credential preflight."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "pr_access", ROOT / ".github/scripts/check-self-improvement-pr-access.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AccessTests(unittest.TestCase):
    def result(self, code=0, stdout="[]", stderr=""):
        return subprocess.CompletedProcess([], code, stdout, stderr)

    def test_read_only_exact_credential_and_bounded_request(self):
        with patch.object(MODULE.subprocess, "run", return_value=self.result()) as call:
            self.assertIsNone(MODULE.check_access("owner/repo", "test-token"))
        args, kwargs = call.call_args
        self.assertEqual(args[0], ["gh", "api", "--method", "GET",
                                  "repos/owner/repo/pulls?state=open&per_page=1"])
        self.assertEqual(kwargs["env"]["GH_TOKEN"], "test-token")
        self.assertNotIn("test-token", args[0])
        self.assertEqual(kwargs["timeout"], 30)

    def test_missing_token_never_invokes_client(self):
        with patch.object(MODULE.subprocess, "run") as call:
            self.assertEqual(MODULE.check_access("owner/repo", ""), "missing-token")
            call.assert_not_called()

    def test_invalid_repository_never_invokes_client(self):
        with patch.object(MODULE.subprocess, "run") as call:
            for value in (None, "", "../repo", "owner/../repo", "https://host/repo",
                          "owner/repo?token=secret", "owner/repo\n"):
                with self.subTest(value=value):
                    self.assertEqual(MODULE.check_access(value, "token"), "invalid-repository")
            call.assert_not_called()

    def test_permission_and_auth_failures_are_not_successful_skips(self):
        for status in (401, 403, 404, 429):
            with self.subTest(status=status), patch.object(
                MODULE.subprocess, "run", return_value=self.result(1, stderr=f"gh: private body (HTTP {status})")
            ):
                self.assertEqual(MODULE.check_access("owner/repo", "token"), f"http-{status}")

    def test_other_remote_failure_is_closed_diagnostic(self):
        with patch.object(MODULE.subprocess, "run", return_value=self.result(1, stderr="secret HTTP 503")):
            self.assertEqual(MODULE.check_access("owner/repo", "token"), "request-failed")

    def test_timeout_and_missing_client_fail_closed(self):
        for error, expected in ((subprocess.TimeoutExpired(["gh"], 30), "timeout"),
                                (OSError("secret path"), "client-failed"),
                                (UnicodeError("secret bytes"), "client-failed")):
            with self.subTest(expected=expected), patch.object(MODULE.subprocess, "run", side_effect=error):
                self.assertEqual(MODULE.check_access("owner/repo", "token"), expected)

    def test_invalid_success_body_fails_closed(self):
        for body in ("", "not JSON", "{}", "null", '"secret"'):
            with self.subTest(body=body), patch.object(MODULE.subprocess, "run", return_value=self.result(stdout=body)):
                self.assertEqual(MODULE.check_access("owner/repo", "token"), "invalid-response")

    def test_failure_output_contains_no_remote_text_or_credential(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            capture = io.StringIO()
            with patch.dict(os.environ, {"GITHUB_REPOSITORY": "owner/repo", "GH_TOKEN": "secret-token",
                                         "GITHUB_OUTPUT": str(output)}), patch.object(
                MODULE.subprocess, "run", return_value=self.result(1, stderr="secret-token private-body (HTTP 403)")
            ), contextlib.redirect_stdout(capture):
                self.assertEqual(MODULE.main(), 1)
            text = capture.getvalue() + output.read_text()
            self.assertIn("http-403", text)
            self.assertNotIn("secret-token", text)
            self.assertNotIn("private-body", text)
            self.assertNotIn("read_access=verified", text)

    def test_success_is_only_read_access_not_write_or_audit_completion(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            capture = io.StringIO()
            with patch.dict(os.environ, {"GITHUB_REPOSITORY": "owner/repo", "GH_TOKEN": "test-token",
                                         "GITHUB_OUTPUT": str(output)}), patch.object(
                MODULE.subprocess, "run", return_value=self.result(stdout='[{"body":"private-body"}]')
            ), contextlib.redirect_stdout(capture):
                self.assertEqual(MODULE.main(), 0)
            self.assertEqual(output.read_text(), "read_access=verified\n")
            self.assertIn("write permission remains unverified", capture.getvalue())
            self.assertNotIn("private-body", capture.getvalue())

    def test_workflow_checks_same_token_before_model_and_reports_failure(self):
        workflow = (ROOT / ".github/workflows/self-improvement.yml").read_text()
        preflight = workflow.index("id: pr_access")
        model = workflow.index("id: managed_self_improvement")
        self.assertLess(preflight, model)
        block = workflow[preflight:workflow.index("\n      #", preflight)]
        self.assertIn("GH_TOKEN: ${{ secrets.SDD_SESSION_PR_TOKEN || github.token }}", block)
        self.assertIn("check-self-improvement-pr-access.py", block)
        self.assertIn("PR_ACCESS_REASON: ${{ steps.pr_access.outputs.failure_reason }}", workflow)
        self.assertIn('reason="$PR_ACCESS_REASON"', workflow)


if __name__ == "__main__":
    unittest.main()
