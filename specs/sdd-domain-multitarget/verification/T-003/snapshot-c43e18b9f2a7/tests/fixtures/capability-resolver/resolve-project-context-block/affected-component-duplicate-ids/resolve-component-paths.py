#!/usr/bin/env python3
"""T-003 fixture stub (route-(a) cross-model panel round-4 closure):
returns an `affected_components` array carrying the SAME component id
twice (`["comp-a", "comp-a"]`) with an otherwise well-formed payload.
Epic A3's own contract guarantees unique affected-component ids, and
REQ-004 binds every `capability_evaluations[]` entry to carry EXACTLY
one `trigger_evaluations[]` element per affected component -- a
duplicate id in the dependency result is therefore malformed dependency
output, and step 4's own shape validation must Block
`dependency-output-malformed` up front (its existing canonical
sentence), never fan the duplicate out into two evaluations per
capability (the REQ-004 violation the openai round-4 panelist named,
which step 12's uniqueItems would then misattribute as
output-schema-validation-failed -- the round-3 misattribution class
again)."""
import hashlib
import sys

digest = hashlib.sha256(b"affected-component-duplicate-ids").hexdigest()
sys.stdout.write(
    '{"affected_components": ["comp-a", "comp-a"], '
    '"context_binding": {"ownership_digest": "sha256:' + digest + '"}}'
)
sys.exit(0)
