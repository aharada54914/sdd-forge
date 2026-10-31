# TEST-004(c) fixture design addendum — 2026-09-29

Issue #427: the user approved separating real-process normal completion from
deterministic deadline evidence checks, with approximately 2000ms slack and
five successful repetitions per runner. This records the approved fixture
strategy for Issue #427; it neither amends nor establishes satisfaction of the
frozen TEST-004(c) acceptance criterion or its task Done When. Those documents
and historical review/evidence records remain intact. The original natural
approximately 2-second completion condition is not proved by these fixtures.

- The normal-completion fixture labelled TEST-004(c) uses a 4-second budget,
  approximately 2000ms slack
  before output, and a deliberate 500ms output delay. Each of five repetitions
  per runner must exit 0 and preserve the complete expected verdict. PowerShell
  also checks the exact awaited process observation and absence of forced kill,
  nonmissing ordered wait/output receipts, and output no later than its deadline.
- PowerShell's unchanged Test-BoundaryTiming frozen inputs independently cover
  lower/deadline edges, early/late output, reversed phases and missing receipts.
  These are evidence-predicate checks, not proof of real near-deadline exit.
  Neither they nor the normal-completion fixture replace the frozen criterion.
- POSIX TEST-004(c2) retains its real polling deadline re-check coverage;
  TEST-004(a)/(b), TEST-005 and TEST-006 retain timeout/cleanup/fail-closed checks.
  The later PowerShell controlled real-process re-check regression and its
  production fix are recorded separately in `pr531-powershell-recheck.md`.

The injected 500ms output delay is the regression for the old 200ms slack:
normal completion must tolerate this delay, while deterministic late receipts
remain rejected and hung real processes still time out. At the initial fixture
change, no production timeout or runner behavior changed; the subsequent
PowerShell re-check correction is not covered by that historical statement.
Local suite results below describe the initial fixture revision only;
Windows CI execution remains necessary and is not replaced by this addendum.

Local validation on macOS, PowerShell 7.6.2: `bash tests/cross-model.tests.sh`
reported 70 passed / 0 failed (exit 0), and
`pwsh -NoProfile -File tests/cross-model.tests.ps1` reported 86 passed / 0 failed
(exit 0). The standalone empty-phase regression passed both cases (exit 0).
