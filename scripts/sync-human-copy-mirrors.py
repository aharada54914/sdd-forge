#!/usr/bin/env python3
"""Sync stale human-copy mirrors to the live tree. WFI-039.

Run this after editing a repository-shared file and before pushing:

    python3 scripts/sync-human-copy-mirrors.py --check    # report only
    python3 scripts/sync-human-copy-mirrors.py            # write

It copies live bytes over every mirror classified STALE by
``scripts/human_copy_mirrors.py`` and rewrites the affected ``MANIFEST.sha256``
lines in place, preserving order and every untouched entry.

What it will not do
-------------------

It never touches a PENDING mirror. A bundle whose staged bytes differ from
``origin/main``'s live bytes is a reviewed change waiting for a human to apply
it; overwriting it would discard that work silently, and CI would go green
because no suite enforces byte-identity for every bundle. The classification
lives in the shared enumerator so this tool and the freshness suite cannot
disagree about which is which.

It also does not create manifest entries. If a mirror's path is not already
registered in its bundle's manifest the digest cannot be rewritten, and the tool
says so rather than inventing a line -- deciding that a bundle should start
snapshotting a new file is a review decision, not a sync.
"""
import hashlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from human_copy_mirrors import _MainDigests, classify  # noqa: E402


def _sha_bytes(payload):
    return hashlib.sha256(payload).hexdigest()


def main(argv):
    check_only = "--check" in argv
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

    digests = _MainDigests(root)
    if not digests.available():
        print("origin/main is not available; cannot tell a stale mirror from a "
              "pending one. Fetch it and retry.", file=sys.stderr)
        return 3

    stale, pending = [], []
    for state, bundle, rel, staged, rule in classify(root, digests):
        if state == "STALE":
            stale.append((bundle, rel, staged, rule))
        elif state == "PENDING":
            pending.append((bundle, rel))

    for bundle, rel in pending:
        print(f"pending (left alone): {bundle} <- {rel}")

    if not stale:
        print("no stale mirrors; nothing to sync")
        return 0

    for bundle, rel, _staged, rule in stale:
        print(f"{'would sync' if check_only else 'sync'}: {bundle} <- {rel} ({rule})")
    if check_only:
        print(f"\n{len(stale)} mirror(s) would be synced")
        return 1

    by_manifest = {}
    for bundle, rel, staged, rule in stale:
        payload = open(os.path.join(root, rel), "rb").read()
        with open(staged, "wb") as handle:
            handle.write(payload)
        if rule != "manifest":
            continue
        manifest = os.path.join(root, bundle, "MANIFEST.sha256")
        by_manifest.setdefault(manifest, {})[rel] = _sha_bytes(payload)

    unregistered = []
    for manifest, fresh in by_manifest.items():
        lines = open(manifest, encoding="utf-8").read().splitlines()
        out, rewritten, seen = [], 0, set()
        for line in lines:
            if not line.strip():
                out.append(line)
                continue
            _, _, path = line.partition("  ")
            path = path.strip()
            if path in fresh:
                out.append(f"{fresh[path]}  {path}")
                seen.add(path)
                rewritten += 1
            else:
                out.append(line)
        open(manifest, "w", encoding="utf-8").write("\n".join(out) + "\n")
        print(f"{os.path.relpath(manifest, root)}: {rewritten} line(s) rewritten")
        unregistered.extend(
            (os.path.relpath(manifest, root), p) for p in fresh if p not in seen)

    if unregistered:
        print("\nnot registered in their manifest (left for review, not invented):",
              file=sys.stderr)
        for manifest, path in unregistered:
            print(f"  {manifest} <- {path}", file=sys.stderr)
        return 1

    print(f"\n{len(stale)} mirror(s) synced")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
