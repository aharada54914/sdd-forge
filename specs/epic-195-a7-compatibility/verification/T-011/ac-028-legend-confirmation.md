# AC-028 disposition-legend confirmation

Result: PASS against the assembled T-002 through T-010 and T-013 suite set.
T-011 added no assertion; this is a cross-check of the shipped cases and their
persisted passing evidence.

## ASSERT cells

- F1/F2 byte identity and all six Context-absent CLI-submatrix cells are
  exercised by `compatibility-byte-identical.tests.sh` and `.ps1`. T-003's
  persisted GREEN records 25 passed, 0 failed in each runtime; its output names
  all six `none`/`--full`/`--lite` x marker-present/marker-absent cells.
- F1/F2 structural identity is exercised by
  `structural-compatibility.tests.sh` and `.ps1`. T-004's persisted GREEN
  records exit 0 in each runtime, and `depth1-proof.log` records 40 passed,
  0 failed for both runtimes.
- F1/F2 orchestration cells are exercised across `loop-inventory`,
  `loop-consistency`, and `loop-escalation`. Persisted GREEN evidence includes
  T-006 loop-consistency (31/0 Bash, 35/0 PowerShell) and T-008
  loop-escalation (32/0 Bash, 31/0 PowerShell).

## SKIP-with-activation cells

The shipped T-010 manifest contains the five fixed activation entries
`AC-004`, `AC-007`, `AC-021`, `AC-042`, and `AC-043`, covering the A5, A4,
A1+A5, A1, and A1+A6 dependency shapes used by the matrix's gated cells.
`skip-allowlist-manifest.tests.sh` and `.ps1` validate the exact entries,
activation expressions and source wiring; T-010's persisted GREEN records
12 passed, 0 failed in each runtime. The source-wiring audit finds the fixed
SKIP renderers in `loop-escalation.tests.sh` (`AC-004`/`AC-021`) and
`structural-compatibility.tests.sh` (`AC-007`/`AC-042`/`AC-043`) calling
`skip_allowlist_line` rather than embedding local allowlist values.

## N/A cells

- Byte identity remains Context-absent-only: no F3-F8 byte case is assigned.
- The shipped structural corpus contains only `f1-full.json`, `f2-lite.json`,
  `f3-advisory.json`, and `f4-required.json`; no F7/F8 case exists.
- A source sweep found no `build_fixture`/case registration for F7 or F8 and
  no `facet-hybrid` or `facet-native` builder call in any `.tests.sh`/`.tests.ps1`
  suite. This matches their matrix disposition of N/A, not SKIP.

## T-012 exclusion

`structural-compatibility-live-refresh.tests.sh` and `.ps1` occur in none of
`tests/run-all.sh`, `tests/run-all.ps1`, or the staged gating workflow. The
AC-031 refresh therefore remains omitted from the gating set as permitted.
