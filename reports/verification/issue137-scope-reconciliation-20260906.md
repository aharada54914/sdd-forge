# Issue 137 — current issue versus existing branch

Status: incomplete; no implementation, task approval, merge, or closure.

## Authoritative observations

- [Issue 137](https://github.com/aharada54914/sdd-forge/issues/137) reports updatedAt `2026-08-29T13:42:24Z`. Its revision history and final decision explicitly retire the PreCompact-only HANDOFF-centered proposal in favor of an append-only Conversation WAL. Required outcomes include unmaterialized user decisions, evidence-bound decision indexing, transcript-tail reconciliation, stale/wrong-repository/corrupt-tail defenses, runtime-specific adapters, 12 acceptance criteria, and 18 scenario tests.
- `git ls-remote origin refs/heads/feature/issue-137-sdd-context` returns `07d94ee6ddb9ae4b33b3ac539f0e0d6ea0bfd646`. An exact-head, all-states PR query returns no PR.
- At that commit, `specs/sdd-context/requirements.md` Overview, Goals REQ-002/004/006, Non-goals, and Main Workflows still specify deterministic repository snapshots, recovery from HANDOFF, and unconditional non-blocking compaction. This is the old design, not the current issue's WAL contract.
- At that commit, `specs/sdd-context/tasks.md` declares Task-Review-Status Passed but all T-001 through T-008 are Approval Draft / Status Planned. A status declaration alone is not an independently revalidated review gate. Generic repository execution approval is not a substitute for the required task-specific human approval.
- A tracked-tree listing for `plugins/sdd-context` returns no files at that commit. Specification and task-review artifacts do exist. This proves absence in that exact branch tree, not absence from every remote branch or untracked worktree.

## Material differences

| Current issue requirement | Existing branch contract | Consequence |
| --- | --- | --- |
| Persist raw user events before interpretation; capture available assistant output | Generate a snapshot from repository state at PreCompact | Cannot preserve an unmaterialized conversation decision |
| Reconcile observable transcript tail into WAL | Snapshot and compact-log workflow | Mid-turn recovery is not specified |
| Rebuild derived projection using authoritative state plus WAL and decision evidence | Read latest HANDOFF for resume | Current stale-state and decision-evidence obligations are not established |
| Visible manual durability failure with supported safe stop; automatic compaction must not deadlock | Never block compaction under any condition | Failure policies require explicit reconciliation |
| Twelve revised ACs and eighteen scenario tests | Sixteen older snapshot/boundary ACs | Old review PASS cannot establish coverage of the revised issue |

## Primary review of delegated investigation

The lightweight explorer found the correct branch and absence of implementation, but called its old requirements the issue's actual acceptance scope and described an approved task set. Primary rejected both conclusions after directly reading the current issue body and branch task/requirements files. All eight tasks are Draft, and the issue explicitly supersedes the branch design.

## Next permissible action

Preserve the existing branch and review history. Reconcile and re-review the specification against the issue's 2026-08-29 revision before approving or implementing tasks; do not implement the easier obsolete snapshot design. Verify current upstream runtime contracts before making implementation claims, as the issue requires. The previously recorded specification-entry handshake blocker must be resolved through a sanctioned path; no denied operation may be rerouted. No request to approve the old T-001..T-008 as-is is justified by this investigation.
