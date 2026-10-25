"""Exact research successors of the frozen A3 consumer files; test-only."""
import copy
import hashlib
import json
from pathlib import Path
import sys


PATHS = (
    "plugins/sdd-quality-loop/scripts/check-contract.py",
    "plugins/sdd-quality-loop/scripts/check-contract.ps1",
    "plugins/sdd-review-loop/scripts/spec-review-precheck.sh",
    "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1",
)
STAGE = "specs/epic-191-a3-path-ownership/human-copy/"


def validate(root, data):
    if data.get("schema") != "research-consumer-current-publication/v1":
        raise ValueError("unknown successor schema")
    entries = data.get("successors", [])
    if [entry.get("live") for entry in entries] != list(PATHS):
        raise ValueError("missing, duplicate or unexpected successor")
    manifest = dict(line.split(None, 1)[::-1] for line in
                    (root / STAGE / "MANIFEST.sha256").read_text().splitlines()
                    if line and not line.startswith("#"))
    for entry in entries:
        name = entry["live"]
        if entry["staged"] != STAGE + name:
            raise ValueError("wrong staged predecessor")
        for field in ("staged", "live"):
            digest = hashlib.sha256((root / entry[field]).read_bytes()).hexdigest()
            if digest != entry[field + "_sha256"]:
                raise ValueError("successor drift: " + name)
        if entry["staged_sha256"] != manifest[name]:
            raise ValueError("frozen manifest mismatch")
    return list(PATHS)


def checked_paths(root):
    data = json.loads((root / "tests/fixtures/research-consumer-current-publication.json").read_text())
    paths = validate(root, data)
    # Each admitted pair must retain both exact hashes and its predecessor path.
    mutations = []
    for index in range(len(PATHS)):
        for field in ("staged_sha256", "live_sha256", "staged"):
            changed = copy.deepcopy(data)
            changed["successors"][index][field] = "0" * 64
            mutations.append(changed)
    for entries in (data["successors"][:-1], data["successors"] * 2):
        changed = copy.deepcopy(data)
        changed["successors"] = entries
        mutations.append(changed)
    for changed in mutations:
        try:
            validate(root, changed)
        except (ValueError, OSError):
            continue
        raise AssertionError("successor mutation accepted")
    return paths


if __name__ == "__main__":
    try:
        print(json.dumps(checked_paths(Path(sys.argv[1]))))
    except (ValueError, OSError, KeyError, TypeError, AssertionError) as error:
        sys.exit(str(error))
