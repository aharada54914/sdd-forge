# T-004 quality-gate preparation — 2026-10-04

This is preparation evidence, not an independent evaluator verdict or a Done decision. Task status and frozen implementation report were not edited. No evaluator identity was reserved and no primary evaluator was launched.

## Current checks

Commands use the repository's `plugins/sdd-quality-loop/scripts/` implementations. Saved stdout/stderr is alongside this note.

| Check | Command arguments | Result |
|---|---|---|
| Risk | `check-risk.sh specs/epic-196-a8-integration/tasks.md T-004` | exit 0, `risk.log` |
| Scoped placeholders | `check-placeholders.sh tests/cli-hook-enforcement.ps1` | exit 0, `placeholder.log` |
| Global workflow state | `check-workflow-state.sh` (no feature filter) | exit 0, `workflow-state.log`; existing amendment-growth warnings retained |
| Task state | `check-task-state.sh specs/epic-196-a8-integration/tasks.md reports/quality-gate reports/implementation .` | exit 0, 8 tasks; `task-state.log` |
| Component coverage | `check-component-coverage.sh --repo-root .` | exit 0, real disabled-legacy record; `component.log` |
| Task-local traceability | `check-traceability.sh specs/epic-196-a8-integration/verification/T-004/traceability.json . require-evidence` | exit 0, 1 REQ-003 link; `traceability.log` |
| Suite | `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/cli-hook-enforcement.ps1` | exit 0, 17 passed / 0 failed; `green.log` |
| Contract | `check-contract.sh specs/epic-196-a8-integration/verification/T-004.contract.json .` | exit 1: only `cross-model-verification` remains false; `contract-current.log` |

The initial Default-FAIL result is preserved in `contract.log`. The contract was then populated only from inspected saved results. `stack: shell` is the explicit toolchain-applicability mechanism defined by risk-gate-matrix.md; it permits compile-oriented waivers, not test waivers. The suite serves this single test-file task's unit, acceptance and regression roles. Historical RED contains all three deliberately permissive TEST-012 failures and is unchanged. Current 3-OS evidence is `../current-ci-20261004.md`; the local recheck is not a substitute for Windows/Linux.

The feature-root `traceability.json` does not exist. The existing, declared task-local traceability JSON is used without claiming that one-link evidence proves the rest of REQ-003 or other A8 tasks. Any demand for a feature-root artifact must be handled as a scoped schema/path decision, not by declaring unrelated native requirements green.

## Inputs and continuity

All five exact path/hash rows in the frozen implementation report's Outputs table were recomputed and match current bytes (source, RED, GREEN, task-local traceability JSON and its historical log). No T-004 implementation bytes changed during preparation.

`git show c886b790:tests/cli-hook-enforcement.ps1` contains 100 lines, not the task's historical 101-line claim. Every prior line was found in order in the current file. `git log -- tests/cli-hook-enforcement.ps1` attributes the synthetic addition to `ff73ebaa`, after `c886b790`. The existing implementation report already documents the discrepancy. Registration search finds this suite in `.github/workflows/test.yml:1366-1395`, not `tests/run-all.*`; adding registration would exceed T-004's explicit one-file scope.

## Panelist Minor findings: scope assessment

1. Synthetic config toggles do not drive native dispatch. Accepted limitation already required by design.md's Direct-Invocation De-Spoofing section and task Goal; no native substitution or code expansion is warranted.
2. The synthetic subagent indicator is not proof of actual subagent dispatch. Accepted limitation explicitly labeled in every new assertion. Native records remain separate work.
3. Historical baseline count/registration statements diverge from the tree. Accepted factual drift, verified above and recorded here without editing frozen artifacts. No missing existing assertion was detected.
4. The prior CI merge ref is not current-main integration proof. Accepted; no merge-readiness claim is made.

These are preparer's classifications, not a primary evaluator or cross-model consensus. Cross-model aggregation remains false until its required primary input exists and its own checker succeeds.

## Primary evaluator boundary

- Parent is repairing the source evaluator startup contract; that is not proof of installed-host activation. No old role is overridden by launch prose and no previous session handshake is reused.
- A read command containing `.codex/agents/sdd-evaluator.toml` was rejected by PreToolUse as a purported malformed-role write. No part of the command ran; role access was not retried through another mechanism. The parent received the refusal.
- The frozen implementation report has no `**Scratch Root**` entry. `validate-review-context-set.sh:598-600` requires scratch_root for a new evaluator reservation, and lines 638-645 require exactly one canonical implementation Scratch Root to check non-overlap. A new legitimate scratch root cannot establish the unknown historical implementation scratch root. Do not invent it or use the optional-field route to bypass the reservation rule.
- Exact implementation run ID `epic-196-a8-integration-t004-20260809-root` had no matching canonical ledger entry when checked. Historical Session ID/Agent Instance ID are both `root`; no provenance was fabricated or appended.
- New deterministic logs/current-CI evidence are not in the frozen report's Outputs table. Before admitting them to a primary evaluator, declare exact hashes through the sanctioned gate-report Post-Fix Artifacts channel and pin that declaration; do not widen allowed inputs with launch prose. No fake gate report/evaluator identity was created merely to satisfy this dependency.

## Safe integration boundary

Read-only GitHub checks observed PR #513 head `ac97422d6e347f4899a32d16fa9ceddc51b10416`, merge status BEHIND, all displayed checks successful. `git ls-remote origin refs/heads/main` returned `164767d998240b33f8622849729fb46f55e0a3d3`. Local HEAD is `495c88d67af44530687ecea3ce9fb0a90a336539` and differs 2 commits on each side from the PR head: local T-004 documentation/provenance commits versus PR main-merge commits. The T-004 PowerShell file has no diff against PR head.

Before integration: preserve current dirty provenance artifacts, select/reconcile the actual owner branch and remote PR head without discarding either side, carry the approved task and role-contract amendments by their sanctioned paths, rerun affected provenance gates on the final bytes, obtain primary/cross-model/evidence-bundle success, then require CI on the exact updated PR merge ref against current main and post-merge verification. No fetch/merge/push/status change was performed here.
