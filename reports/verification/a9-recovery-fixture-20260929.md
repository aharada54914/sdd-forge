# A9 recovery fixture preparation — 2026-09-29

Scope: synthetic fixture preparation only. No product implementation, source/ledger mutation, reservation, approval/status change, Git operation, formal review or semantic admission PASS. Read tester SKILL.md, checkout AGENTS.md and the entire recovery data contract.

## Required inputs and existing helpers

The record's feature is `epic-197-a9-dogfood`, not the implementation feature. Source is `{attempt:3,round:3}`; target is `{attempt:4,round:1}`. Construct a disposable repository with these canonical relative paths:

- Live pins: `specs/epic-197-a9-dogfood/{requirements.md,acceptance-tests.md,investigation.md}` and `plugins/sdd-review-loop/references/spec-review-calibration.md`.
- Previous complete round: `reports/spec-review/epic-197-a9-dogfood/attempt-3/round-2/{precheck-result.json,reviewer-a.json,reviewer-b.json,integrated-summary.json,integrated-verdict.json,spec-review-contract.json}`. These six are consumed by `validate_contract` (`plugins/sdd-review-loop/scripts/spec-review-precheck.sh:227-364`); verdict alone is insufficient.
- Interrupted local inventory: `reports/spec-review/epic-197-a9-dogfood/attempt-3/round-3/{precheck-result.json,reviewer-a.json,reviewer-a-reservation.txt,reviewer-a-host-receipt.json,spec-review-report.md}`. Exactly these five entries, no subdirectories.
- External A invocation: `reports/review-context/epic-197-a9-dogfood-spec-a3r3-a-invocation.json`.
- Synthetic-only identity chain: `reports/review-context/identity-ledger.json`. Use new `fixture-*` identities, never copy real session UUIDs.
- Fixture authorization: `reports/verification/a9-fixture-authorization.md`.
- Fixture record: `reports/verification/a9-fixture-recovery.json`.
- Target `reports/spec-review/epic-197-a9-dogfood/attempt-4/round-1` must be absent, including a dangling symlink.

Reusable helpers:

1. `tests/spec-review-loop.tests.sh:41-113`, `write_contract DIRECTORY NEEDS_WORK Major`: constructs coherent previous precheck/reviewers/summary/verdict/contract bindings. Extract only the function; do not source or execute the suite, whose top-level body changes the workflow registry (`:10-14`, `:115-118`). Set ROOT/FEATURE/SPEC_DIR to the disposable repository and provide its previous-round precheck first.
2. `tests/review-context-boundary.tests.sh:254-262`, hash helpers; `:281-314`, `rcb_new_fixture`; `:319-330`, `rcb_append_record`: reuse the existing two-record chain pattern, with canonical feature/path names and five allowed inputs. Existing `rcb_append_record` writes legacy identity hashes; A's fixture record must additionally bind `allowed_inputs_sha256` with the current `allowed-inputs-v1` suffix (`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:491-510`, `:529-540`, `:1118-1119`). Do not invoke `--reserve`, even on the fixture.
3. Real validators to load/call read-only: `validate_contract` above, and `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh INVOCATION DISPOSABLE_ROOT` without `--reserve`. The latter's matching persisted branch verifies the whole chain and tolerates a historical ledger-tip hash (`:518-576`). No existing closed-recovery-record fixture helper was found in the scoped existing drivers.

## Closed record sample and construction order

This is a construction sample; `REF(path)` means the exact `{path,sha256:SHA256(raw file bytes)}` object. It is intentionally not an admission-ready JSON artifact.

```text
{
  schema: "spec-review-interrupted-recovery/v1",
  feature: "epic-197-a9-dogfood",
  source: {attempt: 3, round: 3},
  target: {attempt: 4, round: 1},
  authorization: REF("reports/verification/a9-fixture-authorization.md"),
  previous_contract: REF("reports/spec-review/epic-197-a9-dogfood/attempt-3/round-2/spec-review-contract.json"),
  interrupted_precheck: REF("reports/spec-review/epic-197-a9-dogfood/attempt-3/round-3/precheck-result.json"),
  pinned_inputs: SORT_BY_PATH([REF(each of the four live pins)]),
  interrupted_artifacts: SORT_BY_PATH([REF(each of the five local inventory files), REF(external A invocation)]),
  reviewer_a: {
    invocation: REF(external A invocation), sequence: 2,
    stage: "spec", role: "spec-reviewer-a",
    run_id: "fixture-a9-source-a", host_session_id: "fixture-a9-source-session-a",
    record_sha256: SHA256(A historical synthetic identity record)
  }
}
```

The sample has exactly ten root members; source/target have exactly two, references exactly two, reviewer_a exactly seven. Use canonical role paths, four/six sorted unique arrays and an identical repeated invocation ref.

Minimal build order:

