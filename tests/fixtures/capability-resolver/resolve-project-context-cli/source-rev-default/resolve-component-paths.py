#!/usr/bin/env python3
"""T-006 fixture-owned stub standing in for `resolve-component-paths`
(`source-rev-default`, TEST-001/AC-001): captures this invocation's own
argv to `rcp-argv-capture.json` -- confirming `--source-rev`'s own CLI
default `HEAD` reaches this dependency verbatim, never a caller-resolved
git sha (design.md API/Contract Plan step 4: `[--source-rev <rev>] #
default: HEAD`) -- and returns a fixed, valid `{affected_components,
context_binding}` response. This fixture only needs step 4 (this
dependency's own invocation) to succeed so step 5's own deliberately-
absent-Registry Block becomes reachable and observable; it never needs a
real git repository, since this suite's own scope is the CLI usage-error/
default-passthrough surface (AC-001), not affected-component resolution
itself (Epic A3's own, out-of-scope concern already covered by T-003's
own suite via a real subprocess)."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ARGV_CAPTURE = HERE / "rcp-argv-capture.json"


def main():
    ARGV_CAPTURE.write_text(json.dumps(sys.argv[1:]), encoding="utf-8")
    sys.stdout.write(json.dumps({
        "affected_components": ["comp-a"],
        "context_binding": {"ownership_digest": "sha256:" + "9" * 64},
    }) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
