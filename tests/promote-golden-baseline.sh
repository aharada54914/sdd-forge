#!/usr/bin/env bash
set -euo pipefail

# These guards intentionally precede root discovery and every candidate or
# canonical filesystem operation. CI is fail-closed for every non-empty value.
if [[ -n "${CI:-}" ]]; then
  printf 'promote-golden-baseline: promotion is forbidden when CI is non-empty\n' >&2
  exit 2
fi
if [[ $# -ne 3 || "${2:-}" != "--approved-by" || -z "${3//[[:space:]]/}" ]]; then
  printf 'Usage: %s <candidate-path> --approved-by <human-identifier>\n' "$0" >&2
  exit 2
fi

candidate="$1"
approved_by="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

exec python3 - "$ROOT" "$candidate" "$approved_by" <<'PY'
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

PRE_CAPABILITY_SHA = "50b20364e996432cb06061df03ffb4d173c27fa6"
SCHEMA_VERSION = "golden-baseline-manifest/v1"
BASELINE_RELATIVE = Path("specs/epic-195-a7-compatibility/verification/golden-baseline")
TARGETS = (
    ("deterministic-script-output", "targets/deterministic-script-output.bin", "raw stdout/stderr byte-tuple"),
    ("exit-code", "targets/exit-code.txt", "status integer"),
    ("stdout-stderr", "targets/stdout-stderr.bin", "raw stdout/stderr byte-tuple"),
    ("template-copy-result", "targets/template-copy-result.sha256", "filesystem manifest (path -> sha256)"),
    ("schema-validator-result", "targets/schema-validator-result.txt", "status integer"),
    ("install-result", "targets/install-result.sha256", "filesystem manifest"),
    ("uninstall-result", "targets/uninstall-result.sha256", "filesystem manifest"),
    ("generated-directory-listing", "targets/generated-directory-listing.txt", "filesystem manifest"),
    ("plugin-manifest", "targets/plugin-manifest.sha256", "filesystem manifest (path -> sha256)"),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inside(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def validate(repo: Path, candidate: Path, candidate_root: Path) -> None:
    if not candidate.is_dir() or candidate.is_symlink() or not inside(candidate, candidate_root):
        raise ValueError("candidate must be a real directory below the gitignored candidate root")
    for item in candidate.rglob("*"):
        if item.is_symlink():
            raise ValueError("candidate must not contain symbolic links")
    manifest_path = candidate / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("candidate manifest is missing or invalid") from exc
    if set(manifest) != {"capture_scripts", "fixed_environment", "pre_capability_commit_sha", "schema_version", "targets"}:
        raise ValueError("candidate manifest has an invalid field set")
    if manifest["schema_version"] != SCHEMA_VERSION or manifest["pre_capability_commit_sha"] != PRE_CAPABILITY_SHA:
        raise ValueError("candidate manifest identity does not match the contract")
    if manifest["fixed_environment"] != {"LC_ALL": "C", "TZ": "UTC", "ambient_sdd_variables": []}:
        raise ValueError("candidate fixed environment does not match the contract")
    expected_scripts = ("tests/capture-golden-baseline.sh", "tests/capture-golden-baseline.ps1")
    scripts = manifest["capture_scripts"]
    if not isinstance(scripts, list) or [entry.get("path") for entry in scripts if isinstance(entry, dict)] != list(expected_scripts):
        raise ValueError("candidate capture-script inventory does not match the contract")
    for entry in scripts:
        if set(entry) != {"path", "sha256"} or entry["sha256"] != sha256(repo / entry["path"]):
            raise ValueError("candidate capture-script hash does not match the live script")
    targets = manifest["targets"]
    expected = [(name, path, capture_format) for name, path, capture_format in TARGETS]
    if not isinstance(targets, list) or [(entry.get("name"), entry.get("path"), entry.get("capture_format")) for entry in targets if isinstance(entry, dict)] != expected:
        raise ValueError("candidate target inventory does not match the contract")
    allowed_files = {"manifest.json"}
    for entry in targets:
        if set(entry) != {"capture_format", "name", "path", "sha256"}:
            raise ValueError("candidate target entry has an invalid field set")
        relative = Path(entry["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("candidate target path is unsafe")
        target = candidate / relative
        if not target.is_file() or entry["sha256"] != sha256(target):
            raise ValueError("candidate target hash does not match its artifact")
        allowed_files.add(relative.as_posix())
    actual_files = {path.relative_to(candidate).as_posix() for path in candidate.rglob("*") if path.is_file()}
    if actual_files != allowed_files:
        raise ValueError("candidate contains an undeclared or missing file")


def promote(repo: Path, candidate_argument: str) -> None:
    baseline = (repo / BASELINE_RELATIVE).resolve()
    candidate_root = (baseline / "candidate").resolve()
    candidate = Path(candidate_argument).expanduser().resolve()
    validate(repo, candidate, candidate_root)
    canonical = baseline / "canonical"
    stage = Path(tempfile.mkdtemp(prefix=".canonical-stage-", dir=baseline))
    backup = baseline / ".canonical-backup"
    try:
        shutil.rmtree(stage)
        shutil.copytree(candidate, stage)
        if backup.exists():
            shutil.rmtree(backup)
        if canonical.exists():
            os.replace(canonical, backup)
        try:
            os.replace(stage, canonical)
        except BaseException:
            if backup.exists() and not canonical.exists():
                os.replace(backup, canonical)
            raise
        if backup.exists():
            shutil.rmtree(backup)
    finally:
        if stage.exists():
            shutil.rmtree(stage)


try:
    repository = Path(sys.argv[1]).resolve()
    promote(repository, sys.argv[2])
    print(f"golden baseline promoted by {sys.argv[3]}")
except (OSError, ValueError) as exc:
    print(f"promote-golden-baseline: {exc}", file=sys.stderr)
    raise SystemExit(1)
PY
