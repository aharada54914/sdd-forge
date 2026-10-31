#!/usr/bin/env python3
"""T-010 fixture stub (order-invariance, design.md Test Strategy item 9(b)):
the `-order-a` sibling's own docstring (this directory) explains this
pair's shared purpose in full -- this variant returns the identical set in
the REVERSE literal array order."""
import json
import sys

OWNERSHIP_DIGEST = "sha256:" + ("9" * 64)

sys.stdout.write(json.dumps({
    "affected_components": ["comp-b", "comp-a"],
    "context_binding": {"ownership_digest": OWNERSHIP_DIGEST},
}))
sys.exit(0)
