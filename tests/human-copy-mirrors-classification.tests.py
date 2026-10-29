#!/usr/bin/env python3
"""Focused regression checks for human-copy mirror classification."""
import hashlib
import importlib.util
import json
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
    for fixture_name in ('ship-track-selection-current-publication.json', 'decision-sidecar-current-publication.json'):
        fixture = json.loads((ROOT / 'tests/fixtures' / fixture_name).read_text())
        for entry in fixture['successors']:
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                live, staged = root / entry['live'], root / entry['staged']
                for target, original in ((staged, ROOT / entry['staged']), (live, ROOT / entry['live'])):
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(original.read_bytes())
                bundle = staged
                for _ in Path(entry['live']).parts:
                    bundle = bundle.parent
                (bundle / 'MANIFEST.sha256').write_text(f"{entry['staged_sha256']}  {entry['live']}\n")
                pin = root / 'tests/fixtures' / fixture_name
                pin.parent.mkdir(parents=True)
                pin.write_text(json.dumps(fixture))
                assert states(root, entry['staged_sha256']) == ['PENDING']
                live.write_bytes(live.read_bytes() + b'changed')
                assert states(root, entry['staged_sha256']) == ['STALE']
                live.write_bytes(staged.read_bytes())
                assert states(root, entry['staged_sha256']) == ['FRESH']
                duplicate = dict(fixture, successors=fixture['successors'] + [entry])
                pin.write_text(json.dumps(duplicate))
                assert states(root, entry['staged_sha256']) == ['STALE']
                pin.write_text(json.dumps(fixture))
                staged.write_bytes(b'changed staged')
                live.write_bytes(staged.read_bytes())
                assert states(root, entry['staged_sha256']) == ['STALE']
                pin.unlink()
                assert states(root, entry['staged_sha256']) == ['STALE']
    print("human-copy mirror classification regression: 26 passed")


if __name__ == "__main__":
    main()
