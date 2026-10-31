# Loop-driver conditional fixture repair (2026-10-07)

- Scope: approved fixture-only repair for omitted spec/impl conditional inputs; owner `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`, HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`.
- Owned implementation files: `tests/lib/loop-driver.sh` and `.ps1` only. Each already has a 3-line dirty diff; preserve it and all unrelated dirty work.
- Risk: routine test-fixture correction to match the approved resolver, not a change to authorization, input contracts, runtime enforcement, formal evidence or task state.
- Reproduction: parent observed loop-consistency 24 pass / 10 fail, including `omits selected conditional review dependencies`. Fixture domain files exist even while Pending; the resolver admits those files before its Approved check.
- Plan: reuse `review-conditional-inputs.py` for spec/impl reservation manifests, reviewer output manifests, contracts and the Bash capability probe. Do not broaden task/domain inputs or weaken negative cases.
- Validation: normal and missing-input checks, Bash/PowerShell loop-driver, loop-consistency and loop-escalation suites. Only disposable fixture ledgers may be exercised by existing suites; no production reservation, native model launch, Git mutation or formal verdict.
- Independent review: parent will arrange separately. CI and formal completion are not claimed.

## Initial repair validation

Follow-up approval extends ownership to the independent normal-manifest fixture in `tests/loop-driver.tests.sh` and permits adding the real `review-hash-normalization.ps1` dependency to the PowerShell driver fixture. No negative fixture, validator or escalation implementation may change.

- Bash syntax: exit 0. Existing terminal-event changes in both drivers preserved.
- Both runtime non-reserving checks: a fixture spec manifest including the resolver's two existing domain files was accepted; the original base manifest omitting those files was rejected with the selected-conditional-dependencies error. Fixture ledger SHA-256 remained unchanged. Both checks exited 0.
- `bash tests/loop-consistency.tests.sh`: 34 passed, 0 failed, exit 0 (48 seconds). Existing task fixture warns that `check-risk.sh` is unavailable; this is not newly introduced or counted as a risk-check execution.
- `pwsh -NoProfile -File tests/loop-driver.tests.ps1`: 23 passed, 0 failed, exit 0 (14 seconds).
- `bash tests/loop-driver.tests.sh`: 25 passed, 1 failed, exit 1. The independent allocation regression at line 173 constructs an old two-input manifest outside the owned driver; spec rounds and the rest pass. Reported to parent; do not mask this by auto-completing manifests in the generic reservation helper.
- `pwsh -NoProfile -File tests/loop-consistency.tests.ps1`: spec rounds passed, then exit 1 because the fixture lacks `review-hash-normalization.ps1`, newly called by its real impl precheck. Reported to parent for scope decision.
- Escalation: Bash 36 passed / 1 failed (7 seconds); PowerShell 35 passed / 1 failed (22 seconds), both exit 1. Both failures are TEST-019.10b: the active merged resolver requires an actual interviewer invocation which this fixture does not drive. Existing named SKIPs remain visible. No escalation implementation changed in this repair.

## Approved follow-up results

- `tests/loop-driver.tests.sh`: its independent positive allocation fixture now uses the same conditional-input resolver helper. Generic admission and all negative fixtures remain unchanged.
- `tests/lib/loop-driver.ps1`: fixture script dependencies now include the existing `review-hash-normalization.ps1`, required by the real impl precheck. No substitute normalization or validator bypass was introduced.
- `bash tests/loop-driver.tests.sh`: 26 passed, 0 failed, exit 0 (5 seconds).
- `pwsh -NoProfile -File tests/loop-consistency.tests.ps1`: 38 passed, 0 failed, exit 0 (72 seconds), including spec/impl/task/domain rounds, brownfield, unauthorized-input negative, and event trace.
- Escalation was investigated read-only, not rerun or repaired. `tests/fixtures/skip-allowlist-manifest.json:5,18` activates AC-004 on merged(A5) and AC-021 on merged(A1) AND merged(A5). `tests/loop-escalation.tests.sh:870-875` only constructs F1/F3-invalid/F4-invalid fixtures under a PATH spy; it does not drive the interviewer. Once activation is true, lines 890-891 intentionally fail closed instead of treating zero resolver invocations as proof. PowerShell has the same boundary at `tests/loop-escalation.tests.ps1:764-765`. The missing evidence is an actual interviewer/caller execution for those negative contexts, not missing spec/impl conditional manifests; weakening activation or restoring a SKIP is outside this repair.
- Independent review, exact-final-head CI, ordinary native-host proof and formal gate verdict remain separate and unclaimed.
