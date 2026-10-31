#!/usr/bin/env python3
"""Preflight caller delivery before delegating an optional identity reservation."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys


class DeliveryError(ValueError):
    pass


def digest(data):
    return hashlib.sha256(data).hexdigest()


def regular(root, relative):
    path = root
    for part in relative.parts:
        path = path / part
        if path.is_symlink():
            raise DeliveryError("fixture-symlink")
    if not path.is_file():
        raise DeliveryError("fixture-input-missing")
    return path


def check(manifest, expected, repository, scratch=None, reserve=False):
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise DeliveryError("caller-pin-invalid")
    if manifest.is_symlink() or not manifest.is_file():
        raise DeliveryError("manifest-not-regular")
    raw = manifest.read_bytes()
    if digest(raw) != expected:
        raise DeliveryError("caller-pin-mismatch")
    document = json.loads(raw)
    if (document.get("schema") != "review-context-invocation/v2"
            or document.get("stage") != "quality"
            or document.get("role") != "sdd-evaluator"
            or document.get("read_only") is not True):
        raise DeliveryError("invocation-kind-invalid")
    entries = document.get("allowed_input_manifest")
    if not isinstance(entries, list) or not entries:
        raise DeliveryError("admitted-inputs-missing")
    repository = repository.resolve(strict=True)
    validator = Path(__file__).with_name("validate-review-context-set.sh")
    result = subprocess.run(["bash", str(validator), str(manifest.resolve()), str(repository)],
                            capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        # Only the validator's bounded category is exposed, never its raw log.
        category = re.search(r"\bREVIEW_CONTEXT_([A-Z_]+):", result.stderr + result.stdout)
        raise DeliveryError("canonical-" + (category.group(1).lower() if category else "rejected"))
    if manifest.read_bytes() != raw:
        raise DeliveryError("manifest-changed")
    if scratch is not None:
        scratch = scratch.resolve(strict=True)
        if str(scratch) != document.get("scratch_root"):
            raise DeliveryError("fixture-root-mismatch")
        if scratch == repository or repository in scratch.parents or scratch in repository.parents:
            raise DeliveryError("fixture-overlaps-repository")
    for entry in entries:
        name, sha = entry.get("path"), entry.get("sha256")
        relative = PurePosixPath(name)
        for root in ([scratch] if scratch is not None else []):
            if digest(regular(root, relative).read_bytes()) != sha:
                raise DeliveryError("fixture-hash-mismatch")
    if reserve:
        if manifest.read_bytes() != raw:
            raise DeliveryError("manifest-changed")
        result = subprocess.run(["bash", str(validator), str(manifest.resolve()), str(repository), "--reserve"],
                                capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            raise DeliveryError("reservation-rejected")
        print(result.stdout, end="")
    return len(entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--scratch-root", type=Path)
    parser.add_argument("--reserve", action="store_true")
    args = parser.parse_args()
    try:
        count = check(args.manifest, args.manifest_sha256, args.repository_root, args.scratch_root, args.reserve)
    except DeliveryError as error:
        print(f"EVALUATOR_DELIVERY_REJECTED: {error}", file=sys.stderr)
        return 1
    except (OSError, ValueError, TypeError, AttributeError, subprocess.TimeoutExpired):
        print("EVALUATOR_DELIVERY_REJECTED: unreadable-or-malformed-input", file=sys.stderr)
        return 1
    print(f"EVALUATOR_DELIVERY_OK inputs={count}; reservation={'performed' if args.reserve else 'not performed'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
