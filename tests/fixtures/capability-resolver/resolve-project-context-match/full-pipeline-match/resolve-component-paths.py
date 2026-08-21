#!/usr/bin/env python3
"""T-005 fixture-owned capture-and-delegate stub for `resolve-component-
paths` (`full-pipeline-match`, TEST-004): records this invocation's own
argv verbatim to `rcp-argv-capture.json` (AC-004 -- confirms the Resolver
passes `--config`/`--source-rev`/`--target-rev`/`--include-untracked`
through byte-identical to its own received flags -- no rev resolution,
merge-base computation, or diff-basis logic performed by the Resolver
itself), then delegates unconditionally to the REAL `resolve-component-
paths` (installed alongside this stub as `resolve-component-paths-real.py`
by the test driver) so the rest of this invocation's own pipeline sees
genuine, correct output. This is the identical "capture, then delegate to
a `-real` sibling" technique T-002's own projection capture stub already
established (tests/fixtures/capability-resolver/
resolve-project-context-projection/canonicalize-sdd-yaml.py), reused here
for a different dependency rather than reinvented. Captures only the FIRST
call it sees (this invocation's own step 4) so step 13's own recheck call
never clobbers it -- it still delegates every call, including that later
one, to the real script either way."""
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REAL = HERE / "resolve-component-paths-real.py"
CAPTURE = HERE / "rcp-argv-capture.json"


def main():
    argv = sys.argv[1:]
    if not CAPTURE.exists():
        CAPTURE.write_text(json.dumps(argv), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(REAL), *argv],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    sys.stdout.buffer.write(result.stdout)
    sys.stdout.buffer.flush()
    sys.stderr.buffer.write(result.stderr)
    sys.stderr.buffer.flush()
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
