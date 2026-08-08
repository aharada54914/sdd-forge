#!/usr/bin/env python3
"""registry_discovery: the Registry discovery contract (T-003, REQ-005,
ADR-0025, docs/adr/0025-registry-discovery-contract.md).

Shared helper module -- imported by validate-capability-registry.py (T-004)
for the lite-upgrade-reason-catalog lookup and generate-registry-digest.py
(T-005) for the Registry lookup. Also directly runnable as a CLI for this
task's own test suite (see `main` below); the documented, long-term usage
is `import registry_discovery` from a script co-located in this same
`plugins/sdd-quality-loop/scripts/` directory.

Resolution order (Security Boundary B4 -- fail-closed, never a silent
stale/absent fallback):
  1. Script-relative packaged copy: `<this-directory>/../contracts/<filename>`,
     resolved from this module's own real, symlink-resolved location -- no
     runtime environment variable of any kind is consulted, and no host
     process identity is inspected.
  2. git-root fallback: `git rev-parse --show-toplevel` (or, if `git` is
     unavailable, an upward walk to the nearest `.git`) + `/contracts/<filename>`.
  3. Fail closed: if neither location exists, or the artifact that DOES
     exist fails its own per-artifact version check, this raises
     DiscoveryError with a diagnostic naming every attempted path and the
     version-check result. A location that exists is fail-closed at that
     point -- discovery does not fall through to try the other location
     merely because the first one it found had a bad version, since doing
     so would itself be a silent, undocumented second resolution path.
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

# The exact $id this Epic's own capability-registry.schema.json declares
# (T-001). The per-artifact version check for the schema file confirms the
# discovered file's own $id equals this expected value, not merely that an
# $id key exists -- this is what makes the check a genuine version/identity
# check rather than a tautological self-reference.
EXPECTED_SCHEMA_ID = "https://github.com/aharada54914/sdd-forge/contracts/capability-registry.schema.json"


class DiscoveryError(Exception):
    """Raised for any fail-closed discovery/version-check failure."""


def _module_dir() -> Path:
    return Path(__file__).resolve().parent


def _packaged_path(filename: str) -> Path:
    return _module_dir().parent / "contracts" / filename


def resolve_git_root() -> "Path | None":
    """git rev-parse --show-toplevel, falling back to an upward .git walk
    if the git command itself is unavailable. Returns None if neither
    resolves. Exposed publicly so vendor-capability-registry.py (T-003's
    own packaging step) can reuse the identical resolution instead of a
    second, divergent implementation."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            cwd=str(_module_dir()),
        )
        if result.returncode == 0:
            candidate = result.stdout.strip()
            if candidate:
                return Path(candidate)
    except (OSError, FileNotFoundError):
        pass

    current = _module_dir()
    for _ in range(64):
        if (current / ".git").exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    return None


def _git_root_path(filename: str) -> "Path | None":
    root = resolve_git_root()
    if root is None:
        return None
    return root / "contracts" / filename


def _load_json(path: Path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def check_capability_registry(doc) -> bool:
    return isinstance(doc, dict) and doc.get("schema") == "capability-registry/v1"


def check_capability_registry_schema(doc) -> bool:
    return (
        isinstance(doc, dict)
        and "$schema" in doc
        and doc.get("$id") == EXPECTED_SCHEMA_ID
    )


def check_lite_upgrade_reason_catalog(doc) -> bool:
    return isinstance(doc, dict) and doc.get("schema") == "lite-upgrade-reason-catalog/v1"


VERSION_CHECKS = {
    "capability-registry.json": check_capability_registry,
    "capability-registry.schema.json": check_capability_registry_schema,
    "lite-upgrade-reason-catalog.json": check_lite_upgrade_reason_catalog,
}


def _verify(path: Path, filename: str):
    """Returns (ok: bool, detail: str)."""
    check = VERSION_CHECKS.get(filename)
    if check is None:
        return False, f"no version check registered for {filename!r}"
    try:
        doc = _load_json(path)
    except (OSError, json.JSONDecodeError) as exc:
        return False, f"cannot read/parse: {exc}"
    if check(doc):
        return True, "ok"
    return False, "version check failed"


def discover_artifact(filename: str) -> Path:
    """Resolve `filename` (one of VERSION_CHECKS' keys) per the three-step
    procedure above. Returns the resolved, verified Path. Raises
    DiscoveryError (fail-closed) otherwise."""
    if filename not in VERSION_CHECKS:
        raise DiscoveryError(f"registry-discovery: no version check registered for {filename!r}")

    attempted = []

    packaged = _packaged_path(filename)
    attempted.append(str(packaged))
    if packaged.is_file():
        ok, detail = _verify(packaged, filename)
        if ok:
            return packaged
        raise DiscoveryError(
            "registry-discovery: fail-closed -- packaged copy exists but failed its "
            f"version check: {packaged} ({detail}); attempted paths: {attempted}"
        )

    git_path = _git_root_path(filename)
    if git_path is not None:
        attempted.append(str(git_path))
        if git_path.is_file():
            ok, detail = _verify(git_path, filename)
            if ok:
                return git_path
            raise DiscoveryError(
                "registry-discovery: fail-closed -- git-root copy exists but failed its "
                f"version check: {git_path} ({detail}); attempted paths: {attempted}"
            )
    else:
        attempted.append("<git-root: unresolved (no git command and no reachable .git)>")

    raise DiscoveryError(
        f"registry-discovery: fail-closed -- {filename!r} not found at any attempted "
        f"location: {attempted}"
    )


def main(argv=None) -> int:
    """CLI mode for this task's own test suite: `registry_discovery.py
    <filename>` resolves and prints the resolved path on success (exit 0),
    or prints the fail-closed diagnostic on stderr (exit 1)."""
    argv = sys.argv[1:] if argv is None else list(argv)
    if len(argv) != 1:
        print("usage: registry_discovery.py <capability-registry.json|capability-registry.schema.json|lite-upgrade-reason-catalog.json>", file=sys.stderr)
        return 2
    try:
        resolved = discover_artifact(argv[0])
    except DiscoveryError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(str(resolved))
    return 0


if __name__ == "__main__":
    sys.exit(main())
