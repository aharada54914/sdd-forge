# RT004 applied contract documents: regression verification

Date: 2026-09-15
Branch: codex/t002-failure-diagnostics
Base HEAD: 8b84f28e0818d6c8ecd251b7f670f73df3d2f861
Status: local regression complete; formal review, CI and integration pending.

The human applied the five contract documents. All five initial hashes matched
the supplied application output. Existing unrelated changes were preserved.

## Executed checks

- `rtk proxy bash tests/impl-review-adr-inputs.tests.sh`: exit 0, admission/history
  448 passed, precheck 10 passed, generation 30 passed, downstream 32 passed;
  520 total, zero failures, downstream inconclusive=0. Tool session 88301.
- `rtk proxy bash tests/impl-review-round2-contract.tests.sh`: exit 0, four checks
  passed. Tool session 89758.
- `rtk proxy bash tests/review-context-boundary.tests.sh`: initially exit 1 due
  to outdated source-line citations. The previous-summary check moved from
  common-library line 274 to 490, and mode admission from precheck line 69 to
  187. Only these two citations and matching test anchors were updated.
  The final execution passed all 32 citation anchors and TEST-RCB-001..010
  plus 005b on Bash and PowerShell (22 runtime checks), exit 0, session 14440.
- `rtk proxy git diff --check`: exit 0 after the two citation corrections.

Output evidence is the tool transcript for these sessions, not a separately
saved full-output log. No test, predicate, required input or review criterion
was removed or weakened. The citation fixture supplied the observed red/green
regression for the two-line reference drift.

## Genuine review resumption

A fresh A1 attempt 6 round 1 provenance precheck completed with exit 0. It
binds seven ADRs and all four layer documents; the old attempt 5 remains intact.
Its precheck hash is
`bcbdec1c5d48a613f365f6389e865019050d031eb7b9b76f97722ed2fb5ac5cf`.
Reviewer A input re-verification and identity reservation succeeded at sequence
980, then a fresh independent reviewer was launched. No reviewer verdict is
claimed by this report. Fixture success does not establish live host activation.

## Scoped publication audit

The complete six-file diff was reviewed after the citation corrections. It adds
the ADR input contract and matching reviewer/launcher guidance; no executable
validator predicate, dependency, required test or CI condition was removed.
The contract template parses as JSON and its new empty ADR array was checked
with jq (exit 0). Whitespace validation remains successful. The identity-ledger
diff contains only the genuine reviewer A reservation at sequence 980.

A read-only Node command intended to scan added diff lines for credential
patterns was rejected by the actual PreToolUse SDD hook before execution.
The automated scan therefore has no result and was not retried through a
different path. Manual diff inspection found no credentials in the six-file
change. This is a scoped review, not a repository-wide security certification.

GitHub PR #400 still targets head
`8b84f28e0818d6c8ecd251b7f670f73df3d2f861`. Its returned check list currently
contains CodeRabbit SUCCESS only, not evidence that required CI ran on the
uncommitted changes. No merge readiness is claimed.