1. Add simple Pending requirements, acceptance/investigation and calibration bytes to the disposable repository. Hash these four; composite precheck `input_sha256` hashes `requirements_sha256:acceptance_sha256:investigation_sha256` without newline. Construct round-2 precheck and reuse `write_contract ... NEEDS_WORK Major`.
2. Construct round-3 Pending precheck, with current four pins and composite hash. Sort the five invocation inputs (four pins plus raw precheck ref) by path. Hash `path<TAB>sha256` entries joined by newline, no final newline, to obtain A's `allowed_inputs_sha256`.
3. Construct a sequence-1 genesis synthetic record. Its hash is SHA256(`1|spec|spec-reviewer-a|fixture-a9-genesis|fixture-a9-genesis-session|`). Before appending A, hash the genesis ledger bytes into invocation `identity_ledger_sha256`. A sequence-2 record hash is SHA256(`2|spec|spec-reviewer-a|fixture-a9-source-a|fixture-a9-source-session-a|GENESIS_HASH|allowed-inputs-v1|INPUT_BINDING_HASH`). Add its `allowed_inputs_sha256`; preserve the historical tip hash in the invocation. Keep just genesis and A, and no B manifests/records attributable to source.
4. Create the external v2 invocation with the five exact inputs, sequence 2 and genesis previous hash. Create A raw with the same identities/manifest, BLOCKED unreadable-input diagnostics, host receipt `review_execution_started:false` and matching allocation session, and a diagnostic report explicitly saying launch failure/B not launched/no integrated result. Create reservation text `REVIEW_CONTEXT_OK A_RECORD_HASH sequence=2 previous_record_sha256=GENESIS_HASH pre_append_tip_sequence=1 identity_unique=yes`. These are synthetic data, not human/host evidence.
5. Build record except authorization. Compute binding using Python stdlib `json.dumps(record_without_authorization,sort_keys=True,separators=(",",":"),ensure_ascii=True).encode("utf-8")`, with no trailing newline. Create exactly one of each of the eight bare authorization lines below, then set authorization ref to its raw SHA256. Finally serialize the complete JSON record and retain its raw SHA256 independently.

```text
Feature: epic-197-a9-dogfood
Source Attempt: 3
Source Round: 3
Target Attempt: 4
Target Round: 1
Maximum Rounds: 3
Decision: Authorize interrupted A-before-B recovery
Recovery Binding SHA256: COMPUTED_BINDING_HASH
```

An added prose line must identify this as synthetic test input. It cannot substitute for AUTH-001 human-origin launch evidence.

## Source observations and remaining conditions

- Real source round 3 contains exactly the five prescribed local files. A raw is BLOCKED and describes denial before manifest verification; host says execution not started; diagnostic report records B not launched/no integrated contract (`round-3/spec-review-report.md:5-11`). No raw session identifier is copied here.
- The four current live SHA256 values match source precheck and external A invocation pins. Source round-2 contract is `spec-review-contract/v1`, attempt 3/round 2, NEEDS_WORK, with both reviewer roles. Its full own-stage validator has not been run in this limited preparation.
- Real reservation has the expected REVIEW_CONTEXT_OK fields, and the live ledger has the canonical schema and historical records. Full real chain validation and all orphan-launch attribution checks have not been run; no source admission conclusion follows.
- Fixture construction is now complete; the execution below supersedes the earlier preparation-only statement. The WFI-001 matrix and recovery-admission implementation remain incomplete.

## Executed RED checkpoint

`rtk proxy python3 -B tests/a9-interrupted-recovery.tests.py` exited 1. The disposable prior round passed the original `validate_contract` (exit 0), and its persisted identity passed the original validator without `--reserve` (exit 0). The Bash and PowerShell recovery-admission entrypoints were absent, so both probes exited 1. This proves the missing implementation, not semantic admission or negative-case coverage.

- Fixture SHA256: `37954f60f0fd71843b03c5fd383fa36e0b3bea7a9d8cb876659dabc433a355b9`.
- Fixed test SHA256: `bdf05e0143b35c22cc99ead7b0bd4bcf27cf5c5aef63f9bfaab96d8ab6fd93aa`.
- Actual output SHA256: `03e0eba6cee4fa2c09bc7da73eb654c74a5549b02447e9716f869b0a27c4d0db` (retained locally, not published).
- Independent ordinary review found 0 findings. No formal verdict, task status, real ledger, reservation or production file changed. The test's no-bytecode guarantee relies on the recorded `-B` invocation. This checkpoint is not native activation, full parity, CI, quality-gate or delivery proof.

## Fixed mutation checkpoint

The two existing test helpers now materialize named mutations without treating a missing admission API as a successful rejection. The historical RED output remains unchanged: the 653-case catalog and corrected 168-case reference subset reached the real prior-contract and persisted-identity controls, but neither recovery API exists; semantic negative execution and PASS are both zero.

The additional 39-case catalog contains one ledger-extension positive and 38 negatives. Fixture-only corrections used their three-attempt budget. The final continuation validated the completed-source NEEDS_WORK control and isolated the incorrect composite hash while coherently rebinding its invocation, ledger, raw output and receipt. These sibling controls do not prove recovery admission. Partial catalog runs are not presented as one aggregate execution, and already checked unchanged cases were not rerun.

- Fixed fixture SHA256: `43429b945f3fd0195bd9cee2811c4635a794274894ebb3977e690a0c462784f4`.
- Fixed runner SHA256: `3f390e9ab64b0ad27abe7f24600ef6b55b6996b3cbd5be70d9d94ec16bf7d180`.
- No production, approval/status, frozen input, live identity ledger or reservation changed.

The private implementation preflight maps current admission fields to concrete mismatch inputs. It also records downstream evidence limits rather than claiming absent report/revision/count/traceability reconciliation tests exist. Production must not start until the governing task's preflight requirement is satisfied. Actual admission, full twin regressions, independent quality verification, CI and delivery remain pending.
