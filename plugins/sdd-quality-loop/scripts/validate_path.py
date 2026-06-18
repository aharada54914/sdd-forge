"""R-01: Shared path-validation utility for SDD gate scripts.

Imported by check-contract.py and check-evidence-bundle.py via __file__-relative
sys.path insertion. If this module is missing at import time, the calling script
must exit 1 (fail-closed) — not skip validation silently.

Usage:
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from validate_path import validate_evidence_path

    failures = []
    # label should be e.g. "check 'lint' evidence" or "check 'unit-tests' red_evidence"
    validate_evidence_path("check 'lint' evidence", evidence_str, root, failures)

Message format (matches original inline-Python exactly — tested in gates.tests.sh):
    "{label} is an absolute path: {raw}"
    "{label} path could not be resolved: {raw}"
    "{label} path escapes repo root: {raw}"
    "{label} file missing: {raw}"
    "{label} is not a regular file: {raw}"
    "{label} file is empty: {raw}"
"""
import os
import pathlib


def validate_evidence_path(label, raw_path, root, failures):
    """Validate a relative evidence file path against repo root.

    Args:
        label: Prefix for error messages, e.g. "check 'lint' evidence" or
               "check 'unit-tests' red_evidence". Matches original inline format.
        raw_path: The raw path string from the contract.
        root: Repo root directory.
        failures: List to append failure strings to.

    Returns True if no failures were added, False otherwise.
    """
    initial_count = len(failures)

    if not raw_path:
        failures.append(f"{label} is missing or empty")
        return False

    path = str(raw_path).strip()

    # Reject absolute POSIX paths
    if path.startswith("/"):
        failures.append(f"{label} is an absolute path: {raw_path}")
        return False

    # Reject Windows drive paths (C:\...) and UNC (\\...)
    if (len(path) >= 2 and path[1] == ":") or path.startswith("\\\\"):
        failures.append(f"{label} is an absolute path: {raw_path}")
        return False

    # Resolve and check for traversal outside root
    abs_root = str(pathlib.Path(root).resolve())
    try:
        resolved = str(pathlib.Path(root).joinpath(path).resolve())
    except Exception:
        failures.append(f"{label} path could not be resolved: {raw_path}")
        return False

    if not resolved.startswith(abs_root + os.sep) and resolved != abs_root:
        failures.append(f"{label} path escapes repo root: {raw_path}")
        return False

    # Evidence must exist, be a regular file, and have size > 0
    if not os.path.exists(resolved):
        failures.append(f"{label} file missing: {raw_path}")
    elif not os.path.isfile(resolved):
        failures.append(f"{label} is not a regular file: {raw_path}")
    elif os.path.getsize(resolved) == 0:
        failures.append(f"{label} file is empty: {raw_path}")

    return len(failures) == initial_count
