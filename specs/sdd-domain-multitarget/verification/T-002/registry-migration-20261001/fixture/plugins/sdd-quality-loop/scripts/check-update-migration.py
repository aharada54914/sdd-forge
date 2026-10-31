#!/usr/bin/env python3
"""Illustrative fixture only (RT-20260930-001 / issue423 registry migration).

This file exists solely so that `capability-registry.fixture.json`'s
`durable-workflow` example resolves an `implementation_ref` to a real path
when validated in isolation. It is not a production migration checker, is
never referenced by the canonical or vendored Registry, and is never
invoked by the real POSIX/PowerShell dispatchers. It intentionally always
fails with an explicit, honest diagnostic rather than fabricating a pass,
so nothing that imports this fixture by mistake could read it as a working
migration gate.
"""
import sys


def main() -> int:
    sys.stderr.write(
        "check-update-migration: fixture-only placeholder (RT-20260930-001); "
        "no production migration-check algorithm exists or is implied here.\n"
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
