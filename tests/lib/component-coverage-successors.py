"""Exact reviewed successors to two shared A3 archive entries.

A9 T-002 introduced the recovery route; these exact T-003 consumer bytes
received independent source review. Earlier T-002 bindings and the A3 archive
stay immutable. This is a byte binding, not a path exemption or a formal gate verdict.
"""
import hashlib
import json
from pathlib import Path
import sys
import tempfile

SUCCESSORS = {
    "plugins/sdd-review-loop/scripts/spec-review-precheck.sh":
        "69e7b47f7b17b6b46955ac983bb226023a26d6ad2c8f5db221976a4d12b134ec",
    "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1":
        "2f5976784b03e1ee79d4f946774235e8575b0e4f25d194a13861d38ab4de9b64",
}


def validate(repo):
    for relative, expected in SUCCESSORS.items():
        if hashlib.sha256((repo / relative).read_bytes()).hexdigest() != expected:
            raise ValueError("reviewed successor hash mismatch: " + relative)


def self_test(repo):
    validate(repo)
    with tempfile.TemporaryDirectory(prefix="coverage-successors-") as directory:
        candidate = Path(directory)
        for relative in SUCCESSORS:
            path = candidate / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((repo / relative).read_bytes())
        validate(candidate)
        for relative in SUCCESSORS:
            path = candidate / relative
            original = path.read_bytes()
            for replacement in (original + b"\n", b""):
                path.write_bytes(replacement)
                try:
                    validate(candidate)
                except ValueError:
                    pass
                else:
                    raise AssertionError("accepted changed successor: " + relative)
            path.unlink()
            try:
                validate(candidate)
            except FileNotFoundError:
                pass
            else:
                raise AssertionError("accepted missing successor: " + relative)
            path.write_bytes(original)


if __name__ == "__main__":
    self_test(Path(sys.argv[1]))
    print(json.dumps(SUCCESSORS))
