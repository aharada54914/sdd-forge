# T-004 bounded legacy manifest citation repair

User authority: explicit limited repair approval in this conversation, 2026-10-11.
Owner: shared-review-launch-integration/sdd-forge.
Owner HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807.
Existing dirty paths: 203; unrelated work preserved. Risk: high (evidence binding).

The frozen T-004 report uses `Manifest SHA-256:` rather than the current path-and-hash citation. Preserve its SHA-256 266f4c37db646ba7eee2e5719a68e9b26df89a4b6c108f3175ee8f87825f0e5c and existing identity/history. A version-2 supplemental declaration binds the missing manifest path; version 1 and modern citations retain their existing behavior.

This record was written after the focused implementation/tests, not represented as a pre-implementation checklist. No formal acceptance is inferred from it.

## Evidence consistency checks

| Field | Counterpart | Rejection regression |
| --- | --- | --- |
| declaration implementation_manifest path/hash | invocation implementation_manifest and pinned allowed input | different-path binding rejected |
| frozen report legacy digest | implementation manifest bytes/hash | wrong and duplicate legacy digest rejected |
| legacy citation mode | absence of modern Input manifest citation | conflicting modern citation rejected |
| declaration artifact paths | separately bound manifest path | manifest duplicated as artifact rejected |
| report run/session | implementation manifest identity | wrong report session rejected |
| declaration schema | legacy fallback requires v2 | v1 legacy fallback rejected |

Shared helper is called by Bash and PowerShell validators; the delivery preparation script emits v2. Contract text in quality-gate and review-context-boundary describes this narrow fallback. Regression driver exercises both validators, including reserve rejection, and checks ledger/report bytes remain unchanged.

## Executed evidence

- RED: legacy v2 positive case rejected by the previous helper (`invalid delivery declaration keys`); observed output, not a retrospectively saved original run.
- GREEN: `python3 -B tests/supplemental-delivery-declaration.tests.py`: 25 tests, zero failures, 34.666 seconds.
- Previous PR #558 CI success applies only to 228cc336a1b3f2f0f953eb46ff0f576d8b37cded, not this repair.

Independent diff review found zero Critical, Major or Minor findings and independently reran all 25 tests successfully (34.704 seconds). The generated delivery bundle passed the original evaluator-delivery preflight with 229 inputs; it was not reserved. These are not a formal quality-gate verdict.

T-004 is now Implementation Complete for evaluation, not Done. The frozen implementation report and manifest remain unchanged. The delivery addendum records exact-head public CI and disposable rollback evidence; the bounded repair has the focused regressions and independent diff review above. Formal evaluation, CI for the eventual final repair commit, merge and post-merge verification remain required. No approval, historical verdict or reservation is changed by this transition.
