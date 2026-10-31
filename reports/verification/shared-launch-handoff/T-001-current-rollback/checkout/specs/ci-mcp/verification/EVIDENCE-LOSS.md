# Evidence Loss Record — ci-mcp (T-001..T-013)

**Status:** Known, permanent, non-repairable. Recorded per
[WFI-008](../../../docs/workflow-improvements/WFI-008.md) (approved
2026-07-12).

Every raw quality-gate log referenced under `verification/qg/T-NNN/` by this
feature's `T-NNN.contract.json` / `T-NNN.evidence.json` files is lost. As a
result, `check-task-state.sh specs/ci-mcp/tasks.md` and
`check-evidence-bundle.sh` on each of the 13 bundles FAIL deterministically,
and are EXPECTED to fail. This failure state is pinned as the golden
expectation in `mcp/sdd-forge-mcp/tests/golden/fixtures/ci-mcp.expected.json`
— any CHANGE to the failure set (including a silent flip to PASS) is a CI
regression, not an improvement.

## What is missing (71 unique files)

| Task | Missing logs under `verification/qg/<task>/` |
|---|---|
| T-001 | build.log, check-placeholders.log, check-task-state.log, tests.log, typecheck.log |
| T-002 | build.log, check-placeholders.log, check-task-state.log, check-traceability.log, tests.log, typecheck.log |
| T-003 | build.log, check-placeholders.log, check-task-state.log, check-traceability.log, tests.log, typecheck.log |
| T-004 | build.log, check-placeholders.log, check-task-state.log, check-traceability.log, tests.log, typecheck.log |
| T-005 | build.log, check-placeholders.log, check-task-state.log, check-traceability.log, tests.log, typecheck.log |
| T-006 | build.log, check-placeholders.log, check-task-state.log, check-traceability.log, tests.log, typecheck.log |
| T-007 | build.log, check-placeholders.log, check-task-state.log, check-traceability.log, tests.log, typecheck.log |
| T-008 | build.log, check-placeholders.log, check-task-state.log, tests.log, typecheck.log |
| T-009 | check-placeholders.log, check-task-state.log, check-traceability.log, install-tests.log, tests.log |
| T-010 | check-placeholders.log, check-task-state.log, check-traceability.log, tests.log, uninstall-tests.log |
| T-011 | check-placeholders.log, check-task-state.log, tests.log |
| T-012 | build.log, check-placeholders.log, check-task-state.log, check-traceability.log, tests.log, typecheck.log |
| T-013 | build.log, check-placeholders.log, check-task-state.log, check-traceability.log, tests.log, typecheck.log |

## Why they are lost

1. At the time these gates ran, `.gitignore` carried the blanket `*.log`
   rule with only the flat re-include `!specs/**/verification/*.log`; the
   nested re-include `!specs/**/verification/**/*.log` covering
   `verification/qg/T-NNN/*.log` did not exist yet on this history. The logs
   were silently ignored at commit time.
   `git log --all --diff-filter=A -- 'specs/ci-mcp/verification/qg/*.log'`
   is empty: they were never committed anywhere.
2. The only copies lived in the throwaway worktree `sdd-forge-p4`, which was
   deleted after the feature completed.

## What remains intact

- Every quality report (`reports/quality-gate/*-ci-mcp-T-NNN.md`) exists
  with matching SHA-256, including the independent evaluator's
  `VERDICT: PASS` for each task.
- Every `T-NNN.contract.json` exists with matching SHA-256.
- Every recorded `git_commit` exists and is an ancestor of HEAD.
- The cross-model/evaluator invocation records that were JSON
  (`verification/qg/T-NNN/invocation-evaluator*.json`) survive where they
  were produced.

Only the raw gate stdout logs are gone; the human-readable attestation chain
for how each task reached Done is preserved.

## Why the bundles are NOT repaired or regenerated

`check-evidence-bundle.sh` binds every artifact to its recorded SHA-256, so
re-run logs can never match the original hashes — and rewriting
`evidence.json` / `contract.json` to reach PASS without the original
evidence is exactly the tampering class the threat model defends against
(docs/THREAT-MODEL.md, "Agent modifies evidence"). The deterministic FAIL is
the integrity design working as intended: it truthfully reports that
evidence was lost. See WFI-008 for the full disposition analysis, including
why gate re-execution (re-certification) was rejected as
disproportionate.
