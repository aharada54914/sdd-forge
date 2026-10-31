# Manual precheck override note

task-review-precheck.sh fails at the persisted-spec-contract cross-check due to
the incompatibility documented in issue #61 (and its false-positive
Risk/Workflow file-level grep, also recorded on #61). Per the human decision in
this session (2026-07-04), the spec/impl contract machine cross-check is
replaced by human approval. All other precheck validations were performed
manually with identical logic and passed:

- Task-Review-Status: Pending present in tasks.md header
- Risk/Required Workflow coherence verified per task block (T-001..T-005 high/tdd,
  T-006/T-007 medium/acceptance-first, T-008 low/acceptance-first)
- check-task-state.sh and check-risk.sh both pass for 8 tasks (run this session)
- Blockers format valid (all None), dependency graph: 8 nodes / 0 edges / no cycle
- STEP 6 foundation review-contract validation executed and passed
- spec round-3 PASS contract and impl round-2 PASS contract exist at
  reports/spec-review/... and reports/impl-review/... (verified this session)
- input hashes recorded in precheck-result.json (tasks 450e25d7e1bbb11b0e26b9f9e2d6c841356077630bdaf74f4e69da0e9cf2bcdd)
