#!/usr/bin/env python3
"""Human-only, hash-fixed staging in the isolated clone or approved worktree."""

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path


SOURCE = Path("/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge")
CLONE = Path("/private/tmp/issue423-resolver-regression.CfwaIT/checkout")
MODE = "isolated-clone"
if sys.argv[1:] == ["--owner-worktree"]:
    CLONE = SOURCE
    MODE = "owner-worktree"
elif sys.argv[1:]:
    print("usage: human-stage-isolated-clone.py [--owner-worktree]", file=sys.stderr)
    raise SystemExit(2)
HEAD = "06bc32cc26f2d67adb02e827610b5230e1658f72"
HERE = SOURCE / "specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001"
REGISTRY = HERE / "candidate/capability-registry.candidate.json"
PYTHON = HERE / "candidate/resolve-project-context.candidate.py"
REGISTRY_HASH = "42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1"
PYTHON_HASH = "ae27deb32d5af3d31dcbfd505812fd737603a9d682476451a855d48fb36ed511"
OLD_REGISTRY = "737af6db85d6ec9e31ad087acb358ea34de1e1d57f4ad4f2ffe2017c64d91278"
OLD_PYTHON = "26a1f3e547ee3bdcaf2bd330f5c06922603facb3f2164c45095c4327929035c7"
TARGETS = {
    "contracts/capability-registry.json": OLD_REGISTRY,
    "plugins/sdd-quality-loop/contracts/capability-registry.json": OLD_REGISTRY,
    "plugins/sdd-quality-loop/scripts/resolve-project-context.py": OLD_PYTHON,
    "specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.py": OLD_PYTHON,
    "plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json": "aa0a6b18cdd561b08ad95c89db8fd08138d2eef0e36aac3d4f7fa15af152e575",
    "specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256": "33c78b3c18fe27dafeba9b542a307b7b3b41a26823b100f98707c9e2bdabdd04",
}
GENERATOR = CLONE / "plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py"
PROJECTION = "plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json"
MANIFEST = "specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256"
MANIFEST_LINE = OLD_PYTHON + "  plugins/sdd-quality-loop/scripts/resolve-project-context.py\n"
NEW_MANIFEST_LINE = PYTHON_HASH + MANIFEST_LINE[64:]
GENERATOR_HASH = "fba1559b635fedaa30b2e4cf716143e31ccf8f7d7b8bffd21f83fe4fca2b3eaa"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.run(["git", "-C", str(CLONE), *args], capture_output=True, text=True, check=True).stdout.strip()


def main():
    if CLONE.resolve() != CLONE:
        raise RuntimeError("target root path changed")
    if git("rev-parse", "HEAD") != HEAD or Path(git("rev-parse", "--show-toplevel")) != CLONE:
        raise RuntimeError("clone HEAD or root changed")
    if git("status", "--porcelain", "--", str(GENERATOR.relative_to(CLONE))):
        raise RuntimeError("projection generator is dirty; no write")
    if digest(GENERATOR.read_bytes()) != GENERATOR_HASH:
        raise RuntimeError("projection generator hash changed; no write")
    registry = REGISTRY.read_bytes()
    python = PYTHON.read_bytes()
    if digest(registry) != REGISTRY_HASH or digest(python) != PYTHON_HASH:
        raise RuntimeError("candidate hash changed")

    current = {}
    for relative in TARGETS:
        path = CLONE / relative
        if path.is_symlink() or not path.is_file():
            raise RuntimeError(f"missing or symlink target: {relative}")
        current[relative] = path.read_bytes()
    manifest = current[MANIFEST].decode("utf-8")
    if manifest.count(MANIFEST_LINE) + manifest.count(NEW_MANIFEST_LINE) != 1:
        raise RuntimeError("A5 manifest resolver entry changed")

    with tempfile.TemporaryDirectory(prefix="issue423-projection-preview-") as preview:
        preview_root = Path(preview)
        preview_registry = preview_root / "contracts/capability-registry.json"
        preview_registry.parent.mkdir(parents=True)
        preview_registry.write_bytes(registry)
        subprocess.run([sys.executable, str(GENERATOR), "--repo-root", preview], check=True)
        projection = (preview_root / PROJECTION).read_bytes()

    expected = {
        **{relative: registry for relative in list(TARGETS)[:2]},
        **{relative: python for relative in list(TARGETS)[2:4]},
        PROJECTION: projection,
        MANIFEST: manifest.replace(MANIFEST_LINE, NEW_MANIFEST_LINE).encode("utf-8"),
    }
    if all(current[relative] == expected[relative] for relative in TARGETS):
        print(f"ALREADY_APPLIED: all six {MODE} targets match candidate bytes")
        return
    if any(digest(current[relative]) != baseline for relative, baseline in TARGETS.items()):
        raise RuntimeError("unknown or partially applied target hash; no write")
    if git("status", "--porcelain", "--", *TARGETS):
        raise RuntimeError("dirty target in clone; no write")
    if not sys.stdin.isatty():
        raise RuntimeError("interactive human terminal required; no write")
    confirmation = "APPLY-ISSUE423-" + MODE.upper()
    print(f"TARGET: {CLONE}", flush=True)
    if input(f"Type {confirmation} to stage these six targets only: ") != confirmation:
        raise RuntimeError("human confirmation not received; no write")

    backup = Path(tempfile.mkdtemp(prefix="issue423-human-stage-backup-"))
    for relative, data in current.items():
        path = backup / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    print(f"BACKUP: {backup}", flush=True)
    try:
        for relative in list(TARGETS)[:4] + [MANIFEST]:
            (CLONE / relative).write_bytes(expected[relative])
        subprocess.run([sys.executable, str(GENERATOR), "--repo-root", str(CLONE)], check=True)
        subprocess.run([sys.executable, str(GENERATOR), "--repo-root", str(CLONE), "--check"], check=True)
        for relative, data in expected.items():
            actual = (CLONE / relative).read_bytes()
            if actual != data:
                raise RuntimeError(f"readback mismatch: {relative}")
            print(f"READBACK SHA-256 {digest(actual)}  {relative}")
    except Exception:
        print(f"INCOMPLETE: clone may be partially staged; backup preserved at {backup}; no rollback", file=sys.stderr)
        raise
    print(f"STAGED: six {MODE} targets match candidate and generated projection; backup {backup}")
    print("This application runs no regression drivers, formal review, CI, commit, push or merge.")
    if MODE == "isolated-clone":
        print("Owner-worktree application was not performed.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"human-stage-isolated-clone: {exc}", file=sys.stderr)
        raise SystemExit(1)
