#!/usr/bin/env python3
"""vendor-capability-registry: the vendoring/packaging step (T-003, REQ-005,
ADR-0029's vendored-copy drift check / release gate).

Refreshes `plugins/sdd-quality-loop/contracts/*` from the canonical
top-level `contracts/*` originals (capability-registry.json,
capability-registry.schema.json, lite-upgrade-reason-catalog.json).

Usage:
    vendor-capability-registry.py           writes the vendored copies.
    vendor-capability-registry.py --check   no write; computes both sides'
                                             sha256 in memory and compares;
                                             non-zero exit on any mismatch
                                             (mirrors generate-gate-
                                             capabilities.py --check's own
                                             no-write, non-zero-on-drift
                                             contract exactly).

This step always locates the canonical `contracts/` originals via the
git-root (never the packaged/vendored copy under its own plugin directory,
since it is that vendored copy's own producer -- design.md's Projection
generator contract convention, reused here identically) -- it therefore
only runs meaningfully from within an in-repository checkout, unlike
registry_discovery.py's own three-step procedure, which additionally
supports a standalone install with no monorepo checkout at all.
"""
import argparse
import hashlib
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from registry_discovery import resolve_git_root  # noqa: E402

ARTIFACTS = (
    "capability-registry.json",
    "capability-registry.schema.json",
    "lite-upgrade-reason-catalog.json",
)


def _script_dir() -> Path:
    return Path(__file__).resolve().parent


def _vendored_root() -> Path:
    return _script_dir().parent / "contracts"


def sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else list(argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify vendored copies without writing")
    args = parser.parse_args(argv)

    git_root = resolve_git_root()
    if git_root is None:
        print("vendor-capability-registry: cannot resolve the repository root (no git command and no reachable .git)", file=sys.stderr)
        return 1
    canonical_root = git_root / "contracts"
    vendored_root = _vendored_root()

    stale = []
    for name in ARTIFACTS:
        src = canonical_root / name
        if not src.is_file():
            print(f"vendor-capability-registry: canonical source missing: {src}", file=sys.stderr)
            return 1
        dst = vendored_root / name
        if not dst.is_file() or sha256_file(src) != sha256_file(dst):
            stale.append(name)

    if args.check:
        if stale:
            print("vendor-capability-registry: vendored copies are stale: " + ", ".join(stale), file=sys.stderr)
            return 1
        print("vendor-capability-registry: vendored copies match their canonical sources; no drift.")
        return 0

    vendored_root.mkdir(parents=True, exist_ok=True)
    for name in ARTIFACTS:
        shutil.copyfile(canonical_root / name, vendored_root / name)
    print(f"vendor-capability-registry: vendored {len(ARTIFACTS)} artifact(s) from {canonical_root} to {vendored_root}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
