# T-001 current repair evidence — 2026-10-09

This addendum supersedes current-repair completion claims, not historical verdicts.
The original implementation report and its Outputs remain historical and unchanged.
The supplemental declaration binds the current delivery bytes.

## Lifecycle
The existing Done state predates this repair and is supported by the historical
quality PASS copied as current-20261009/historical-quality-pass.md and its
historical-evidence.json. It does not assert this repair passed.
The old implementation report's In Progress state predates that PASS.
The new evaluation 93b6c91a-c34e-43c9-bdb4-02bf2ff13404 returned NEEDS_WORK,
Critical 0, Major 3, Minor 2. Its original wrapper and transcript remain unchanged.
Its major findings requested current raw regressions, current byte-exact rollback,
and evidence explaining the historic Done/report lifecycle mismatch.

## Current regressions
The nine adjacent *.log files are copies of the final current-code executions:
quality-nontty-transport 20, host-review-preflight 7, unified-task-launch 9,
unified-launch-order 9, task-structured-output 13, review-conditional-inputs 16,
shared-launch-build 1, t001-evaluation-preparation 8,
supplemental-delivery-declaration 17: total 100 passed, zero failed.
Each driver exited zero. The fixed two-file annotation/compact-only probe cleanup
preceded these runs.

Fresh static verification on the same current code:
- mypy --config-file tests/shared-launch-python/pyproject.toml:
  Success: no issues found in 6 source files; exit 0.
- ruff check with that config and the same six registered launcher/preflight Python
  files: All checks passed!; exit 0.

## Rollback
The admitted compact-runtime-rollback-* artifacts record the current coherent
24-target candidate, 62 passing candidate tests, reverse application and equality
with 26 original hashes (including originally absent files), and 42 passing restored
baseline tests. The audit and executable verification helper define exact commands.
The earlier failed mixed-runtime rollback remains preserved and is not counted as PASS.
These checks test source rollback in an isolated checkout, not installed state.

## Boundaries
The earlier rate_limited diagnostic boolean was a false positive from textual
matching; its event count was zero. It is not used as a verification result.
Formal re-evaluation, Windows execution, exact final-head CI, merge and installed
activation are not established by this addendum. No frozen document or task status
is changed. Current source identity is supplied by the supplemental declaration.
