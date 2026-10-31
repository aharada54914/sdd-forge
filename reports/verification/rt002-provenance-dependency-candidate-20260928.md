# RT002 formal-input preparation candidate — 2026-09-28

Observation addendum only. This file is not a canonical implementation report,
review receipt, evaluator manifest, quality verdict, or lifecycle transition.
No frozen feature artifact, ledger, task status, or historical report was edited.

## Identity-chain dependency

Read-only comparison of the source and integration canonical
`reports/review-context/identity-ledger.json` found 1001 and 1189 records,
respectively. All first 979 records are equal. Both sequence-980 records bind
previous hash `1a54a3c9d27a4cd6e4770e577f5a7629f42a9e79ae9ce9b46095830d4d82e325`,
but the source next record is RT002 implementation-policy reviewer A with hash
`e26bf8f5ebf2a706b2f277aebb5249c452e9e263502c75a6ab603f1ad97b7c60`, whereas
the integration next record is A8 specification reviewer A with hash
`5c0490e6526572ec1be99709eabea9dfed3c139d05a35ff411100dfb6114809c`.
Evidence: jq comparison of both `.records` arrays, first unequal index 979.

The source task-review invocation
`reports/review-context/epic-189-a1-rt002-repair-task-a1r2-a-invocation.json`
binds sequence 999 and ledger SHA256
`fe99547aa2a059b566c2696e9b5b07226c2c3b7e55559d864b5ba645c728bd24`.
It belongs to the source branch of this chain. Copying a source suffix,
renumbering records, or replacing the integration ledger cannot preserve both
historical receipts. No such reconciliation was performed or authorized by
this addendum. Minimum prerequisite: establish an explicit supported provenance
route that preserves both histories and allows the governing consumers to
verify the actual selected chain; otherwise retain the source evaluation
context rather than presenting selective copying as a valid gate migration.

## Authentic implementation continuation dependency

The real third task-input manifest identifies run
`rt002-t001-20260927-01a0e0bd`, attempt 1 in the legacy report, and SHA256
`28ec2c8bfdfbf3d4c74114477b92c0b7df2f0e6658c24e37ad2b7b0c8e95dff7`.
Its `allowed_outputs` names the legacy flat implementation report and feature
verification directory; it does not name the canonical
`reports/implementation/epic-189-a1-rt002-repair/T-001.md` path.
The current legacy report contains multiple run identities and no Outputs
table. The source ledger has no entry with the third implementation run ID
(jq filtering `.records[].run_id`), so the task-input manifest alone cannot
substitute for canonical ledger provenance.

Minimum prerequisite: a legitimate implementation continuation with authentic
host/run identity, explicit canonical-report output scope, governing task input
validation and declared output hashes. Preserve the legacy report and all old
manifest hashes; do not recast its historical entries as a newly executed run.
The new report can cite prior evidence by exact path/hash while clearly
separating new observations from prior session activation.

## Existing source evidence available for declared input preparation

These are source observations, not files integrated into this checkout and not
evaluator authorization. Raw SHA256 was measured with `shasum -a 256`.

| Feature verification file | SHA256 | Observed scope |
|---|---|---|
| third-baseline-bash-20260927.log | 51303df41675fe9987dd42f0463744c914a8983194653d9fdb9f58bbf2c494c4 | 199 PASS / 211 FAIL |
| third-baseline-pwsh-20260927.log | ba80f5ce1014922417c2e8d22a5a5d59a40d05133d67f938a5247752cafc9ba9 | 199 PASS / 211 FAIL |
| third-candidate-bash-20260927.log | abd21bd9ad742c07ce01e6d548ee592662fea32d7e6ec58bc15103a12765a9a7 | 410 PASS / 0 FAIL |
| third-candidate-pwsh-20260927.log | bebcfd9304511ac24ad023b20ba7811b7cf3eb01a840d8e726ece73abd73a2d0 | 410 PASS / 0 FAIL |
| child-host-activation-third-20260927-01a0e0bd.json | 5f20ec006e6bdc54ee6c10a89917e7f34ea9316c7aca433f04c221b9bf8f30e8 | prior real native-dispatch capture; fresh present-session activation is not claimed |

Evidence paths above are relative to
`specs/epic-189-a1-rt002-repair/verification/`; totals were read from log tails.
No suite, canary, coverage runner or refused operation was rerun.

The four logs establish the historical 410-assertion differential scope only.
Exact-head native Windows 423/0 evidence is separately recorded in
`reports/verification/rt002-native-windows-confirmed-20260928.md` for PR #528
head `a7cb83d3d3200ecb9a6f55cd2662fbce6bb7cae3`. Native Windows fixtures and
September 27 actual session activation are distinct evidence; neither proves
fresh evaluator activation.

## Remaining declared-input dependencies

1. Nine approved/frozen feature inputs, all bound review attempts, dependency
   graphs, invocation manifests and referenced calibration/ADR inputs, verified
   against the selected provenance chain. Retain the source frozen raw bytes;
   task approval/status normalization must use the actual validator.
2. One scoped canonical implementation report with authentic identity/attempt
   and exact lowercase path/SHA256 Outputs rows for current implementation,
   tests, prior captures, logs and all deterministic evidence it declares.
3. Repository-relative real current-head local/CI evidence and verification
   addenda, with public material excluding private host metadata and paths.
4. Component coverage through the permitted human route: the previous actual
   PreToolUse denial remains terminal for this agent operation. Preserve any
   genuine disabled-legacy/N/A result as N/A; do not synthesize PASS.
5. Legitimate contract/spec-revision/evidence-bundle generation and fresh
   independent evaluator activation/reservation only after its prerequisites.
   No contract, bundle, reservation, receipt, gate verdict or task status was
   manufactured during this preparation.

The installed quality-gate input boundary (SKILL.md step 8) requires a single
canonical implementation report with Outputs declarations and an intact
canonical identity chain. An observation addendum does not satisfy that
boundary or release the task from In Progress.
