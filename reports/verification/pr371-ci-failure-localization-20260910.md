# PR 371: current-head CI failure localization

Read-only inspection on 2026-09-10. No test execution, source change, retry,
merge or passing verdict is recorded here.

GitHub PR head and failed run head both equal
`9e39c396f4ca8f9abe3c9aabb090868ada17b53f`.
The PR is BEHIND; current base is
`e00478321327b48e4e4ad21a14391d69e0f1baa9`.
Run 33256788058 is completed/failure, not an active wait target.

## Observed failures

- Windows test job 99111814795: TEST-004(c) near-boundary completion fails
  for gpt iterations 3/4 and gemini iterations 2/4. Each reports exit=1,
  verdict=0, budget_ms=2000. The suite ends 60 passed, 4 failed. Observed
  elapsed_ms are 2878, 3043, 3301 and 3085 respectively; these wall times
  alone do not prove whether process output crossed the internal deadline.
- macOS and Ubuntu MCP jobs: live shell comparison test 52 fails on
  risk-adaptive-layer, with parser verdict pass versus shell exit 1/fail.
  The recorded fixture comparison test 53 passes on both. This localizes the
  disagreement to live comparison, but does not prove which implementation
  is wrong or what causes the shell refusal.
- required-checks fails as an aggregate. It is not a third product defect.

Evidence:
[Windows job](https://github.com/aharada54914/sdd-forge/actions/runs/33256788058/job/99111814795),
[run containing both MCP logs](https://github.com/aharada54914/sdd-forge/actions/runs/33256788058).

Queries: `gh pr view 371 --json headRefOid,baseRefOid,files`,
`gh run view 33256788058 --json headSha,event,conclusion`, and
`gh run view 33256788058 --log-failed` (all with the explicit repository).
Log extraction used full-consuming grep, not an early-exit filter.

## Consequence for remediation

Do not classify all PR 371 failures as RT004 or blindly rerun unchanged CI.
After the recovery-entry exit requirements are satisfied, reconcile the
existing timing/supervisor work against these four Windows cases, and inspect
the live shell diagnostic for risk-adaptive-layer at the integration candidate.
Preserve the live parity assertion and deadline semantics; do not turn either
failure into an expected PASS. A refreshed main integration requires a new
complete CI result at its new head; this historical run cannot prove it.

The current open-PR query returns 11 PRs and no active CheckRuns. PRs
245/403/405 are DIRTY and have no CI success proof; 404/402/401/394/390/381/371
have failed checks; 400 remains BLOCKED. The recovery-only entry does not
authorize unrelated implementation or integration before its verified exit.

## Current-worktree direct diagnostic

Executed the original read-only command on 2026-09-10:

```sh
rtk proxy bash plugins/sdd-quality-loop/scripts/check-task-state.sh specs/risk-adaptive-layer/tasks.md
```

Exit 0, complete output:

```text
Verification contract passed for task T-010.
Evidence bundle passed for task T-010.
Task state check passed for 12 task(s).
```

This is 12 task records checked, not 12 regression tests and not a PR371 CI
PASS. Current input SHA-256 values:

- check-task-state.sh: `e91ca02d2907069b156a62e7dcf6a6fbfbebad89bb70d9be90c4c0ac429cf491`
- risk-adaptive-layer/tasks.md: `028232492079a2d654b3be296582dc5bf64aa376af0830d18ad678f020e848b5`
- T-010.evidence.json: `c9ee01c64c2646276c4e06ebf49817233108b2c840c30e4a6455f02cc275deb5`

Read-only comparison against pinned PR371 shows the current bundle already
contains the existing e72e4dcda2ce33dcdb276e1d605bc3ea66852fec correction:
different spec_revision, git_commit, dirty flag and added check records.
The old bundle binds a3a5c66c905211a3ad2dfe21814c6f6a9d8ba38d; current binds
e00478321327b48e4e4ad21a14391d69e0f1baa9. No evidence was regenerated here.

Do not implement another parser workaround on the strength of the old CI
assertion: its shell failure does not reproduce on these current inputs.
The next integration check must preserve the existing bundle correction and
RT005 mixed-failure controls, then run full live parser/shell comparison at
the actual integrated head. Windows timing failures remain separate and open.
