#!/usr/bin/env python3
"""Projection-pass capture stub for T-002's step 3 assertions.

The resolver's step 2 must behave exactly as in production, so every
YAML-mode invocation is delegated verbatim to the real canonicalizer, which
the driver copies beside this stub as `canonicalize-sdd-yaml-real.py`.

The step 3 (JSON-mode) invocation is the one under observation. Its input
file is the resolver's own in-memory Context Projection, serialized to a
temporary path -- the only point at which that structure is observable from
outside the process, since T-002 stages it and never writes a live artifact
(design.md step 3, B1/B4). The stub copies those bytes byte-for-byte to
`<fixture-repo>/projection-capture.json` before doing anything else, then
behaves per SDD_T002_PROJECTION_MODE:

  passthrough   delegate to the real canonicalizer (success path)
  json-fail     exit non-zero  -> canonicalizer-invocation-failed
  json-garbage  exit 0, unparseable stdout -> dependency-output-malformed

The two failure modes emit an `UPSTREAM_SECRET` marker so the caller can
assert M8 (upstream stderr is never copied into the Resolver's own
diagnostic). There is no default mode: an unset variable fails closed.

T-003 note: once the resolver's own step 6 (`registry_digest`) lands, a
SECOND, later JSON-mode canonicalizer invocation reaches this same stub (via
`generate-registry-digest --whole`'s own identical canonicalizer call) after
step 3's own capture has already happened. This stub captures only the
FIRST JSON-mode call it sees per process tree, so step 3's own capture is
never clobbered by that later, unrelated call -- it still delegates every
JSON-mode call (including that later one) to the real canonicalizer either
way.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REAL = HERE / "canonicalize-sdd-yaml-real.py"
# HERE is <fixture-repo>/plugins/sdd-quality-loop/scripts.
CAPTURE = HERE.parents[2] / "projection-capture.json"


def delegate(argv):
    result = subprocess.run(
        [sys.executable, str(REAL), *argv],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    sys.stdout.buffer.write(result.stdout)
    sys.stdout.buffer.flush()
    sys.stderr.buffer.write(result.stderr)
    sys.stderr.buffer.flush()
    return result.returncode


def main():
    argv = sys.argv[1:]
    json_mode = (
        "--input-format" in argv
        and argv.index("--input-format") + 1 < len(argv)
        and argv[argv.index("--input-format") + 1] == "json"
    )
    if not json_mode:
        return delegate(argv)

    if not CAPTURE.exists():
        shutil.copyfile(argv[0], str(CAPTURE))
    mode = os.environ.get("SDD_T002_PROJECTION_MODE", "")
    if mode == "passthrough":
        return delegate(argv)
    if mode == "json-fail":
        sys.stderr.write("UPSTREAM_SECRET: platform-specific canonicalizer failure\n")
        return 27
    if mode == "json-garbage":
        sys.stdout.write("UPSTREAM_SECRET:not-json")
        return 0
    sys.stderr.write("stub: SDD_T002_PROJECTION_MODE unset or unknown\n")
    return 90


if __name__ == "__main__":
    sys.exit(main())
