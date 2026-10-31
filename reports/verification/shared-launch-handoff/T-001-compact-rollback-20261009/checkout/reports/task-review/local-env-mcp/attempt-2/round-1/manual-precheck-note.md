# Manual Precheck Note — task-review attempt 2 / round 1 (local-env-mcp)

Date: 2026-07-06
Recorded by: orchestrating agent (session 6503d1ba), under explicit human direction.

## Why the automated precheck could not run

`plugins/sdd-review-loop/scripts/task-review-precheck.sh local-env-mcp 2 1`
fails at its embedded canonical workflow-state validation
(`check-workflow-state.sh`) **in every reachable tasks.md state** during a
post-implementation provenance re-review (AGENTS.md "Post-implementation
provenance re-review", WFI-004):

- `Task-Review-Status: Pending` → `task-lifecycle: pending task review
  permits only Draft approvals` (live tasks legitimately carry
  approved-with-sudo-audit-mark approvals and `Status: Implementation
  Complete`).
- `Task-Review-Status: Passed` → the validator selects the latest evidence
  (attempt-1/round-2) and fails with `task reviewer manifests omit layer
  inputs` — the exact defect this attempt-2 re-review exists to remedy
  (RT-20260705-001 items 4–5).

The precheck script therefore shares the pre-implementation initial-state
assumption that WFI-004 identified in the reviewer role files. This is part
of the plugin-maintainer follow-up tracked at
https://github.com/aharada54914/sdd-forge/issues/86.

Note: the AGENTS.md issue-#61 manual-precheck fallback (WFI-002) is **not**
invoked here — issue #61 is closed. This deviation stands on:

1. WFI-004 (docs/workflow-improvements/WFI-004.md), whose approval value was
   set by the human on 2026-07-06, defining the post-implementation
   provenance re-review protocol this attempt executes.
2. The human's explicit directive of 2026-07-06 in the orchestrating
   session: 「AGENTS.md への2規則適用 → tasks.md T-005/T-010 の Done When
   文言修正…→ task-review attempt 2(完全 manifest + 正準スキーマ)→
   check-workflow-state exit 0 確認(= WFI Verified)→ quality-gate
   T-001〜T-010 再開せよ」.

## Manually executed precheck steps and results

Every step of task-review-precheck.sh other than the unsatisfiable
workflow-state call was executed verbatim on 2026-07-06:

| Step | Command / logic | Result |
|---|---|---|
| Input files exist (STEP 1) | tasks/requirements/acceptance-tests/design + 4 layer specs + traceability, regular files, no symlinks | PASS |
| Stage statuses | `Spec-Review-Status: Passed`, `Impl-Review-Status: Passed` | PASS |
| Risk check (STEP 2) | `plugins/sdd-quality-loop/scripts/check-risk.sh specs/local-env-mcp/tasks.md` | PASS ("Risk check passed for 10 task(s)."), `workflow_match_precheck: PASS` |
| Blockers parse + graph (STEP 3) | Same parser semantics (## T-NNN headers, `### Blockers` value lines); 10 nodes, 18 edges; no range notation, no prose, no unknown targets, no cycle | PASS (`blockers_format_valid: true`) |
| Input hashes (STEP 4) | sha256 of all inputs; see precheck-result.json | recorded |
| Layer traceability | `validate-layer-traceability.py traceability.md requirements.md` | PASS |
| Round>1 tasks-changed check (STEP 5) | N/A — this is round 1 of attempt 2 | skipped by design |
| Portable contract (STEP 6) | `review-contract-validate.sh --feature local-env-mcp --attempt 2 --round 1 --stage task …` | PASS (`review-contract-validation/v1`, verdict PASS) |
| Outputs (STEP 7) | `precheck-result.json` + `dependency-graph.json` written to this round directory with the same field set the script emits | done |

Frozen-artifact integrity at precheck time: design.md raw sha256
`0f02d668…b458af6b` (impl-reviewed bytes) and traceability.md raw sha256
`15921dfb…70cace47` (task-reviewed bytes) — both unchanged, satisfying the
AGENTS.md "Post-review artifact freeze" rule. tasks.md raw sha256
`13ab5116…32bd9206` reflects the human-authorized Done When wording
amendment of T-005/T-010 (commit history: "docs(tasks): amend T-005/T-010
Done When …"); its status-normalized hash is `720afc5a…f5709664`.

## Identity reservation

Reviewer identities are reserved in the canonical identity ledger exactly as
the automated path would: one `review-context-invocation/v2` manifest per
reviewer, validated and appended via
`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh <manifest>
<repo-root> --reserve` (REVIEW_CONTEXT_OK required before launch), sequences
42 (task-reviewer-a) and 43 (task-reviewer-b).

## Reviewer invocation reframing (disclosed)

Per WFI-004's audited Rollback-Plan disclosure, the reviewers' static role
files still carry the pre-implementation initial-state text; the invocation
is therefore operationally reframed at runtime: both reviewers run in fresh
read-only contexts with the complete input set (including all four layer
specification files), perform the full check catalogues (reviewer A: 14
checks incl. INITIAL-STATE; reviewer B: 9 checks), emit the persisted-state
validator's canonical task output schema, and evaluate INITIAL-STATE by
lifecycle validity (AGENTS.md "Post-implementation provenance re-review").
