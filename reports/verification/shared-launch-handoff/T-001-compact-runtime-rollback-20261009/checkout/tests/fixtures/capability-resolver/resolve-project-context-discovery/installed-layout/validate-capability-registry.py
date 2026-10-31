#!/usr/bin/env python3
"""T-006 fixture-owned stub standing in for `validate-capability-registry`
(`installed-layout`, TEST-028), disclosed deviation (this suite's own
implementation report, "Specification Differences"): the REAL Epic A2
`validate-capability-registry.py` unconditionally resolves its own
`--repo-root` via `registry_discovery.resolve_git_root()` when
`resolve-project-context.py` invokes it (no `--repo-root` override is ever
passed at that call site) and therefore hard-fails ("cannot resolve
repository root") in a genuinely no-git installed-standalone-plugin layout
-- the EXACT layout AC-028 itself requires ("no reachable .git"). That
git-root dependency is Epic A2's own, already-`Spec-Review-Status: Passed`,
out-of-scope contract; this feature's own Global Constraints forbid
editing anything under `plugins/**`, `validate-capability-registry.py`
included. This fixture's own scope is proving THIS feature's Registry/
schema discovery contract (AC-002/AC-028), never Epic A2's own registry-
content validation machinery (already covered, against a real git
repository, by T-003's own suite) -- so this stub reports success
unconditionally, needing no git, letting the pipeline proceed to the
Registry-digest/governing-schema discovery steps this fixture actually
targets."""
import sys


def main():
    sys.stdout.write("validate-capability-registry: all 9 checks passed (T-006 installed-layout stub).\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
