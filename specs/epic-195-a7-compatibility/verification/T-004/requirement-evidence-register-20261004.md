# A7 requirement evidence register — bounded observation

This non-frozen addendum records where measured evidence exists. An evidence
path is not a PASS verdict: the structural `require-evidence` checker verifies
non-empty files, not completeness, current-head provenance, or acceptance.
The frozen `traceability.md` is unchanged. The task plan's 2026-10-04 amended
Done When still needs post-implementation provenance re-review.

| Requirement | Observed evidence | Scope and remaining obligation |
|---|---|---|
| REQ-002, T-004 → AC-005/006/007/030/042/043 | `activation-final-sh-20261004.log` 77 passed/0 failed; `activation-final-ps1-20261004.log` 84 passed/0 failed; `activation-mutation-sh-20261004.log` and `activation-mutation-ps1-20261004.log` each 5 killed/0 survived | Local offline structural suite and mutation observations. The T-004 independent gate, amended task provenance, current-head CI, and T-012's separate AC-031 are not proved by these logs. |
| REQ-003 | `verification/T-005/current-regression-20261003.md` reports six local Bash/PowerShell suite commands exit 0; `verification/T-010/current-working-tree-regression-20261004.md` reports loop-escalation 36/1 and 35/1 | Partial evidence only. The latter failure is T-008's real-interviewer invocation obligation. `verification/T-008/native-resume-preconditions-20261004.md` records a permission refusal and missing valid positive Context input; zero calls are not native negative proof. No REQ-003 completion claim. |
| REQ-004, AC-013/017/029 | This addendum's document review below | AC-013 clause links and AC-029 table presence are directly inspected. AC-017's universal factual-citation sweep has not been independently repeated here, so REQ-004 completion is not claimed. |
| REQ-007 | `verification/T-010/coordinator-recheck-20261004.md` records manifest 29/0 Bash and 32/0 macOS PowerShell; `verification/T-010/current-working-tree-regression-20261004.md` records related escalation failures | Partial manifest evidence only. Coordinator identifies unresolved requirements/AC activation conflict and no native T-008 caller proof. The earlier `current-validation-20261004.md` is superseded; do not promote it to a passing record. |

## REQ-004 bounded document review

- AC-013: `requirements.md:415-424` states clauses (a) byte, (b) event,
  (c) structural; `traceability.md:42-55` maps them to separate ACs.
  This establishes the written decomposition, not downstream task completion.
- AC-029: `design.md:315-356` contains 16 observable rows × F1–F8,
  with each cell explicitly marked byte, structural, event, or N/A.
  No blank cell appears in that inspected table. This establishes table
  presence and local cell classification, not a re-review of all design bytes.
- AC-017: `requirements.md:449-454` requires a universal file:line citation
  audit. `requirements.md:3` records Spec-Review-Status Passed and
  `design.md:3` records Impl-Review-Status Passed, but those historical
  statuses alone do not independently prove every present factual claim.
  A direct citation spot-check found concrete gaps in the frozen
  `investigation.md`: INV-007 (line 39) asserts the `tests/uninstall.tests.sh`
  line count and absence of a Project Context/capability concept but cites
  only the bare file path, without a line range or a recorded negative grep;
  INV-020 (line 52) asserts `specs/local-env-mcp` is a minimal registry-entry
  example but cites `specs/workflow-state-registry.json` without the entry's
  line number (the current entry begins at line 278). These are examples,
  not an exhaustive count. The later test changes also mean the historical
  INV-007 line count is not a claim about the current checkout. Because
  AC-017 requires citations in the spec document itself, this addendum does
  not retroactively satisfy it. A scoped citation correction was appended
  to `investigation.md` on 2026-10-04 and a fresh specification precheck
  (attempt 8 round 1, reset) completed. That is a new review input, not a
  review verdict. Keep AC-017 and REQ-004 partial pending independent
  review of the amended input; do not infer PASS from evidence-path
  existence or from the historical Spec PASS.

## T-011 CI ownership handoff

The historical whole-file candidate in
`verification/T-004/ci-candidate-ownership-audit-20261004.md` derives from
commit `a4829db1` and is stale against the live workflow. T-011 alone owns
`.github/workflows/test.yml` and its conditional human-copy route
(`tasks.md:45-49`, `tasks.md:65-68`, `tasks.md:1516-1558`). T-004 does not
apply or refresh that candidate. T-011 must re-evaluate the current protected
membership, regenerate/rebase a candidate against current live bytes, and
obtain its own approval and verification. No current-head CI is claimed.

## Bounded precheck results (2026-10-04)

- `derive-traceability-json.py --check`: exit 0, seven generated links in sync.
- `check-traceability.sh ... require-evidence`: exit 0, seven links; this is
  structural path coverage only and does not promote partial REQs to PASS.
- `check-risk.sh ... T-004`: exit 0.
- `check-contract.sh ... fresh-contract-candidate-20261004.json`: exit 1,
  intentionally, because unit, acceptance, regression, requirement
  traceability, component coverage, placeholder, and task-state checks
  remain `passes:false`. No historical qg-cycle2 check was imported as true.
- `check-workflow-state.sh --feature epic-195-a7-compatibility`: exit 1,
  `stage-provenance: task plan hash is stale` after the authorized T-004
  Done When amendment. Its investigation.md amendment-growth diagnostic is
  separately tolerated. The task-plan change needs the post-implementation
  provenance re-review; a green traceability check cannot replace it.
- `git diff --check`: exit 0. No old 77/84 or mutation suite was rerun.
