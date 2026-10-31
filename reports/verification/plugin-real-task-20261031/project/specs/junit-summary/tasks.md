# Tasks (lite): JUnit summary CLI

## T-001 Implement and verify the local JUnit summary CLI
Approval: Draft
Status: Planned

### Scope

- Implement REQ-001 through REQ-008 in requirements.md following design.md.
- Add `junit_summary.py` and `tests/test_junit_summary.py`; extend `README.md`.
- Record a real initial failing behavior test before application implementation,
  retain raw Red/Green outputs and exit statuses, and write the implementation report
  at the paths in design.md. Do not fabricate evidence.
- Use Python standard library only. Preserve input bytes and unrelated files.

### Done When

- The documented CLI produces deterministic counts across nested, namespaced,
  conflicting-outcome and multiple-report inputs, ignoring suite totals.
- Exit 0/1/2 behavior, empty suites, no partial output on invalid input, concise
  diagnostics, help and byte preservation are verified by actual CLI tests.
- `python3 -m unittest discover -s tests -v` passes with the coverage in design.md.
- Raw Red/Green outputs and the implementation report identify the commands and
  observed statuses; README documents use and testing.
- After human approval and implementation, the applicable lite gate verifies the
  result before any Done transition. Independent final review remains in another context.

### Blockers

- Human review and task approval are required before implementation. This stage
  authorizes neither application/test implementation nor task approval.
