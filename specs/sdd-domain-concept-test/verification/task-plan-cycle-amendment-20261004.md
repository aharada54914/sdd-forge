# Task-plan lifecycle amendment evidence — 2026-10-04

Status: applied to the owner task plan; **new task-stage review required**. This record is not a review verdict, quality-gate result, or Done decision.

- Human-authorized scope: clarify validator-side T-001 Implementation Complete evidence; keep TEST-022 and TEST-051–078 bootstrap/zero-call assertions pending for T-003; make T-004 the last dependent task and full feature-root traceability assembler. No shared quality-gate or checker contract changed.
- Pre-apply `specs/sdd-domain-concept-test/tasks.md` SHA-256: `fe1899d1a9f5ded503278ca4ae9e0f456798d1f7cda6a1d3147e675ba75d100a`.
- Source candidate `/tmp/sdd290-task-only-traceability-cycle-candidate-20261004.md` SHA-256: `82717e43efc13deb7b8d0e7de774869e4499666f41fe76262e24ff67253ba881`. All ten candidate hunks were applied with the normal `apply_patch` tool; no protection refusal was observed.
- Post-apply `specs/sdd-domain-concept-test/tasks.md` SHA-256: `8e8c8dafa256652f3ac9adb77b4adf1a54a00bbb59d549bef95970adf6470e02`.
- All six Approval and Status values, plus `Task-Review-Status: Passed`, were preserved. The existing attempt-4/round-1 PASS is historical; its binding does not cover the amended bytes.

## Local checks

| Check | Result |
|---|---|
| Candidate patch applicability before editing | `patch --dry-run --verbose -p1`: ten of ten hunks matched, exit 0. |
| Task state | `check-task-state.sh specs/sdd-domain-concept-test/tasks.md`: six tasks passed, exit 0. |
| Project structure | `check-sdd-structure.sh . sdd-domain-concept-test`: OK, exit 0; `CLAUDE.md` advisory only. |
| Whitespace | `git diff --check -- specs/sdd-domain-concept-test/tasks.md`: exit 0 (this task plan is untracked in the owner checkout, so this does not compare its body with the old review). |
| Current provenance | `check-workflow-state.sh --feature sdd-domain-concept-test`: exit 1, `stage-provenance: task plan hash is stale`. This is the expected block until a fresh review re-binds the amended plan. |

## Remaining boundary

Do not use the old PASS to start a gated implementation or quality-gate launch. The next task-review attempt is attempt 5, round 1, with complete reviewer inputs and fresh per-role reservations under the normal launch contract. The amendment does not assert that any bootstrap assertion, feature-root traceability row, independent quality gate, or downstream task is complete. The new review may reject the amendment; no PASS is presumed.

### Formal precheck, attempt 5 round 1

`task-review-precheck.sh sdd-domain-concept-test 5 1 --provenance-rereview` exited 0 and wrote `reports/task-review/sdd-domain-concept-test/attempt-5/round-1/precheck-result.json` and `dependency-graph.json`. The script first observed the expected stale-plan `check-workflow-state` failure and explicitly proceeded only under the re-review mode. A subsequent `--verify-inputs` exited 0. No reviewer identity has been reserved and neither reviewer has been launched.

The precheck binds the normalized task-plan SHA-256 `63e4db01e19c91a5aef323d32b9b56048226d517fb01e9a577ee2cd734bb233f`, distinct from its raw byte SHA-256 above. Its input SHA-256 is `734e6b5ca96d7591919acb16cd7890d913df46c1a278644f0480a1a57fa69276`. It records `workflow_match_precheck: PASS`, `blockers_format_valid: true`, and an empty `frozen_artifact_done_when` list. The dependency graph now includes T-004 → T-006 and has six task nodes. The complete reviewer manifest must copy this normalized task hash, not recompute the raw hash; the other inputs must match their recorded raw hashes.
