# Parallel PR and pushed-only reconciliation

Status: in progress; no new integration or closure asserted.

## Scope and dispatch

The user explicitly requested parallel sub-agent work on other PRs and un-PR'd branches. Four existing lightweight agents were reused for separate read-only investigations: auto/improve branches and Issues 295/380; PRs 371/381; PR245/A5; and PR391's interrupted package test. The primary retains final review and integration decisions. The approved dependency-only workflow exception remains limited to dependencies; other work retains the repository's task and quality gates.

## Primary-verified findings

- Fetched `main` and `feature/issue-137-sdd-context` without pruning. Main is `e5ff39d95adadb7c0628132313392ec03c7f21c4`.
- At that exact main, Python guard lines 543–548 still use `APPROVAL_RE.search(cmd)` for shell approval classification. The investigator's claim that main already uses `count(cmd) > 0` was rejected by directly inspecting `git show origin/main:plugins/sdd-quality-loop/scripts/sdd-hook-guard.py`. Neither non-ancestry nor the presence of a count helper establishes whether a call site was fixed.
- Existing `docs/ci-staging/hook-branch-reconciliation.md` records both auto-improve candidates and regression weaknesses. It also records that `second-approval-mask` explicitly excludes hook-guard changes; its historical Done task is not approval for this correction. Both branches and aggregate issues remain preserved.
- Issue288 claims commit `18a588101c64e746c0a7592b7c30f5761fcc94ee` moves existing-investigation completeness to reservation. Its original patch adds paired shell/PowerShell predicates. A comparison with the issue137 branch also reveals many older implementations that would revert later main improvements if copied wholesale. Selective reconciliation is required; no wholesale branch overwrite or cherry-pick was executed.
- Main's `docs/workflow-improvements/WFI-027.md` describes a different, Draft cross-epic activation proposal. Issue288's WFI identifier therefore collides with main's document; historical names alone cannot authorize replacing it.
- PR391 remains incomplete: local tests were interrupted, and current CI is still queued/running. Fresh Windows/Ubuntu MCP checks are successful, but that is not all-checks success. See its dedicated preflight report.

## Review control

Agent answers that read the root checkout instead of the requested PR tree, substitute check names for failure causes, or infer implementation from commit ancestry were returned for correction. No such claims are accepted as closure evidence. Further A5 task-state and PR391 test diagnosis results remain pending. No protected file was edited or denial rerouted in this dispatch.

## Next actions

1. Complete exact-tree A5 task/evidence inspection and interrupted PR391 test diagnosis.
2. Preserve and independently evaluate branch-specific changes before selecting governed repair units; do not reuse unrelated task approval.
3. Integrate only exact reviewed heads with every mandatory check successful and strict base requirements satisfied. Keep all unresolved issues open.
