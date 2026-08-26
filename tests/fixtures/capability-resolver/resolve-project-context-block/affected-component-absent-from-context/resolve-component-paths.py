#!/usr/bin/env python3
"""T-003 fixture stub (ruling C(2), human-approved 2026-08-26): returns an
`affected_components` entry (`comp-ghost`) that the fixture's own Project
Context does NOT define. Under REQ-002's amended
`dependency-output-malformed` row, steps 7-8 must Block BEFORE any
predicate evaluation of that entry -- never silently evaluate it against a
defaulted-empty properties document, which is exactly the fail-open both
the quality gate (cycle 1) and the openai cross-model panelist flagged.
`comp-a` is present and valid, proving the Block is attributable to the
ghost entry alone, not to the shape of the stub's output."""
import hashlib
import sys

digest = hashlib.sha256(b"affected-component-absent-from-context").hexdigest()
sys.stdout.write(
    '{"affected_components": ["comp-a", "comp-ghost"], '
    '"context_binding": {"ownership_digest": "sha256:' + digest + '"}}'
)
sys.exit(0)
