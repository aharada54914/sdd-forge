# Requirements: workflow-state-integrity

Spec-Review-Status: Passed

## Overview

Persisted SDD artifacts must obey the same Spec → Impl → Task ordering that
transition prechecks already enforce. v1.3.0 introduces a repository-wide,
portable, fail-closed integrity gate and an explicit migration record for
historical artifacts.

## Goals

- Make inconsistent review states fail in repository validation, CI, and the
  full-track quality gate.
- Keep current transition, approval, evidence, install, and uninstall behavior
  intact.
- Distinguish historical debt from current valid state without inventing
  provenance.
- Maintain deterministic POSIX/PowerShell parity.

## Requirements

- **REQ-001 — Authoritative registry:** Add a machine-readable registry that
  enumerates every first-level `specs/<feature>/` directory and declares exactly
  one profile: `full`, `lite`, or `legacy`. An unregistered directory, duplicate
  entry, unknown profile, path traversal, or registry entry without a directory
  must fail.
- **REQ-002 — Full-profile ordering:** For a `full` feature, the checker must
  require canonical status headers and enforce:
  `Task Passed ⇒ Impl Passed ⇒ Spec Passed`. A downstream `Pending` stage must
  not coexist with a later `Passed` stage or executable/completed task state.
- **REQ-003 — Verdict provenance:** Every `Passed` full-profile stage must have
  a matching latest passing review contract and integrated verdict whose
  feature, stage, attempt, round, hashes, reviewer identities, and verdict
  satisfy the existing stage contract. A header alone must never prove PASS.
- **REQ-004 — Task lifecycle coupling:** In a full profile, `tasks.md` and its
  Draft/Planned task entries may be created only after Spec and Impl are validly
  Passed. While task review is pending, those entries must remain
  `Approval: Draft` and `Status: Planned`. After Task is validly Passed, tasks
  may remain Draft/Planned while awaiting human approval. `Approval: Approved`
  or a status of In Progress, Implementation Complete, or Done requires Spec,
  Impl, and Task all to be validly Passed. No task lifecycle state may be used
  to skip a predecessor review.
- **REQ-005 — Explicit legacy migration:** `legacy` entries must identify a
  fixed pre-v1.3.0 cutoff commit, reason, owner, and exact allowed missing or
  noncanonical stages. The checker must reject wildcard exceptions, new
  unregistered legacy fallbacks, or a state broader than the recorded exception.
- **REQ-006 — Lite isolation:** `lite` entries must not be interpreted as
  full-track review failures. They remain subject to the existing lite gate and
  must be explicitly registered.
- **REQ-007 — Portable enforcement:** Provide equivalent POSIX shell and
  PowerShell entry points. Both must accept LF and CRLF artifacts, emit stable
  diagnostics naming feature/stage/rule, and return nonzero for the same invalid
  fixtures.
- **REQ-008 — Enforcement integration:** Run the checker from repository
  validation, CI, full-track quality-gate flow, and downstream review prechecks.
  Existing stage-specific preconditions remain in force.
- **REQ-009 — Historical traceability:** Register all current specification
  directories and add a retrospective source record for the uninstall change
  introduced by commit `277a79d`. Historical records must say that review
  provenance is unavailable rather than simulate approval.
- **REQ-010 — Regression coverage:** Test missing/stale/forged verdicts,
  predecessor inversion, completed tasks with incomplete reviews, unregistered
  directories, overbroad legacy exceptions, lite behavior, path safety, CRLF,
  and shell/PowerShell parity. Existing relevant suites must remain green.
- **REQ-011 — Release revision:** Bump all synchronized plugin manifests and
  both marketplaces from `1.2.0` to `1.3.0`, update validation constants and
  changelog, and preserve release/install compatibility.
- **REQ-012 — No privilege bypass:** Sudo mode, a pre-existing `Done` state, or
  a manually edited status header must not bypass workflow-state integrity.

## Non-goals

- Re-running or fabricating historical independent reviews.
- Changing the meaning of current review findings, task approvals, evidence
  bundles, critical two-person approval, or lite-gate policy.
- Replacing stage-specific review prechecks with the global checker.
- Changing installer or uninstaller user-facing behavior.
- Introducing a network service or non-standard runtime dependency.

## Constraints

- Architecture changes require an ADR in `docs/adr/`.
- API/data formats require a versioned schema in `contracts/`.
- New full-profile features cannot select `legacy`.
- Only quality-gate may set a task to `Done`.
- The repository's six plugin versions remain synchronized.

## Acceptance criteria

See `acceptance-tests.md` for AC-001 through AC-014.
