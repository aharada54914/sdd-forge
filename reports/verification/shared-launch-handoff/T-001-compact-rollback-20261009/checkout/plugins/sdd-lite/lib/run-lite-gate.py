#!/usr/bin/env python3
"""Execute Registry-sourced Lite checks with a bounded argv-direct contract.

This is the executable counterpart of lite-gate's Step 2b.  It deliberately
captures child output instead of inheriting the parent's streams so a caller
can place stdout/stderr and the exit status in a quality report without
mistaking diagnostic output for gate output.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path


CHECK_ID = re.compile(r"^[a-z0-9][a-z0-9-]*$")
BASELINE = {"placeholder", "lint", "typecheck", "build", "test"}
DEFAULT_TIMEOUT = 120.0
DEFAULT_MAX_OUTPUT = 64 * 1024


class RunnerError(Exception):
    """A fail-closed discovery or input error."""


def _load_summary(path: Path) -> dict:
    if path.suffix.lower() in {".yaml", ".yml"}:
        canonicalizer = Path(__file__).resolve().parents[2] / "sdd-quality-loop" / "scripts" / "canonicalize-sdd-yaml.py"
        if not canonicalizer.is_file():
            raise RunnerError("capability-summary canonicalizer is unavailable")
        result = subprocess.run(
            [sys.executable, str(canonicalizer), "--input-format", "yaml", str(path)],
            cwd=str(path.parent),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            detail = result.stderr.strip() or f"exit {result.returncode}"
            raise RunnerError(f"capability-summary canonicalization failed: {detail}")
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            raise RunnerError(f"capability-summary canonicalizer returned non-JSON: {exc}") from exc
    else:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise RunnerError(f"capability-summary unreadable: {exc}") from exc
    validator = Path(__file__).resolve().parents[2] / "sdd-quality-loop" / "scripts" / "validate-capability-summary.py"
    if not validator.is_file():
        raise RunnerError("capability-summary validator is unavailable")
    validation = subprocess.run(
        [sys.executable, str(validator), "--summary", str(path)],
        cwd=str(path.parent),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if validation.returncode != 0:
        detail = validation.stdout.strip() or validation.stderr.strip() or f"exit {validation.returncode}"
        raise RunnerError(f"capability-summary validation failed: {detail}")
    if not isinstance(data, dict):
        raise RunnerError("capability-summary must be an object")
    required = {"schema", "feature", "track", "capabilities", "required_lite_checks", "full_upgrade_required"}
    missing = sorted(required - data.keys())
    if missing:
        raise RunnerError("capability-summary missing: " + ", ".join(missing))
    if data.get("schema") != "sdd-capability-summary/v1" or data.get("track") != "lite":
        raise RunnerError("capability-summary schema or track is invalid")
    if not isinstance(data.get("required_lite_checks"), list):
        raise RunnerError("capability-summary required_lite_checks must be an array")
    if not isinstance(data.get("full_upgrade_required"), bool):
        raise RunnerError("capability-summary full_upgrade_required must be boolean")
    return data


def _safe_pair(root: Path, check_id: str) -> tuple[Path, Path] | None:
    scripts = (root / "scripts").resolve()
    sh_path = root / "scripts" / f"{check_id}.sh"
    ps1_path = root / "scripts" / f"{check_id}.ps1"
    if not sh_path.exists() or not ps1_path.exists():
        return None
    if sh_path.is_symlink() or ps1_path.is_symlink() or not sh_path.is_file() or not ps1_path.is_file():
        return None
    sh_real = sh_path.resolve()
    ps1_real = ps1_path.resolve()
    try:
        sh_real.relative_to(scripts)
        ps1_real.relative_to(scripts)
    except ValueError:
        return None
    return sh_real, ps1_real


def _discover(root: Path, check_id: str, runtime: str) -> tuple[str, list[str]]:
    if not CHECK_ID.fullmatch(check_id):
        raise RunnerError(f"{check_id}: check-id does not match the required grammar")
    package = root / "package.json"
    if package.is_file():
        try:
            package_data = json.loads(package.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise RunnerError(f"package.json unreadable: {exc}") from exc
        scripts = package_data.get("scripts") if isinstance(package_data, dict) else None
        if isinstance(scripts, dict) and check_id in scripts:
            npm = "npm.cmd" if runtime == "powershell" and os.name == "nt" else "npm"
            if shutil.which(npm) is None:
                raise RunnerError(f"{check_id}: npm executable is unavailable")
            return f"npm:{check_id}", [npm, "run", check_id]
    pair = _safe_pair(root, check_id)
    if pair is None:
        raise RunnerError(f"{check_id}: required Lite check has no discoverable command")
    if runtime == "posix":
        return f"scripts:{check_id}", ["sh", str(pair[0])]
    if runtime == "powershell":
        shell = shutil.which("pwsh") or shutil.which("powershell")
        if shell is None:
            raise RunnerError(f"{check_id}: PowerShell executable is unavailable")
        return f"scripts:{check_id}", [shell, "-NoProfile", "-File", str(pair[1])]
    raise RunnerError(f"unsupported runtime: {runtime}")


def _clip(value: str, limit: int) -> tuple[str, bool]:
    raw = value.encode("utf-8", errors="replace")
    if len(raw) <= limit:
        return value, False
    clipped = raw[:limit].decode("utf-8", errors="replace")
    return clipped + "\n[output truncated]", True


def _run_one(root: Path, check_id: str, runtime: str, timeout: float, max_output: int) -> dict:
    started = time.monotonic()
    source, argv = _discover(root, check_id, runtime)
    try:
        result = subprocess.run(
            argv,
            cwd=str(root),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            errors="replace",
            timeout=timeout,
            check=False,
        )
        timed_out = False
        exit_code = result.returncode
        stdout, stdout_truncated = _clip(result.stdout, max_output)
        stderr, stderr_truncated = _clip(result.stderr, max_output)
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        exit_code = None
        raw_stdout = exc.stdout or ""
        raw_stderr = exc.stderr or ""
        if isinstance(raw_stdout, bytes):
            raw_stdout = raw_stdout.decode("utf-8", errors="replace")
        if isinstance(raw_stderr, bytes):
            raw_stderr = raw_stderr.decode("utf-8", errors="replace")
        stdout, stdout_truncated = _clip(raw_stdout, max_output)
        stderr, stderr_truncated = _clip(raw_stderr, max_output)
    duration_ms = round((time.monotonic() - started) * 1000, 3)
    return {
        "id": check_id,
        "source": source,
        "argv": argv,
        "exit_code": exit_code,
        "stdout": stdout,
        "stderr": stderr,
        "stdout_truncated": stdout_truncated,
        "stderr_truncated": stderr_truncated,
        "timed_out": timed_out,
        "duration_ms": duration_ms,
    }


def execute(args: argparse.Namespace) -> tuple[int, dict]:
    root = Path(args.repo_root).resolve()
    if not root.is_dir():
        raise RunnerError(f"repository root is not a directory: {root}")
    summary = None
    if args.enforcement != "none":
        if not args.summary:
            raise RunnerError("capability-summary.yaml missing under active capability_enforcement")
        summary_path = Path(args.summary).resolve()
        if not summary_path.is_file():
            raise RunnerError("capability-summary.yaml missing under active capability_enforcement")
        summary = _load_summary(summary_path)
        if summary["full_upgrade_required"]:
            return 1, {"verdict": "FAIL", "reason": "full_upgrade_required: true", "checks": []}
    required = [] if summary is None else summary["required_lite_checks"]
    checks = []
    for item in required:
        if not isinstance(item, str):
            raise RunnerError("required_lite_checks entries must be strings")
        if item in BASELINE:
            continue
        checks.append(_run_one(root, item, args.runtime, args.timeout, args.max_output_bytes))
    failed = [check for check in checks if check["timed_out"] or check["exit_code"] != 0]
    verdict = "FAIL" if failed else "PASS"
    reason = "all required Lite checks passed" if not failed else "one or more required Lite checks failed"
    return (0 if verdict == "PASS" else 1), {"verdict": verdict, "reason": reason, "checks": checks}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary")
    parser.add_argument("--enforcement", choices=("none", "advisory", "required"), required=True)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--runtime", choices=("posix", "powershell"), required=True)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    parser.add_argument("--max-output-bytes", type=int, default=DEFAULT_MAX_OUTPUT)
    args = parser.parse_args()
    if args.timeout <= 0 or args.max_output_bytes <= 0:
        parser.error("--timeout and --max-output-bytes must be positive")
    try:
        code, payload = execute(args)
    except RunnerError as exc:
        code, payload = 1, {"verdict": "FAIL", "reason": str(exc), "checks": []}
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
