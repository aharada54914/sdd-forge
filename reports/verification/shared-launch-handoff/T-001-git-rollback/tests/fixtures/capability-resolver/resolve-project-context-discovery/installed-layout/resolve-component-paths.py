#!/usr/bin/env python3
"""T-006 fixture-owned stub standing in for `resolve-component-paths`
(`installed-layout`, TEST-028): AC-028's own installed-standalone-plugin
layout is deliberately outside ANY git working tree (no reachable `.git`
at all, matching Epic A2's own three-fixture discovery pattern this AC
cites) -- the REAL `resolve-component-paths` (Epic A3) cannot function at
all in that layout, and this suite's own scope is this feature's
Registry/schema DISCOVERY contract, not affected-component resolution
(already covered, via a real subprocess against a real git repository, by
T-003's own suite). This stub returns a fixed, valid response
unconditionally, needing no git."""
import json
import sys


def main():
    sys.stdout.write(json.dumps({
        "affected_components": ["comp-a"],
        "context_binding": {"ownership_digest": "sha256:" + "7" * 64},
    }) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
