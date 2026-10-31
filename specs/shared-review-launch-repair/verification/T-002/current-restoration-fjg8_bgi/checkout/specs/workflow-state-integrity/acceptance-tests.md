# Acceptance Tests: workflow-state-integrity

| AC-ID | Requirements | Scenario | Pass condition |
|-------|--------------|----------|----------------|
| AC-001 | REQ-001 | Validate a registry exactly covering current first-level spec directories. | Both runtimes exit 0. |
| AC-002 | REQ-001, REQ-007 | Add an unregistered directory, dangling entry, duplicate, unknown profile, traversal, and escaping symlink in isolated fixtures. | Each case exits nonzero with the same rule ID in shell and PowerShell. |
| AC-003 | REQ-002 | Set Task to Passed while Spec or Impl is Pending in a full fixture. | Both runtimes reject the predecessor inversion. |
| AC-004 | REQ-003 | Test missing, malformed, stale-hash, wrong-feature, wrong-stage, non-PASS, and forged review contract/verdict fixtures. | Every invalid provenance case is rejected; a current valid contract passes. |
| AC-005 | REQ-004, REQ-012 | Exercise the task boundary matrix: (a) tasks absent while Spec/Impl are incomplete, (b) Draft/Planned with Spec+Impl Passed and Task Pending, (c) Draft/Planned after Task Passed, and (d) Approved/In Progress/Implementation Complete/Done with each predecessor missing, including sudo environment. | (a), (b), and (c) pass; creating tasks before Spec+Impl PASS and every case in (d) with an incomplete chain fail regardless of sudo or pre-existing state. |
| AC-006 | REQ-005 | Validate exact historical legacy records, then broaden an exception or add an unbounded fallback. | Exact records pass; broadened/unbounded records fail. |
| AC-007 | REQ-006 | Validate an explicitly registered lite fixture without full review headers. | Workflow-state checker does not apply full review rules; existing lite tests pass. |
| AC-008 | REQ-007, REQ-010 | Run parity fixtures with LF and CRLF artifacts on supported non-Windows/Windows jobs. | Shell and PowerShell outcome/rule IDs match; CRLF does not change results. |
| AC-009 | REQ-008 | Run repository validation and CI entry points against an invalid persisted state. | Validation fails before packaging/release success is reported. |
| AC-010 | REQ-008 | Inspect and execute full quality-gate and downstream precheck paths. | They invoke scoped/global workflow validation and retain existing predecessor checks. |
| AC-011 | REQ-009 | Inspect registry and uninstall retrospective record. | Commit `277a79d`, changed implementation/tests, and unavailable historical review provenance are traceable without a fabricated PASS. |
| AC-012 | REQ-010 | Run existing review-precheck, task-state, guard, scenario, install, uninstall, and repository suites. | All existing supported suites pass. |
| AC-013 | REQ-011 | Validate all manifests, both marketplaces, changelog, and repository version constants. | Every released plugin surface reports `1.3.0`; install/release validation passes. |
| AC-014 | REQ-003, REQ-007 | Corrupt JSON, remove required files, or deny reads in isolated fixtures. | Checker fails closed with a stable diagnostic and no partial PASS. |
