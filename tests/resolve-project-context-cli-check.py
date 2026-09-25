#!/usr/bin/env python3
"""T-006 driver shared by the POSIX and PowerShell twins for
`resolve-project-context-cli` (design.md Test Strategy item 1, TEST-001/
AC-001): the required-flag argument-validation matrix -- `--config`,
`--target-rev`, `--feature` each rejected as a usage error (exit 2) when
omitted -- plus `--source-rev`'s own CLI default (`HEAD`) reaching
`resolve-component-paths` verbatim when omitted.

Reuses `tests/resolve-project-context-block-check.py`'s own already-
established fixture-repo helpers (`Counts`, `install_scripts`,
`launcher_args`, `read_evidence`), loaded by path via the identical
`_load_module` technique `tests/resolve-project-context-match-check.py`
already uses -- never re-implemented.

Every case here runs against a plain `tempfile.TemporaryDirectory()`, no
`git init` -- design.md step 0's own argument-validation runs before any
filesystem or git work begins at all, so the three missing-required-flag
fixtures need no fixture data whatsoever; the fourth (`--source-rev`
default) only needs step 0-4 to succeed, which a capture-only
`resolve-component-paths` stub (this suite's own fixture, never a real git
repository) already provides -- affected-component resolution itself is
Epic A3's own, out-of-scope concern, already exercised via a real
subprocess by T-003's own suite."""

import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/capability-resolver/resolve-project-context-cli"


def _load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Reused, not reinvented (module docstring, above): the block driver's own
# already-established fixture-repo helpers.
block_check = _load_module(
    Path(__file__).resolve().parent / "resolve-project-context-block-check.py",
    "resolve_project_context_block_check_for_cli",
)


def _run(kind, scripts, argv_tail, cwd):
    argv = block_check.launcher_args(kind, scripts) + argv_tail
    return subprocess.run(argv, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def run_missing_flag_case(kind, counts, flag_name, argv_tail):
    """AC-001: omitting `--config`/`--target-rev`/`--feature` is a usage
    error (exit 2, design.md step 0), never a way to spell a default and
    never a REQ-002 diagnostic-id line -- this invocation never even
    reaches the filesystem, so a plain, empty tempdir is sufficient."""
    case_name = f"missing-{flag_name}"
    with tempfile.TemporaryDirectory(prefix="resolver-cli-") as tmp:
        repo = Path(tmp).resolve()
        scripts = block_check.install_scripts(repo)
        result = _run(kind, scripts, argv_tail, cwd=repo)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(
            result.returncode == 2,
            f"{case_name}: omitting --{flag_name} is rejected as a usage error, exit 2 (AC-001)",
            f"got exit {result.returncode} stdout={stdout!r} stderr={stderr!r}",
        )
        counts.check(
            stdout == "",
            f"{case_name}: no stdout on a usage error (argparse writes only to stderr)",
            repr(stdout),
        )
        counts.check(
            "capability-resolver:" not in stderr,
            f"{case_name}: a usage error never carries this feature's own `capability-resolver: <check-id>:` "
            f"diagnostic-line format -- it is not a Block, and never reaches REQ-002's own enum (design.md step 0)",
            repr(stderr),
        )


def run_source_rev_default_case(kind, counts):
    """AC-001: `--source-rev`'s own omission resolves to the CLI's fixed
    default `HEAD` (design.md API/Contract Plan step 4: `[--source-rev
    <rev>] # default: HEAD`), passed through to `resolve-component-paths`
    verbatim -- never a caller-resolved git sha. Blocked deliberately at
    step 5 (`contract-discovery-failed`, Registry absent) so this
    invocation reaches step 4 (proving argument validation itself already
    passed) without needing any further fixture data."""
    case_name = "source-rev-default"
    fixture_dir = FIXTURES / case_name
    with tempfile.TemporaryDirectory(prefix="resolver-cli-") as tmp:
        repo = Path(tmp).resolve()
        scripts = block_check.install_scripts(repo)
        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")
        shutil.copy2(fixture_dir / "resolve-component-paths.py", scripts / "resolve-component-paths.py")
        argv_tail = [
            "--config", "project-context.yaml",
            "--target-rev", "HEAD",
            "--feature", "example-feature",
        ]
        result = _run(kind, scripts, argv_tail, cwd=repo)
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(
            result.returncode == 1 and "contract-discovery-failed" in stderr,
            f"{case_name}: reaches step 5 (Registry deliberately absent -> contract-discovery-failed), proving "
            f"steps 0-4 (including argument validation) all passed with --source-rev omitted (AC-001 sanity)",
            f"got exit {result.returncode} stderr={stderr!r}",
        )
        capture_path = scripts / "rcp-argv-capture.json"
        captured, parse_error = block_check.read_evidence(capture_path)
        has_source_rev_head = (
            isinstance(captured, list)
            and "--source-rev" in captured
            and captured[captured.index("--source-rev") + 1] == "HEAD"
        )
        counts.check(
            has_source_rev_head,
            f"{case_name}: resolve-component-paths received --source-rev HEAD verbatim -- the CLI's own fixed "
            f"default value, never a caller-resolved sha (AC-001)",
            parse_error or repr(captured),
        )


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = block_check.Counts()

    required_files = [block_check.STAGED / f"resolve-project-context.{suffix}" for suffix in ("py", "sh", "ps1")]
    if not all(path.is_file() for path in required_files):
        counts.check(False, "staged implementation exists", "TDD RED: implementation absent")
    else:
        run_missing_flag_case(args.launcher, counts, "config", ["--target-rev", "HEAD", "--feature", "example-feature"])
        run_missing_flag_case(args.launcher, counts, "target-rev", ["--config", "project-context.yaml", "--feature", "example-feature"])
        run_missing_flag_case(args.launcher, counts, "feature", ["--config", "project-context.yaml", "--target-rev", "HEAD"])
        run_source_rev_default_case(args.launcher, counts)

    sh_registered = "tests/resolve-project-context-cli.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-cli.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
