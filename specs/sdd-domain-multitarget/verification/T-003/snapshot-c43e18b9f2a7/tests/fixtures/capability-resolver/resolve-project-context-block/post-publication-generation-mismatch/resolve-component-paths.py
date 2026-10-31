#!/usr/bin/env python3
"""T-007 fixture stub (AC-049/TEST-049): a `resolve-component-paths`
stand-in that agrees with itself across this invocation's own step-4
snapshot AND its step-13 pre-publication recheck, then reports a DIFFERENT
`affected_components` set on its THIRD call -- the post-publication
verification the transactional bundle contract runs after every rename in
step 14's own commit sub-step has already succeeded (design.md "Resolver
publication transactional bundle contract", Post-publication verification).

This is the "post-recheck race" (adversarial review B8) reproduced
deterministically: the pre-publication recheck genuinely PASSES (calls 1
and 2 are byte-identical, so `snapshot-generation-mismatch` cannot fire),
every rename genuinely commits, and only then does the source turn out to
have moved on. The call-counting marker-file technique is the identical one
`recheck-dependency-failed`'s own stub already established for the SAME
recheck window, extended by one call.

THIRD-CALL LIVE-STATE CAPTURE (AC-049(a), "fires only after every rename
has already, briefly, succeeded"). That claim is otherwise unobservable
from outside the resolver process -- by the time the invocation exits, the
journal-based rollback has already put every target back at PRE. This stub
runs INSIDE the post-publication verification window, i.e. after the last
rename and before the rollback, so it is the one vantage point from which
the briefly-live state can be recorded. On its third call it writes the
sha256 (or the literal "ABSENT") of every live publication target to
`post-publication-live-capture.json` in its own script directory, which
the driver then compares against those targets' own PRE-transaction
sentinel bytes.
"""
import hashlib
import json
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
MARKER = SCRIPT_DIR / ".t007-post-publication-call-count"
CAPTURE = SCRIPT_DIR / "post-publication-live-capture.json"

OWNERSHIP_DIGEST = "sha256:" + ("0" * 64)
SNAPSHOT_AFFECTED_COMPONENTS = ["comp-a"]
# The post-publication re-derivation: a genuine set difference, with the
# ownership_digest left byte-identical (B8's own "ownership_digest parity
# is not sufficient by itself" point, reused at the post-publication site).
POST_PUBLICATION_AFFECTED_COMPONENTS = ["comp-a", "comp-b"]

# Repo-relative live publication targets, resolved against this stub's own
# cwd (the resolver always invokes its dependencies with the fixture repo
# as cwd).
LIVE_TARGETS = (
    "specs/example-feature/facet-manifest.yaml",
    "plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json",
    "specs/example-feature/resolver-evidence.yaml",
)


def _call_number():
    try:
        previous = int(MARKER.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        previous = 0
    current = previous + 1
    MARKER.write_text(f"{current}\n", encoding="utf-8")
    return current


def _capture_live_state():
    observed = {}
    for relative_path in LIVE_TARGETS:
        path = Path(os.getcwd()) / relative_path
        try:
            observed[relative_path] = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError:
            observed[relative_path] = "ABSENT"
    CAPTURE.write_text(json.dumps(observed, sort_keys=True), encoding="utf-8")


def main():
    call_number = _call_number()
    if call_number >= 3:
        _capture_live_state()
        affected_components = POST_PUBLICATION_AFFECTED_COMPONENTS
    else:
        affected_components = SNAPSHOT_AFFECTED_COMPONENTS
    sys.stdout.write(json.dumps({
        "affected_components": affected_components,
        "context_binding": {"ownership_digest": OWNERSHIP_DIGEST},
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
