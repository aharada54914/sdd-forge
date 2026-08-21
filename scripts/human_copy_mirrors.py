#!/usr/bin/env python3
"""Enumerate and classify human-copy mirrors of repository-shared files. WFI-039.

A repository-shared file can be snapshotted in several places at once: one copy
per ``specs/*/human-copy/`` bundle that ever needed a human to apply it, plus any
``specs/*/drafts/human-copy-candidate/`` set. Each existing suite enforces its own
bundle and is blind to the others, so editing a shared file surfaces the mirrors
one CI round at a time.

This module is the single enumeration all of that should go through. The shell
and PowerShell suites and the sync tool call it rather than reimplementing the
walk, so they cannot disagree about what a mirror is or how it is classified.

Classification
--------------

``fresh``
    staged bytes equal live bytes. Nothing to do.

``stale``
    staged differs from live, and staged equals ``origin/main``'s live bytes. The
    bundle was already applied and the working tree moved the live file without
    syncing. This is the failure case, and the only one the sync tool touches.

``pending``
    staged differs from live *and* from ``origin/main``'s live bytes. The bundle
    is a reviewed change still waiting for a human to apply it.

The pending/stale split is the safety property. ``specs/epic-159-pillar-c/
human-copy/`` stages role definitions at bytes differing from main's live files;
treating "staged differs from live" as stale would overwrite reviewed human work,
and CI would go green because no suite enforces byte-identity for that bundle.
``staged == main`` is what separates the two, and it is not guessable from the
file alone.

CLI: ``human_copy_mirrors.py <repo-root>`` prints one TSV row per mirror,
``<STATE>\\t<bundle>\\t<repo-relative path>\\t<rule>``.
"""
import glob
import hashlib
import os
import subprocess
import sys

CANDIDATE_SUFFIX = ".candidate"
CANDIDATE_MARKER = os.path.join("drafts", "human-copy-candidate") + os.sep


def _sha_file(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


class _MainDigests:
    """origin/main digests, resolved lazily and cached per path."""

    def __init__(self, root):
        self.root = root
        self._cache = {}

    def available(self):
        return subprocess.run(
            ["git", "-C", self.root, "rev-parse", "--verify", "--quiet", "origin/main"],
            capture_output=True,
        ).returncode == 0

    def get(self, rel):
        if rel not in self._cache:
            result = subprocess.run(
                ["git", "-C", self.root, "show", f"origin/main:{rel}"],
                capture_output=True,
            )
            self._cache[rel] = (hashlib.sha256(result.stdout).hexdigest()
                                if result.returncode == 0 else None)
        return self._cache[rel]


def enumerate_mirrors(root):
    """Yield (bundle, repo_relative_path, staged_path, rule) for every mirror."""
    for manifest in sorted(glob.glob(
            os.path.join(root, "specs", "*", "human-copy", "MANIFEST.sha256"))):
        bundle_dir = os.path.dirname(manifest)
        bundle = os.path.relpath(bundle_dir, root)
        with open(manifest, encoding="utf-8") as handle:
            for line in handle:
                if not line.strip():
                    continue
                _, _, rel = line.partition("  ")
                rel = rel.strip()
                if not rel:
                    continue
                staged = os.path.join(bundle_dir, rel)
                # A manifest may register a directory-shaped path; only regular
                # files are mirrors that can be compared byte for byte.
                if os.path.isfile(staged):
                    yield bundle, rel, staged, "manifest"

    for candidate in sorted(glob.glob(
            os.path.join(root, "specs", "*", "drafts", "human-copy-candidate",
                         "**", "*" + CANDIDATE_SUFFIX),
            recursive=True)):
        base = candidate[: -len(CANDIDATE_SUFFIX)]
        index = base.find(CANDIDATE_MARKER)
        if index < 0:
            continue
        rel = base[index + len(CANDIDATE_MARKER):]
        # The candidate set carries its own manifest, which mirrors nothing in
        # the live tree; it is self-consistency data, not a snapshot.
        if os.path.basename(rel) == "MANIFEST.sha256":
            continue
        bundle = os.path.relpath(base[:index + len(CANDIDATE_MARKER)].rstrip(os.sep), root)
        yield bundle, rel, candidate, "candidate"


def manifest_digest_mismatches(root):
    """Yield (bundle, rel, recorded, actual) where a manifest digest is stale.

    Separate from classify() on purpose. classify() compares staged bytes to
    live bytes; this compares the manifest's recorded digest to the staged bytes
    it describes. Those are different failures and one does not imply the other:
    a change that rewrites live and staged identically leaves them agreeing
    while the manifest silently goes stale. That is not hypothetical -- a
    branch-wide rename did exactly this and only `phase2-guard-invariants`
    caught it, one CI round later.
    """
    for manifest in sorted(glob.glob(
            os.path.join(root, "specs", "*", "human-copy", "MANIFEST.sha256"))):
        bundle_dir = os.path.dirname(manifest)
        bundle = os.path.relpath(bundle_dir, root)
        with open(manifest, encoding="utf-8") as handle:
            for line in handle:
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    continue
                recorded, _, rel = line.partition("  ")
                rel = rel.strip()
                staged = os.path.join(bundle_dir, rel)
                if not (rel and os.path.isfile(staged)):
                    continue
                actual = _sha_file(staged)
                if actual != recorded.strip():
                    yield bundle, rel, recorded.strip(), actual


def classify(root, main_digests=None):
    """Yield (state, bundle, rel, staged_path, rule) for every mirror."""
    main_digests = main_digests or _MainDigests(root)
    for bundle, rel, staged, rule in enumerate_mirrors(root):
        live = os.path.join(root, rel)
        if not os.path.isfile(live):
            yield "MISSING", bundle, rel, staged, rule
            continue
        staged_digest, live_digest = _sha_file(staged), _sha_file(live)
        if staged_digest == live_digest:
            yield "FRESH", bundle, rel, staged, rule
        elif staged_digest == main_digests.get(rel):
            yield "STALE", bundle, rel, staged, rule
        else:
            yield "PENDING", bundle, rel, staged, rule


def main(argv):
    if len(argv) != 2:
        print("usage: human_copy_mirrors.py <repo-root>", file=sys.stderr)
        return 2
    root = os.path.abspath(argv[1])
    digests = _MainDigests(root)
    if not digests.available():
        print("origin/main is not available", file=sys.stderr)
        return 3
    for state, bundle, rel, _staged, rule in classify(root, digests):
        print(f"{state}\t{bundle}\t{rel}\t{rule}")
    for bundle, rel, _recorded, _actual in manifest_digest_mismatches(root):
        print(f"MANIFEST-STALE\t{bundle}\t{rel}\tmanifest")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
