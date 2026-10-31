#!/usr/bin/env python3
"""Human-only, hash-pinned application of the Issue #290 A6/B wording candidate.

Default is a read-only dry run. An interactive human may pass --apply-human.
Do not run this through an agent after a protected-path gate refusal.
"""

import argparse
import difflib
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path("/Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge")
CANDIDATE = Path("reports/verification/issue290-a6-b-distinct-clarification-candidate-20261004.patch")
CANDIDATE_SHA256 = "ea9e8ea0f53897990b5471dbcef0320ee837e751a6fa0e3374aa8475dc03b0f7"

ROLE_ANCHOR = (
    "The orchestrator provides a fresh run ID, distinct nonblank host-session ID,\n"
    "and an allowed-input manifest, as well as feature slug, attempt number, round\n"
    "number, and the path to precheck-result.json. Reject any invocation with a\n"
    "wrong stage/role, a raw reviewer report in the manifest, or a path outside this\n"
    "allowlist. Read the following yourself:\n"
)
ROLE_INSERT = (
    "\n"
    "Here “distinct” means distinct from prior reservations and from the other\n"
    "reviewer's corresponding ID: A/B run IDs differ, and A/B host-session IDs\n"
    "differ. It does not require `run_id` and `host_session_id` to differ within\n"
    "one invocation when both identify the same host-issued root thread. Do not\n"
    "invent either ID or reuse a prior reservation.\n"
)
BOUNDARY_ANCHOR = (
    "**Authority.** `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`\n"
    "(and its `.ps1` twin) is the authority on manifest validity. This document\n"
    "describes that script; it does not add rules. Where the two disagree, the script\n"
    "wins and this document is the defect.\n"
)
BOUNDARY_INSERT = (
    "\n"
    "For A/B reviewers, “distinct” means each reviewer's run ID is unique against\n"
    "the other reviewer's and prior reservations, and likewise for host-session IDs.\n"
    "The validator does not require `run_id != host_session_id` within one record;\n"
    "a host-issued root thread ID may be used for both. This does not relax the\n"
    "cross-reviewer or ledger-wide uniqueness checks or authorize fabricated IDs.\n"
)

# Only these three existing paths can appear in the generated patch.
TARGETS = (
    ("plugins/sdd-review-loop/agents/task-reviewer-a.md",
     "e114b7a61b673e5230a691df3cc8f338df934b2ecf883fcd1b58206d14bae4a8",
     ROLE_ANCHOR, ROLE_INSERT),
    ("plugins/sdd-review-loop/agents/task-reviewer-b.md",
     "4f0add219de40b025d8bf0b73b5fe048e4d94728de2bd7616da728c930498ae9",
     ROLE_ANCHOR, ROLE_INSERT),
    ("plugins/sdd-review-loop/references/review-context-boundary.md",
     "003180de314177a2d5c6de0ee119e65dcebe4f4dd38178f72088160edc215057",
     BOUNDARY_ANCHOR, BOUNDARY_INSERT),
)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def regular_file(path):
    if path.is_symlink() or not path.is_file():
        raise RuntimeError(f"not a regular, non-symlink file: {path}")
    return path.read_bytes()


def run_git_apply(patch_path, check):
    argv = ["git", "-C", str(ROOT), "apply"]
    if check:
        argv.append("--check")
    argv.append(str(patch_path))
    subprocess.run(argv, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply-human", action="store_true",
                        help="interactive human-only write, after dry-run inspection")
    args = parser.parse_args()

    if not ROOT.is_dir() or ROOT.is_symlink():
        raise RuntimeError(f"unexpected checkout: {ROOT}")
    candidate_bytes = regular_file(ROOT / CANDIDATE)
    if sha256(candidate_bytes) != CANDIDATE_SHA256:
        raise RuntimeError("candidate SHA-256 mismatch; no application permitted")

    # The custom Begin Patch format is not passed to git apply. Pin its exact
    # contents and reproduce its three insertions as fixed, unique replacements.
    expected_sections = (
        b"*** Begin Patch\n",
        b"*** Update File: plugins/sdd-review-loop/agents/task-reviewer-a.md\n",
        b"*** Update File: plugins/sdd-review-loop/agents/task-reviewer-b.md\n",
        b"*** Update File: plugins/sdd-review-loop/references/review-context-boundary.md\n",
        b"*** End Patch\n",
    )
    if any(section not in candidate_bytes for section in expected_sections):
        raise RuntimeError("candidate structure mismatch")

    before = {}
    after = {}
    diff_chunks = []
    for rel, pinned_sha, anchor, insertion in TARGETS:
        path = ROOT / rel
        raw = regular_file(path)
        if sha256(raw) != pinned_sha:
            raise RuntimeError(f"original SHA-256 mismatch: {rel}")
        old = anchor.encode("utf-8")
        if raw.count(old) != 1:
            raise RuntimeError(f"expected unique anchor missing: {rel}")
        updated = raw.replace(old, old + insertion.encode("utf-8"), 1)
        before[rel] = raw
        after[rel] = updated
        diff_chunks.append(f"diff --git a/{rel} b/{rel}\n")
        diff_chunks.extend(difflib.unified_diff(
            raw.decode("utf-8").splitlines(keepends=True),
            updated.decode("utf-8").splitlines(keepends=True),
            fromfile=f"a/{rel}", tofile=f"b/{rel}",
        ))

    patch = "".join(diff_chunks).encode("utf-8")
    with tempfile.TemporaryDirectory(prefix="issue290-role-preflight-") as tmp:
        patch_path = Path(tmp) / "scoped.patch"
        patch_path.write_bytes(patch)
        run_git_apply(patch_path, check=True)
        print(f"candidate SHA-256: {CANDIDATE_SHA256}")
        for rel, pinned_sha, _, _ in TARGETS:
            print(f"{rel}: before={pinned_sha} after={sha256(after[rel])}")
        print(patch.decode("utf-8"), end="")

        if not args.apply_human:
            print("DRY RUN ONLY: no protected original was written")
            return
        if not sys.stdin.isatty():
            raise RuntimeError("--apply-human requires an interactive human terminal")
        if input("Type APPLY-ISSUE290 to apply these exact three paths: ") != "APPLY-ISSUE290":
            raise RuntimeError("human confirmation did not match")

        # A unique, retained external backup is made before any target write.
        backup_dir = Path(tempfile.mkdtemp(prefix="issue290-role-backup-"))
        print(f"backup directory: {backup_dir}")
        for rel, pinned_sha, _, _ in TARGETS:
            source = ROOT / rel
            if regular_file(source) != before[rel]:
                raise RuntimeError(f"source changed before backup: {rel}")
            backup = backup_dir / rel
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, backup)
            if sha256(regular_file(backup)) != pinned_sha:
                raise RuntimeError(f"backup hash mismatch: {rel}")
        for rel, _, _, _ in TARGETS:
            if regular_file(ROOT / rel) != before[rel]:
                raise RuntimeError(f"source changed after backup: {rel}")
        run_git_apply(patch_path, check=True)
        run_git_apply(patch_path, check=False)
        for rel, _, _, _ in TARGETS:
            if regular_file(ROOT / rel) != after[rel]:
                raise RuntimeError(f"after-readback mismatch: {rel}; backups retained at {backup_dir}")
        print(f"APPLIED AND READ BACK: three scoped files; backups retained at {backup_dir}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError, UnicodeError) as exc:
        print(f"STOP: {exc}", file=sys.stderr)
        sys.exit(1)
