#!/usr/bin/env python3
"""A-2 unit regressions against the UNMODIFIED function in --repo.

Only the declaration-discovery function is extracted; git and fingerprinting
are deterministic test doubles. This is not a complete quality-gate run.
All fixture writes are restricted to a TemporaryDirectory owned by the test.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

PARSER = argparse.ArgumentParser()
PARSER.add_argument("--repo", required=True, type=Path)
ARGS, REST = PARSER.parse_known_args()
SOURCE = (ARGS.repo / "plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh").read_text()
START = SOURCE.index("_ppi_declaration_commit() {")
END = SOURCE.index("\n# Fingerprint of a report", START)
FUNCTION = SOURCE[START:END]

PREAMBLE = r'''
exec 3>&2
umask 022
project_root="$FIXTURE_ROOT"
feature=fixture
task_id=T-001
_ppi_decl_commit_checked=0
_ppi_decl_commit=''
_ppi_decl_report_abs="$FIXTURE_ROOT/report.md"
_ppi_outputs_fingerprint() {
    if [ "$CASE" = fingerprint_failure ] && [ "$1" != "$_ppi_decl_report_abs" ]; then
        return 1
    fi
    printf 'fingerprint\n'
}
git() {
    case "$3" in
        rev-parse) return 0 ;;
        log)
            if [ "$4" = -1 ]; then printf 'FALLBACK\n' >&3; fi
            printf 'abcdef\n'
            ;;
        show)
            for observed_file in "$TMPDIR"/ppi-decl-scan-*; do
                [ -e "$observed_file" ] || continue
                if [ "$(uname -s)" = Darwin ]; then
                    observed_mode=$(stat -f '%Lp' "$observed_file")
                else
                    observed_mode=$(stat -c '%a' "$observed_file")
                fi
                printf 'MODE:%s\n' "$observed_mode" >&3
            done
            if [ "$CASE" = show_failure ]; then return 1; fi
            printf 'historical report bytes\n'
            ;;
        *) return 90 ;;
    esac
}
if [ "$CASE" = allocation_failure ]; then
    mktemp() { return 1; }
fi
if [ "$CASE" = symlink ]; then
    ln -s "$FIXTURE_ROOT/sentinel" "$TMPDIR/ppi-decl-scan-$$"
fi
'''

POSTAMBLE = r'''
if _ppi_declaration_commit; then
    printf 'RESULT:0:%s\n' "$_ppi_decl_commit"
else
    printf 'RESULT:1:%s\n' "$_ppi_decl_commit"
fi
'''


class AnchorTemporaryFileTests(unittest.TestCase):
    def run_case(self, case):
        with tempfile.TemporaryDirectory(prefix="pr389-a2-") as owned:
            fixture = Path(owned)
            temp = fixture / "temp"
            temp.mkdir()
            sentinel = fixture / "sentinel"
            sentinel.write_text("KEEP\n")
            env = dict(os.environ, FIXTURE_ROOT=owned, TMPDIR=str(temp), CASE=case)
            result = subprocess.run(
                ["/bin/bash", "-c", PREAMBLE + FUNCTION + POSTAMBLE],
                env=env, text=True, capture_output=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            # Ignore the deliberately planted symlink, not allocated files.
            leftovers = [p.name for p in temp.iterdir() if not p.is_symlink()]
            return result, sentinel.read_text(), leftovers

    def test_success_uses_private_file_and_cleans_it(self):
        result, _, leftovers = self.run_case("success")
        self.assertIn("RESULT:0:abcdef", result.stdout)
        self.assertIn("MODE:600", result.stderr)
        self.assertEqual(leftovers, [])

    def test_predictable_symlink_does_not_overwrite_target(self):
        result, sentinel, leftovers = self.run_case("symlink")
        self.assertIn("RESULT:0:abcdef", result.stdout)
        self.assertEqual(sentinel, "KEEP\n")
        self.assertEqual(leftovers, [])

    def test_allocation_failure_cannot_reach_anchor_or_fallback(self):
        result, _, leftovers = self.run_case("allocation_failure")
        self.assertIn("RESULT:1:", result.stdout)
        self.assertNotIn("FALLBACK", result.stderr)
        self.assertEqual(leftovers, [])

    def test_git_show_failure_cleans_and_fails_closed(self):
        result, _, leftovers = self.run_case("show_failure")
        self.assertIn("RESULT:1:", result.stdout)
        self.assertNotIn("FALLBACK", result.stderr)
        self.assertEqual(leftovers, [])

    def test_fingerprint_failure_cleans_and_fails_closed(self):
        result, _, leftovers = self.run_case("fingerprint_failure")
        self.assertIn("RESULT:1:", result.stdout)
        self.assertNotIn("FALLBACK", result.stderr)
        self.assertEqual(leftovers, [])


if __name__ == "__main__":
    unittest.main(argv=[__file__] + REST)
