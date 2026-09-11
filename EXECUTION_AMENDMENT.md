# Execution amendment — 2026-09-05

Status: proposed for independent GPT-6 Astra re-review.

## Precedence and scope

This dated amendment supersedes **scheduling only** in `SAFE_CONSOLIDATION_PLAN.md`, `task_plan.md`, and historical findings/progress. Production Symphony engineering is deferred from the repository execution critical path; it is not completed, waived, or declared safe. All ownership, SDD human approval, frozen-artifact, quality-gate, and remote-action boundaries remain mandatory.

`SYMPHONY_HARDENING_PLAN.md` is preserved byte-for-byte at SHA-256 `657ce9e12aed195d3d5193bd1d1c676323ef064c5a705d55e009a6cba47c4093`. Its H-003C PLANNING header is historical: progress records the later round-21 contract PASS and completed codec/C1a slices. Neither result authorizes production use. The remainder (H-003C1b and later transitions, H-004/H-005) is deferred without further implementation or added permissions.

## Independent review disposition

GPT-6 Astra returned NEEDS_WORK on the program plan, with three Major findings:

1. Distributed fencing and privileged services displaced the user's Issue/PR outcomes; the original local ledger scope expanded materially (hardening plan lines 55, 514, 1844).
2. Provider Git/tag writes conflict with the original read-only metadata/issues credential boundary (consolidation plan line 171). No extra credentials or provider service have been authorized.
3. Making optional production tooling a prerequisite unnecessarily blocks direct governed Codex verification and specification work.

All three findings are accepted. Completed local patches remain intact; no rollback, deletion, new ledger schema, or privilege changes are needed for this amendment.

## Executable critical path

1. Refresh all remote heads, PRs, Issues and known owner-worktree signals; preserve occupied or uncertain work. Export an exact-SHA inventory and verify a local remote-ref bundle. This is evidence, not an ownership release or permission to delete.
2. Revalidate PR #386's exact head against `PR386_VERIFICATION.md`. Reuse unchanged-head test evidence with its explicit baseline parity exception. Record outstanding ownership handoff, SDD coverage and merge authorization separately.
3. Produce read-only overlap and failure dossiers for #371/#381/#382 and #389; do not reconstruct their occupied work. Investigate a concrete unclaimed issue and determine its actual approval requirements before any coding.
4. Execute one matching human-Approved task only when both ownership clearance and applicable review gates are evidenced; otherwise prepare the exact decision packet for the missing human transition. No Draft implementation or invented approval marks.
5. After an approved task is implemented, use independent review and repository quality-gate. Only quality-gate may set Done. Commit/push/PR/merge/cleanup remains separately and explicitly authorized.

## Symphony use and limits

The pinned installation and existing credential-free memory/fake-worker scratch tests remain available and are the only permitted Symphony execution mode for this program. This is synthetic validation, not a production pilot or actual Issue implementation. No real tracker polling, real-repository agent launch, credentials, remote reservation refs, or privileged helper service will be configured.

The candidate's `elixir/lib/symphony_elixir/claim_store.ex:461-475` accepts only empty v2 claims; `elixir/lib/symphony_elixir/orchestrator.ex:836-841` and `:972-1009` still use in-memory dispatch ownership. A locked owner plus concurrency one does not prove restart-safe durable claims. Failed cleanup hooks preserve workspaces, but successful/no-op hooks may still delete them (hardening plan line 23). These limits are not hidden by passing synthetic tests.

## Completion and next human boundary

This phase completes with current ownership/overlap/CI dossiers, safe branch classifications, a verified backup, and an exact next-task decision. It does not claim the user's overall objective complete until approved changes are actually integrated and verified. Any required owner handoff must identify issue/PR, branch and expected SHA; any new task approval must name its reviewed specification and task ID. Unknown work on other machines remains unobservable.
