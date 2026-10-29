#!/usr/bin/env python3
"""Focused regression checks for human-copy mirror classification."""
import hashlib
import importlib.util
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "human_copy_mirrors", ROOT / "scripts" / "human_copy_mirrors.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class MainDigests:
    def __init__(self, digest):
        self.digest = digest

    def get(self, _rel):
        return self.digest


def setup_bundle(root: Path) -> None:
    bundle = root / "specs" / "fixture" / "human-copy"
    bundle.mkdir(parents=True)
    staged = bundle / "plugins" / "example.txt"
    staged.parent.mkdir(parents=True)
    staged.write_text("reviewed candidate\n", encoding="utf-8")
    digest = hashlib.sha256(staged.read_bytes()).hexdigest()
    (bundle / "MANIFEST.sha256").write_text(
        f"{digest}  plugins/example.txt\n", encoding="utf-8"
    )


def states(root: Path, main_digest):
    return [row[0] for row in MODULE.classify(str(root), MainDigests(main_digest))]


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        setup_bundle(root)
        assert states(root, None) == ["PENDING"], "new human-copy file must remain pending"
        staged = root / "specs" / "fixture" / "human-copy" / "plugins" / "example.txt"
        assert states(root, hashlib.sha256(staged.read_bytes()).hexdigest()) == ["MISSING"], (
            "missing file that exists on main must remain a failure"
        )
        live = root / "plugins" / "example.txt"
        live.parent.mkdir(parents=True)
        live.write_text("second branch edit\n", encoding="utf-8")
        before = {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
        main_digest = hashlib.sha256(b"main bytes\n").hexdigest()
        assert states(root, main_digest) == ["PENDING"], "ambiguous second edit must stay pending"
        assert before == {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}, (
            "classification must not modify reviewed bytes"
        )
        assert states(root, hashlib.sha256(staged.read_bytes()).hexdigest()) == ["STALE"]
        live.write_bytes(staged.read_bytes())
        assert states(root, main_digest) == ["FRESH"]
    print("human-copy mirror classification regression: 6 passed")


if __name__ == "__main__":
    main()
