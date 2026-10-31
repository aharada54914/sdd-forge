# MCP report lookup cache operational acceptance — DRAFT

This prospective acceptance packet was authored after the recovered implementation
and its tests. It is not a claim of specification-first implementation or TDD.
Implementation recovery source: 451fa4c9; inspected final source: 75b169fe.

## Requirements
- REQ-001: Scan/read report files once within one parser/tool request rather than once per completed task; maintain existing matches, ordering and diagnostics.
- REQ-002: Keep snapshots confined to root identity and one request. Changed, replaced, deleted, denied or symlink-escaped files must never reuse a stale PASS in a later request.
- REQ-003: Preserve lazy behavior for planned-only tasks, and validate completed task evidence as before.
- REQ-004: Record real TypeScript checks, build, full regression and the recovered report-reuse test results. Existing output contracts remain unchanged.
- REQ-005: After genuine human approval and Context publication, observe this acceptance work with the actual advisory collector; retain authentic CI association and failure/recovery findings. No inactive-gate or isolated fixture result substitutes for this requirement.

## Already observed technical evidence
The final dependency lock fullsuite passed 309 tests, zero skips, including ten
report-reuse cases. The same fullsuite execution is referenced as unit, acceptance
and regression evidence; it is one run. Actual typecheck, build and production
audit also passed. Raw records are retained under verification/T-001/.

## Not yet established
Human task approval, genuine Context approval/publication, actual advisory
observation and real release-cycle acceptance have not occurred. These are
prospective acceptance work; they are not retroactively attributed to the code
recovery. Runtime source binding relies on the preserved commit/file comparison
and the original execution record; no clean-commit test certificate is invented.
