# Windows CI lane-balance analysis (2026-09-22)

## Finding

The current Windows `version-gates` leg executes the Bash/PowerShell bump
checks and four independent version-gate lanes on one `windows-latest`
runner. The lanes are logically independent, but their child PowerShell
processes contend for the same CPU and filesystem. The latest main run
(`35671459622`) spent about 11m27s in the Windows `version-gates` leg.

The candidate keeps every existing test and release-loop check, but moves the
Windows-only work to two required jobs:

- `version-gates-windows-bump`: the existing Bash/PowerShell bump pair and
  `release-loop-gate.tests.sh`.
- `version-gates-windows-lanes`: a four-entry matrix, one lane per runner
  (`governance`, `capability`, `ownership`, `lite`).

The POSIX `version-gates` matrix remains unchanged except that its Windows
entry is removed. `required-checks` and its structural regression fixture now
require both replacement jobs, so a missing or failed lane cannot be silently
accepted.

The human-copy workflow snapshots for epic-190 and the existing epic-194
bundle are updated together. This keeps the repository's mirror freshness gate
green when the shared workflow changes; no unrelated pending bundles are
rewritten.

## Validation

- Candidate YAML parsed successfully with Ruby Psych.
- Candidate job set is a strict superset of the live job set (11 -> 13).
- Candidate `required-checks` fixture: 4 tests passed, 0 failed.
- Windows `lite` lane on PowerShell 7.6.2: 220 assertions passed, 0 failed
  (the lane's existing suites were not changed).
- Candidate workflow SHA-256:
  `4522750f3e8cad74e992b61c5baba6bf4bb4cbc4e15dd12389b0c1b2ab3adad4`.
- Human-copy mirror freshness: 6 passed, 0 failed (19 pending informational
  mirrors); manifest digests and applied mirrors match.
- Capability-registry parity: the candidate suite's only pre-commit failure is
  its intentional guard against an uncommitted live workflow; it is expected to
  pass after this branch is committed.

Full Windows timing and all-lane CI validation remain pending until the
resulting GitHub Actions run. No test was removed or weakened.
