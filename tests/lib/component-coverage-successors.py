"""Exact reviewed successors to two shared A3 archive entries.

A9 T-002 intentionally updates these prechecks (commit b40dc88f); hashes match
its reviewed-candidate-manifest.json, accepted at 021cf42c. The A3 archive stays
immutable. This is a byte binding, not a path exemption or a formal gate verdict.
"""
import hashlib
import json
from pathlib import Path
import sys
import tempfile

SUCCESSORS = {
    "plugins/sdd-review-loop/scripts/spec-review-precheck.sh":
        "4032fa28afdfbc6a2af871d4c76b97313d831fb1e87aa7eed752633be3513474",
    "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1":
        "e962f3f179e0e697ef6f645b7ab6eb082a06050f735ed24bf716b76e157bc42e",
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
