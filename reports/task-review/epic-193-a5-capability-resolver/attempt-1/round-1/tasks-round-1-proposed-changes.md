# Task Review Report: epic-193-a5-capability-resolver — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-193-a5-capability-resolver |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-07-22T11:34:00Z |

## Reviewer-A Findings (Structural Coverage)

None — 14/14 checks PASS, `findings: []`.

## Reviewer-B Findings (Quality/Risk)

- **TASK-SIZE** (Major, `T-002`): T-002 ("Author `resolve-project-context.{py,sh,ps1}`'s
  evaluation pipeline (steps 0-13)") spans far more than three distinct
  implementation areas in one task: it authors three production scripts
  implementing 12+ distinct pipeline stages (argument validation, REQ-003
  state derivation, workflow-combination validation, Project-Context
  canonicalization, Context Projection assembly, `resolve-component-paths`
  invocation, Registry discovery, per-Capability trigger evaluation,
  conditional-facet evaluation, the any-branch WARN check, the Full/Lite
  track branch and artifact staging, Resolver Evidence assembly,
  output-schema self-validation, and the pre-publication snapshot recheck),
  AND in the same task creates and registers five brand-new test suites
  with their own fixture trees (`resolve-project-context-cli`/`-match`/
  `-lite`/`-discovery`/`-block`) covering twelve of REQ-002's sixteen Block
  diagnostics plus AC-001..AC-009/AC-016/AC-028/AC-038/AC-040/AC-041/
  AC-043/AC-044/AC-048/AC-052/AC-055/AC-056. Not one coherent unit of work
  completable in a single focused session; by contrast T-003 and T-004 are
  each scoped to one cohesive mechanism. Recommends splitting T-002 so the
  core per-Capability evaluation/WARN/track-branch/Evidence-assembly logic
  is separable from its own CLI/discovery/lite-track suite authoring.

## Proposed Changes

Split T-002 into two tasks along the exact boundary reviewer-b names:

1. **T-002 (revised, narrowed)** — retains only the core evaluation engine
   (steps 0-13: argument validation, state derivation, canonicalization,
   Context Projection assembly, `resolve-component-paths` invocation,
   Registry discovery, per-Capability trigger/conditional-facet
   evaluation, any-branch WARN check, track branch + artifact staging,
   Resolver Evidence assembly, output-schema self-validation,
   pre-publication snapshot recheck) plus the one suite most directly
   tied to that logic (`resolve-project-context-match`) and the
   twelve non-transactional `resolve-project-context-block` fixtures
   (unchanged from the original T-002 — REQ-002's Block taxonomy fires
   during steps 0-13, the same core evaluation surface, not a peripheral
   concern).
2. **T-003 (new)** — "Author `resolve-project-context`'s CLI-validation,
   discovery-contract, and Lite-track test suites": `resolve-project-
   context-cli`, `resolve-project-context-discovery`, `resolve-project-
   context-lite`. Blocked on the revised T-002 (needs the core engine to
   exist to test against).

Every task from the old T-003 onward renumbers up by one (old T-003 →
new T-004, old T-004 → new T-005, old T-005 → new T-006, old T-006 → new
T-007), with Blockers/Depends-On references updated to match (including
new T-006's parity suite gaining new T-003 as an additional blocker,
since design.md Test Strategy item 5 requires parity coverage "across
every fixture above," which includes the CLI/discovery/lite fixtures
now owned by new T-003). `traceability.md`'s Task Mapping, Acceptance
Mapping, Deliverables, and Requirements tables are updated to match the
new seven-task numbering. No requirement, acceptance criterion, or test
suite is dropped or added — this is a pure task-boundary/numbering
change, not a scope change.

## Next Steps

Apply the split above to `tasks.md`/`traceability.md`, re-run
`task-review-precheck.sh` for a new round (round 2, `--edit-summary`
required), and re-invoke both reviewers fresh.
