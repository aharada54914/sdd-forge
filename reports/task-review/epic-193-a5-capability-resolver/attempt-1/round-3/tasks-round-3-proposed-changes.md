# Task Review Report: epic-193-a5-capability-resolver — Round 3 / Attempt 1 (FINAL ROUND)

## Verdict: BLOCKED

| Field | Value |
|---|---|
| Feature | epic-193-a5-capability-resolver |
| Round | 3 of 3 (final) |
| Attempt | 1 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 3 (FAIL-check count, per SKILL.md's own merge formula — reviewer-b's own `findings[]` array has 5 entries, since it recorded three independent DEPENDENCY-OVERLAP instances (T-004/T-006/T-008) under one FAIL check rather than one combined entry; see "Process Note" below) |
| Minor Findings | 0 |
| Generated | 2026-07-22T (round-3 completion) |

Per `task-review-loop/SKILL.md` STEP 6: "Round == 3, Critical or Major
findings remain → BLOCKED... Use `--reset` to start a new attempt after
addressing the root causes." Attempt 1 is therefore closed as BLOCKED;
attempt 1's own evidence (`attempt-1/round-1` through `attempt-1/round-3`)
remains in place, unmodified, per the SKILL's own `--reset` convention.

## Reviewer-A Findings (Structural Coverage)

None — 14/14 checks PASS, `findings: []`.

## Reviewer-B Findings (Quality/Risk)

- **TASK-SIZE** (Major, `T-002`): T-002 still authors the entire
  undivided 14-step engine (API/Contract Plan steps 0-13 — argument
  validation, state derivation, canonicalization, Context Projection
  assembly, `resolve-component-paths` invocation, Registry discovery,
  trigger evaluation, conditional-facet evaluation, WARN check, track
  branch, Evidence assembly, output-schema validation, snapshot recheck)
  in one task. Rounds 1 and 2 relocated only test suites (first the
  cli/discovery/lite suites, then the block suite); neither round
  reduced the engine's own production-code scope.
- **SCOPE-DISJOINT** (Major, `T-004`): T-003 (block suite) and T-004
  (cli/discovery/lite suites) both target the identical shared
  CI-registration files (`tests/run-all.sh`/`.ps1`, the staged
  `human-copy/.github/workflows/test.yml` candidate) with no Blockers
  relationship between them. T-004's own Scope/Planned Files text still
  literally says its steps are "appended after T-002's own" — a
  leftover from round 1's numbering that was never corrected when
  round 2 inserted the new T-003 (block suite) between T-002 and T-004
  in the registration order.
- **DEPENDENCY-OVERLAP** (Major, three instances — `T-004`, `T-006`,
  `T-008`): each task's own Scope text names a real dependency (T-004 on
  T-003; T-006 on T-004; T-008 on T-007) that is absent from both its
  direct Blockers field and its transitive closure. Round 2's own remedy
  fixed the analogous gap for T-007 (which now correctly cites
  T-002/T-003/T-004/T-005/T-006) but did not extend the same fix to
  T-004, T-006, or T-008, which retain the identical class of gap in the
  same shared-file serialization chain.

## Process Note (transparency, not a finding to act on)

Reviewer-b's own `findings[]` array contains 5 entries for 3 FAIL checks
— `DEPENDENCY-OVERLAP` alone contributed 3 entries (one per task
instance: T-004, T-006, T-008), rather than the single combined entry
its own role file's Output Format section literally specifies ("findings
must contain exactly one entry per check whose result is FAIL"). This
orchestrator used the count of FAIL *checks* (3), not the raw
`findings[]` length (5), for `findings_major` in `integrated-verdict.json`
and `task-review-contract.json`, matching `task-review-loop/SKILL.md`
STEP 5's own literal formula ("count of FAIL checks with severity Major
(across both)"). This does not change the merged verdict (BLOCKED either
way, since round == 3 and Major findings > 0) and is recorded here for
transparency rather than corrected in reviewer-b's own persisted file —
findings are facts this orchestrator does not edit.

## Root-Cause Assessment (for attempt 2)

Both remedy rounds so far treated TASK-SIZE as a "which suite is bundled
with the engine" question and never revisited the engine's own 14-step
scope. Attempt 2 will split the engine itself, along design.md's own
natural pipeline-phase boundaries (each Block condition documented in
requirements.md REQ-002 fires before any *later* step runs, so an
early-phase task's own Block-condition fixtures are genuinely testable
against a partial engine without needing later phases to exist):

1. Input validation + Context normalization (steps 0-4): argument
   validation, state derivation (`disabled-legacy-invocation`,
   `workflow-combination-invalid`), Project Context canonicalization
   (`project-context-validation-failed`), Context Projection assembly,
   `resolve-component-paths` invocation (`affected-component-
   resolution-failed`).
2. Registry discovery + Capability evaluation (steps 5-9): Registry
   discovery + digest (`registry-validation-failed`,
   `contract-discovery-failed`), trigger/conditional-facet evaluation
   fan-out (`canonicalizer-invocation-failed`, `dependency-subprocess-
   failed`, `dependency-output-malformed`), the any-branch WARN check
   (`dsl-warn-on-matched-capability`).
3. Track branching + Evidence assembly (steps 10-13): track branch and
   dual-track staging (`lite-check-source-undefined`), Resolver Evidence
   assembly, output-schema self-validation
   (`output-schema-validation-failed`), pre-publication snapshot recheck
   (`snapshot-generation-mismatch`) — this is also the only phase that
   produces a complete staged result, so the full `match`-suite
   end-to-end fixtures (union-match, field-assembly, Facet Manifest
   schema-conformance, byte-identity/aggregation/provenance) belong here.

Each phase's own Block-condition fixtures are Red→Green-testable against
that phase alone (a Block exits before any later, not-yet-implemented
phase would run); the full `match` suite (needing the complete pipeline)
lands with phase 3. This directly addresses TASK-SIZE by finally
reducing the engine's own per-task scope, not merely relocating tests.

For SCOPE-DISJOINT/DEPENDENCY-OVERLAP: attempt 2's own Blockers graph
will be re-derived so **every consecutive pair in the declared
CI-registration serialization chain has a direct (not merely transitive)
Blockers edge**, closing the exact class of gap both remedy rounds left
open.

## Next Steps

`--reset`: attempt 1's own evidence remains in place; a new
`attempt-2/round-1` begins with the redesigned `tasks.md`/
`traceability.md` above. `Task-Review-Status:` clears to `Pending` (per
SKILL.md STEP 7) pending attempt 2's own precheck and reviewer
invocations.
