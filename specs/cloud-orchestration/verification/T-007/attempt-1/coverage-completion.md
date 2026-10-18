# T-007 bounded installed predecessor coverage completion

Same Run/Session/Agent Instance ID: `01a14f96-e637-7773-aa3b-74e44216f500`.
Task Attempt Count: 1. Model: openai/gpt-6-astra. Effort: high.
This 2026-10-18 follow-through changes only `tests/install-cloud.tests.py`
and this task's report/evidence; no production semantics, review, or lifecycle status change.

## Boundary and controls

The first handoff's generic missing/invalid denial assertions used `prior.json`.
They did not isolate canonical predecessor-path validation, and prepare/apply
are denied by the separate no-executor gate. Historical results are retained
as actually executed, not relabeled as stronger field-validation evidence.

The new fixture uses:
`specs/cloud-orchestration/verification/T-007/cloud/prior-run/prior-unit/verification.json`.
Its `cloud-verification/v1` run/unit/provider, request reference unit, profile
reference bytes, complete required check IDs and referenced synthetic bytes are
structurally matched. This is local route integrity only. The referenced
observation bytes are deliberately labeled synthetic structural data, not
native observations. Neither a saved fixture nor route PASS confers authority,
proves health, or simulates governed CI.

| Variant | Actual installed route assertion |
|---|---|
| matched | Exit 0, PASS, null error_code, output exists |
| missing | Remove only receipt file after hashing; exit 2, BLOCKED, UNSAFE_OR_UNAVAILABLE_FILE, no output |
| invalid | Remove one check but retain required_check_ids and recompute the actual receipt digest; exit 2, BLOCKED, CHECK_SET_MISMATCH, no output |
| restored | Restore matched body and digest; exit 0, PASS, null error_code, output exists |

Existing boundary sources: `cloud_contracts._parent/read_verified` maps the
missing file to `UNSAFE_OR_UNAVAILABLE_FILE`; `_verification` compares check IDs
against required_check_ids using `CHECK_SET_MISMATCH`; `verify_local_context`
checks receipt unit and canonical path. Correct digest and path plus matched
and restored positive controls keep unrelated guards from satisfying the
negative assertions. No production guards were patched for these CLI checks.

All four variants executed across 32 payload invocations: Bash and real
PowerShell, Azure alone/AWS alone/both, installed trees plus isolated
Codex/Claude/Copilot cache copies. The existing explicit missing-runtime-root
no-development-fallback and omitted cloud_dependencies.py checks also ran.
The separate authenticated-deadline callable probe is byte-identical and
retains scoped mocks and guard-bypass sensitivity. Public prepare/apply still
assert OPERATION_UNIMPLEMENTED, never predecessor-admission validation.

## Verification and preservation

- `coverage-completion-packaging.json/.log`: 11 scoped test methods pass;
  no full repository suite or live cloud actions.
- `coverage-completion-ruff.json/.log` and `coverage-completion-mypy.json/.log`:
  pinned Python with explicit `tests/shared-launch-python/pyproject.toml`;
  check_untyped_defs=true; no suppressions or cross-provider Python imports.
- `coverage-completion-manifest.json/.log`: original manifest validates against
  its intact initial scratch snapshot.
- `coverage-completion-diff.json/.log`: changed test whitespace check succeeds.
- `coverage-completion-entry.json` records pre-edit hashes;
  `coverage-completion-preservation.json/.log` records the actual audit command;
  `coverage-completion-result.json` contains current task file hashes and scope.
- All 113 historical evidence artifacts checked remain byte-identical,
  including first-handoff-report.md and the initial input manifest.
  Historical Red, command logs and original native delivery were not edited.

## Rollback qualification

`final-rollback-result.json` remains unchanged. Its isolated checkout experiment
covers the exact final production bytes and the prior test bytes. Of its 22
candidate paths, 21 are unchanged; only `tests/install-cloud.tests.py` differs.
The strengthened suite was rerun successfully against those unchanged production
bytes. The earlier rollback is not claimed to have exercised the later test-only
delta. No unrelated regression or rollback experiment was repeated.
`changed-files.json` and `command-summary.json` remain first-handoff inventories;
the new result/command evidence and canonical report Outputs give current bytes.

Raw native stdout/stderr, account metadata and mutable transport logs remain
private and are not public delivery outputs. Root owns independent review and
formal gate decisions; this completion is neither a gate PASS nor Done.
