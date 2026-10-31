# Issue 423 T-003 fresh implementation ownership

Owner checkout: issue423-approved-recovery/sdd-forge, branch codex/issue423-boundary-checkpoint.
Observed HEAD: 3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9. Existing 243 dirty entries are preserved.
Risk: high. Selected obligations and fail-closed quality evaluation affect the verification boundary.
Scope: approved T-003 only; reuse Registry/Project Context resolver, preserve legacy-required checks, add selected-plan evaluation and mandatory quality-gate consumption, schema and regression registration. No deployment/promotion or T-004 implementation.
Affected contracts: selected-verification-plan/v1 candidate, Registry v1, facet manifest, verification contract, existing resolver evidence and quality-gate requirements. The candidate design-boundary addendum is not new approval authority.
Fresh implementation identity: 01a1409f-5fa6-7ef0-9d05-040b8b5e0649. Attempt 5 was preparation/investigation only; attempt 6 owns implementation. Previous compacted contexts will not implement.
Prerequisite T-002 is Done with independent PASS in reports/quality-gate/20261014-sdd-domain-multitarget-T-002.md. The historical T-003 blocker paragraph describes attempt 4, is retained, and is superseded only for current execution by the validated new handoff. It does not become success evidence.
Validation: immutable task-input snapshot; high-risk persisted-field/sibling/mismatch preflight; RED before source change; GREEN plus legacy resolver regressions; run-all registration; independent Codex review and quality-gate decision. Product-host activation, CI and release remain separate and unclaimed.
No authenticated remote operation pending previously reported credential rotation. No credential values or environment dumps are permitted. This does not prevent local implementation and verification.
Only the parent may make lifecycle transitions after checking their evidence; no child may declare Done or alter existing approvals, historical evidence or review ledger.
