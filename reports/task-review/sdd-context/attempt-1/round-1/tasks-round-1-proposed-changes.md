# Task Review Round 1 — Proposed Changes: sdd-context

Verdict: **NEEDS_WORK** (0 Critical, 5 Major, 0 Minor)
Reviewer A: NEEDS_WORK · Reviewer B: NEEDS_WORK

Both reviewers independently reached the same root problem from different
directions: the decomposition states its dependencies in prose but declares
`Blockers: None` everywhere, so nothing machine-readable sequences the work.

## Reviewer-A Findings (Structural Coverage)

- FAIL — `DEPENDENCY-COMPLETE` (Major): T-001's Scope says "every other task
  depends on this skeleton existing", and T-006's Out of Scope excludes "the
  core logic the wrappers delegate to (T-002 through T-005)" — yet all eight
  tasks declare `Blockers: None`, and `dependency-graph.json` records
  `edges: []`.
- FAIL — `OBSERVABLE-DONE` (Major): every task carries the identical Done-When
  item "traceability.md updated with T-NNN → REQ-NNN mapping". That artefact is
  frozen once this gate passes, and the mapping it asks for is already present
  in traceability.md's Task Mapping table. The item is unsatisfiable as written
  and describes content that predates the gate.

Passing: PREREQ-AC-IDS, BLOCKERS-FORMAT, REQ-COVERAGE, AC-COVERAGE, ORPHAN-TASK,
ORPHAN-TEST, INITIAL-STATE, RISK-WORKFLOW-FORMAT, NO-DUPLICATE-AC,
DEPENDENCY-CYCLE, SINGLE-CONCERN, TRACEABILITY-SYNC.

## Reviewer-B Findings (Quality and Risk)

- FAIL — `DEPENDENCY-OVERLAP` (Major): the same gap seen from the sequencing
  side. T-002 "Consumes the boundary value produced by T-003"; T-004 "Consumes
  the artefact written by T-002"; T-006 delegates to the core built in
  T-002..T-005; T-007 covers "the whole hook execution path established by
  T-002 through T-006". None of these appear as Blockers.
  `blockers_format_valid: true` in the precheck only confirms the field is
  syntactically well-formed, not that it reflects the real graph.
- FAIL — `SCOPE-DISJOINT` (Major): T-007's Planned Files include "hardening
  changes to `plugins/sdd-context/scripts/*.mjs` as the scan requires" — an
  unbounded glob over the exact files T-002 through T-006 own, with no Blockers
  relationship to sequence the edits.
- FAIL — `ROLLBACK-PLAN` (Major): T-006 and T-007 are the two `high` tasks and
  neither has a `Rollback:` field nor any rollback-related Done-When item.
  `infra-spec.md` has a `## Rollback` section documenting a revert-commit
  procedure, but neither task references it.

Passing: RISK-APPROPRIATE, HIGH-CRITICAL-EVIDENCE, TASK-SIZE,
EDGE-CASE-COVERAGE, TEST-TYPE-MATCH. Skipped: BUGFIX-DIAGNOSTIC-PATH (no
bugfix task in scope).

Reviewer B also recorded one non-blocking observation: T-005's Scope claims
"Exit 0 under every degraded condition" for the PostCompact write path, but no
AC/TEST-ID covers a missing-or-read-only `.sdd/context/` for that path the way
AC-013 does for PreCompact. That is a traceability completeness note, not a
finding.

## Proposed Changes

Apply the following to `specs/sdd-context/tasks.md`.

1. **Declare the real dependency graph in every `Blockers:` field.** The
   dependencies the tasks' own prose already states are:
   - T-002 … T-008 each blocked by T-001 (the skeleton and manifests they build
     into)
   - T-002 additionally blocked by T-003 (it consumes the boundary value)
   - T-004 additionally blocked by T-002 (it consumes the handoff artefact)
   - T-006 additionally blocked by T-002, T-003, T-004, T-005 (it delegates to
     that core)
   - T-007 additionally blocked by T-006 (it verifies and hardens the completed
     execution path)
   - T-008 needs only T-001

   Note that T-002's stated dependency on T-003 reverses the current document
   order. Either record it as written, or re-order so the producer precedes the
   consumer; do not leave the two inconsistent.

2. **Replace the traceability Done-When item in all eight tasks.** Substitute a
   record that is actually writable after the gate — for example the
   implementation report's requirement cross-reference, or the
   `specs/sdd-context/verification/TEST-NNN.log` evidence entry the traceability
   file's own "Verification Evidence Paths" section names.

3. **Bound T-007's Planned Files.** Replace the `*.mjs` glob with the specific
   files the security scan may harden, and rely on the T-006 blocker added in
   item 1 to sequence those edits after the implementation tasks close.

4. **Add a rollback criterion to T-006 and T-007.** Reference
   `infra-spec.md`'s `## Rollback` procedure explicitly and add a checkable
   Done-When item (for example, "Revert procedure identified and the revert
   verified to restore the pre-task hook behaviour").

5. **Optional, non-blocking**: give the PostCompact degraded-write path its own
   acceptance criterion, or narrow T-005's Scope wording so it does not claim
   coverage no AC asserts.

## Next Steps

1. A human edits `specs/sdd-context/tasks.md` per the proposed changes above.
2. Re-run round 2 with `--edit-summary "<summary of the edits>"`.
3. `Task-Review-Status` is not to be changed by hand; the state machine sets it
   when a round reaches PASS.
