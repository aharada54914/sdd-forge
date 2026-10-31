# Issue 290 current task-plan and provenance preparation (2026-10-04)

Status: deterministic preparation only. No attempt-7 reviewer identity was reserved, no reviewer turn was started, no prior reviewer output or ledger record was changed, and no task status or approval was changed.

## Current owner bytes

- Owner: `/Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge`.
- Current `specs/sdd-domain-concept-test/tasks.md` raw SHA-256: `8e8c8dafa256652f3ac9adb77b4adf1a54a00bbb59d549bef95970adf6470e02`.
- The current task plan already contains the ten changes described by `/tmp/sdd290-task-only-traceability-cycle-candidate-20261004.md`: T-001 validator-only evidence and shared bootstrap assertions pending; quality-gate after all approved tasks reach Implementation Complete; T-004 full feature-root traceability assembly and `T-006` dependency. The candidate's statement that it is unapplied is stale relative to these observed bytes. The actor and time of application are not inferred.
- T-001 remains `Approval: Approved`, `Status: In Progress`, and `Blockers: None`. The current plan's `Task-Review-Status: Passed` header is not a fresh binding of these amended bytes.

## Bounded checks on the current checkout

| Check | Observed result |
| --- | --- |
| `rtk proxy node --test reports/verification/issue290-guarded-task-review-launch.test.mjs` | exit 0; 11 pass, 0 fail |
| `rtk proxy bash tests/validate-approval-sidecar.tests.sh` | exit 0; 113 pass, 0 fail on macOS |
| `rtk proxy pwsh -NoLogo -NoProfile -File tests/validate-approval-sidecar.tests.ps1` | exit 0; 112 pass, 0 fail on macOS; not native Windows |
| `rtk proxy bash tests/review-context-boundary.tests.sh` | exit 0; 84 pass, 0 fail; disposable-fixture checks, not a real attempt-7 reservation |
| `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature sdd-domain-concept-test` | exit 1; `stage-provenance: task plan hash is stale` |
| `rtk proxy bash plugins/sdd-review-loop/scripts/task-review-precheck.sh sdd-domain-concept-test 7 1 --provenance-rereview` | exit 0; attempt-7/round-1 precheck written; expected stale workflow-state warning tolerated only for provenance re-review |
| Same precheck with `--verify-inputs` | exit 0; inputs verified, no reservation |
| `rtk proxy git diff --check` | exit 0 |

Attempt-7 precheck records normalized task SHA-256 `63e4db01e19c91a5aef323d32b9b56048226d517fb01e9a577ee2cd734bb233f`, `tasks_sha256_form: normalized`, `workflow_match_precheck: PASS`, and `blockers_format_valid: true`. This is input readiness, not task-review PASS.

## Formal launch boundary

Attempt-6 reviewer A's PASS and reviewer B's BLOCKED output remain historical. B's finding interpreted `distinct nonblank host-session ID` as requiring `run_id != host_session_id` inside one reservation. The canonical validator enforces ledger-wide uniqueness of each field and A/B separation, but does not require that within-record inequality (`validate-review-context-set.sh:480-485,582-590`). The current role text still says `fresh run ID, distinct nonblank host-session ID` (`task-reviewer-a.md:27`, `task-reviewer-b.md:28`); the clarifying protected-file candidate was refused by the normal hook and is not applied. The same actual host-issued root thread ID for both fields would likely reproduce B's interpretation, so no attempt-7 reservation or reviewer turn was started. Do not fabricate a second ID, reuse B6, change a role through another executor, or merge B6 into a PASS.

Next lawful step: admit the narrowly scoped role wording clarification through the repository's authorized protected-file process, then re-verify attempt-7 inputs immediately before a fresh independent A/B launch with distinct identities across reviewers and reservations. Recheck current task hashes and role bytes at launch. After both canonical reviews pass, persist integration and require `check-workflow-state` exit 0 before treating current task provenance as rebound. The task-plan-only lifecycle route avoids a shared quality-gate contract change, but T-001 Implementation Complete still requires truthful validator-side evidence and report readiness; quality-gate Done remains later and independent.

## Implementation report format recheck (2026-10-04)

After the latest T-001 report addendum, `rtk proxy bash plugins/sdd-implementation/scripts/validate-implementation-report.sh reports/implementation/sdd-domain-concept-test/T-001.md` exited 0 with `IMPLEMENTATION_REPORT_OK`. This verifies the current report's format only. It does not rebind the amended task plan, launch independent review, or complete the quality gate. No reviewer reservation, task status, approval, or Git state was changed.
