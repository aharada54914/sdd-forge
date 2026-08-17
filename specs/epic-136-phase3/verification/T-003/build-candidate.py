#!/usr/bin/env python3
"""Validate the retired epic-136 workflow fixture without modifying it.

The historical transformer was disabled after the live workflow advanced past
its source snapshot. Current workflow changes must use a base-bound patch under
``docs/ci-staging``. This command is intentionally read-only and accepts no
source or destination arguments.
"""

from pathlib import Path
import sys


HERE = Path(__file__).resolve().parent
FIXTURE = HERE / "staged-workflow-candidate.draft.yml"
BANNER = "# SUPERSEDED TEST FIXTURE — DO NOT APPLY TO .github/workflows/test.yml."
REQUIRED_SUITES = (
    "tests/guard-dispatch-fallback.tests.sh",
    "tests/guard-negative-corpus.tests.sh",
    "tests/deterministic-lane-selfcheck.tests.sh",
    "tests/workflow-scenarios/workflow-scenarios.tests.sh",
)


def main() -> int:
    if len(sys.argv) != 1:
        print("error: retired validator accepts no source or destination", file=sys.stderr)
        return 2

    text = FIXTURE.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0] != BANNER:
        print("error: historical fixture lacks the DO NOT APPLY banner", file=sys.stderr)
        return 1

    missing = [suite for suite in REQUIRED_SUITES if suite not in text]
    if missing:
        print("error: historical fixture is missing: " + ", ".join(missing), file=sys.stderr)
        return 1

    print(f"validated retired historical fixture (read-only): {FIXTURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
