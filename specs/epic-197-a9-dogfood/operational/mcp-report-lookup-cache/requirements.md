# MCP report lookup cache operational acceptance

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
audit also passed. Raw records are retained under verification/T-678/.

## Operational progress
The owner authorized this prospective task and registry/Context candidate in the
development conversation. Protected CI run 41258114242 subsequently issued and
validated the exact candidate after the actual owner environment review. Its
four-file publication was applied transactionally on this activation branch;
see ../../verification/T-678/phase1-publication.json. The agent did not obtain
the new environment signing key. Final-head advisory CI association and the real
release interval remain pending. These events are not retroactively attributed
to code recovery. Historical source binding and execution records remain unchanged;
no new clean-commit fullsuite certificate is invented.

## Current approval and evidence scope
Owner authorization is transcribed in approval-provenance.json. The agent records
that decision; it does not claim an independently authenticated GitHub review.
Historical raw execution records remain byte-identical to the exported packet.
The current task-state check is separately rerun for Approved / Planned.
