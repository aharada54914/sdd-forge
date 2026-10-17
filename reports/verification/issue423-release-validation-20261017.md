# Issue 423 implementation and acceptance verification

This report records current development verification, not a recovered historical
SDD verdict. The user explicitly prioritized delivered fixes and validation over
procedural completion. Historical review records remain unchanged. Merge and
post-merge CI are still required before issue closure.

## Result and boundaries

The existing target-selection implementation preserves Registry ownership,
implementation-only results and fail-closed checks. Five target fixtures exercise
the shipped resolver and selected-plan evaluator. Legacy/hybrid fixtures retain
all seven documents; the task does not introduce a new default layout or a cloud
execution engine. Compatibility already worked, so T-004 required regression
coverage rather than an artificial production change just to manufacture RED.

The remaining UI boundary now uses `resolve-design-sync.py` through both full and
lite skill consumers. It separates applicability/provider availability from
upload consent, resolves current feature/session/destination records, preserves
pull's separate policy, and retains the existing pre-upload scanner. Off can be
revoked without an old off audit permanently overriding the new setting. Scope
prohibitions remain persistent. Standing audits are written once per
feature/destination. Local artifacts remain available without the provider.
The helper is registered in the protected workflow-script inventory.

The request/decision JSON is transient adapter data, versioned v1; it does not
create a new persisted policy source. Skills map existing Design-Source fields
and current settings into it and retain the existing audit format. The helper
has no provider or network APIs and cannot authorize cloud deployment.

## Acceptance evidence

| Acceptance | Executed evidence | Result |
|---|---|---|
| AC-001 inventory | T-001 consumer-inventory suite against current consuming files | 17 passed |
| AC-002/012 ownership and provider neutrality | T-002 contract-boundaries suite | 29 passed |
| AC-003/004/013 five targets, obligations, unavailable/unknown, stage boundaries | T-003 integration/evaluator suite, including real resolver CLI and standalone package tests | 29 passed |
| AC-005/006/007 absent/malformed/stale Context and hybrid retention | T-004 suite, including legacy byte comparison and seven structural mutation cases | 5 tests plus 5 stale-publication assertions passed |
| AC-008/009 UI applicability/consent/fallback | design-sync-policy suite; real helper subprocess, all regimes/scope changes and adapter spy | 12 passed |
| AC-008/009 existing scanner and contract continuity | design-sync-standing-consent, design-sync-scan, design-system-contract, bootstrap-interview-guidance | 55, 101, 121, 32 passed |
| AC-010 simulated/real and provider result boundary | T-003 implementation-only, nonimplementation-observation rejection and required execution-state tests; T-002 ownership checks | passed; only implementation-stage observations emitted, no deployment claim |
| AC-011 host semantics | guard-parity; guard-r10-port (Python/Node/PowerShell); cli-hook-enforcement (configured Claude/Codex/Copilot invocation forms) | 114, 60, 15 passed |
| AC-014 release bundle | this report, current consumer tests, branch diff and latest commit CI | local evidence complete; merge/post-merge evidence pending |

Additional integration checks: CI suite wiring (21 behavioral controls),
PowerShell aggregate Python runner (4 cases), generated guard invariants (42
checks), Python syntax, mirror freshness and `git diff --check` passed. The new
suite runs in both POSIX inventory and PowerShell aggregate. Existing pending
human-copy candidates are retained rather than replaced with current bytes.

## Regression and review

Before implementation, the new helper/consumer tests failed (8 test methods,
12 failures) because the helper and consumer references did not exist. After
implementation and independent review, all 12 methods pass. Independent review
found two concrete consent defects: old off records persisting across a setting
change, and missing audit output for scope egress prohibitions. Both were fixed
with regression cases; the reviewer reran the suite and reported no additional
findings. A further assertion verifies standing consent cannot override a
persisted scope prohibition. Pull remains independent of upload consent, but
an explicit egress prohibition also blocks provider reads.

## Limits

Host tests invoke shipped hook transports with synthetic payloads. They establish
adapter fixture conformance required by AC-011, not authenticated native-agent
sessions. Provider fixtures and the no-call spy are simulations, not remote
provider observations; no upload, real cloud test or deployment occurred. No
claim is made that an autonomous interview generated documents. The product's
skill consumers must still obtain honest runtime inputs and execute their
prescribed helper, scanner and audit steps.

The previous T-003 Done status had no canonical task contract/evidence files and
failed the task-state checker. It is corrected to Implementation Complete; no
missing formal evidence is fabricated. T-001 through T-006 have implementation
evidence; status changes record
Implementation Complete where appropriate, leaving historical formal gate
records untouched. Issue closure awaits latest-head CI, reviewed safe merge and
post-merge verification.
