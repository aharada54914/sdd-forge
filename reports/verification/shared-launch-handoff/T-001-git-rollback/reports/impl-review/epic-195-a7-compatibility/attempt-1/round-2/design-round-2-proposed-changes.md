# Implementation Policy Review Report: epic-195-a7-compatibility — Round 2 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-195-a7-compatibility |
| Round | 2 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-07-22T11:19:45Z |

## Reviewer-A Findings (Structural Soundness)

No FAIL findings. All 9 checks PASS or SKIP (8 PASS, 1 SKIP —
FRONTEND-BACKEND-CONSISTENCY, no frontend surface).

## Reviewer-B Findings (Implementability/Risk)

- **NO-REQ-CONTRADICTION (FAIL, Major)**: design.md's Compatibility Matrix
  F4/REQ-002 cell states AC-007's disposition as `SKIP-with-activation →
  AC-007 (until Epic A1 **and** Epic A4 both merge)`. This contradicts
  two independent sources: (1) requirements.md's own AC-007 text, which
  states the activation condition is `"Epic A4 merged to main"` — a
  single dependency, no Epic A1 clause; (2) design.md's own worked
  `skip-allowlist-manifest/v1` example (Data Plan), whose AC-007 entry
  lists only `{epic: A4, issue: 192}` with `activation_condition:
  "merged(A4)"` — again no Epic A1 clause. A Phase 2/3 implementer
  following the Matrix table versus the manifest example (or
  requirements.md itself) would build two non-interoperable activation
  conditions for the identical assertion.

  **Orchestrator verification**: independently confirmed by reading
  requirements.md:340-347 (AC-007's own text, "Epic A4 merged to
  `main`" only) and design.md's own skip-allowlist-manifest/v1 example
  (AC-007 entry, single A4 dependency) directly. Two of the three
  sources already agree with each other; the Compatibility Matrix cell
  is the sole outlier.

- **VERIFICATION-PATH-CONCRETE (FAIL, Major)**: two distinct issues in
  one check:
  1. The Compatibility Matrix's F3/REQ-003 and F4/REQ-003 cells cite
     `AC-034's F3/F4 entry` as their verification path, violating the
     Matrix's own Disposition legend rule that a `SKIP-with-activation`
     cell must cite the assertion's own AC — AC-034 defines the
     `skip-allowlist-manifest/v1` schema's *shape*, not a substantive
     assertion with its own `activation_condition`. The correct citation
     (AC-010/AC-025, the quality-gate-outcome/TEST-019 assertion) exists
     in requirements.md but is not used.
  2. F3's REQ-002 cell (Context-present-advisory, structural) has **no
     corresponding acceptance criterion anywhere** in requirements.md or
     acceptance-tests.md — AC-005 covers only Context-absent generation
     (F1/F2); AC-007 covers only Context-present-required (F4)
     Facet-reference-absence. The Observable×fixture-state judgment
     table nonetheless marks F3's "Generated-artifact structure"
     observable as `structural`, asserting a comparison exists with no
     criterion defining what it actually checks.

  **Orchestrator verification**: independently confirmed. AC-010
  (requirements.md:365-370) and AC-025 (requirements.md:472-480) are
  exactly the quality-gate-outcome/TEST-019 assertion criteria; AC-034
  (requirements.md:569) only defines the manifest schema. A full search
  of requirements.md and acceptance-tests.md for any F3/REQ-002-advisory
  criterion returned nothing — the gap is real, not a citation error.

## Proposed Changes

**Sub-finding 1 and 2's citation half (both fully within design.md,
applied this round):**

1. Correct the F4/REQ-002 Compatibility Matrix cell: remove the
   erroneous "Epic A1 **and**" clause so the cell reads
   `SKIP-with-activation → AC-007 (until Epic A4 merges)`, matching
   requirements.md's AC-007 text and design.md's own manifest example.
2. Correct the F3/REQ-003 and F4/REQ-003 Compatibility Matrix cells'
   citation from `AC-034's F3/F4 entry` to `AC-010, AC-025`.

**Sub-finding 2's gap half — NOT applied this round, boundary conflict
flagged for a decision:**

Closing the F3/REQ-002 verification-path gap requires **adding** a new
acceptance criterion (and its mirrored `acceptance-tests.md` TEST row)
for the Context-present-advisory structural assertion — an edit to
`requirements.md`/`acceptance-tests.md`, both already
`Spec-Review-Status: Passed`.

`plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md`'s own
Boundaries section states: *"Never write to `specs/<feature>/
requirements.md` or `specs/<feature>/tasks.md`."* This is an
unconditional prohibition on this loop's orchestrator, not one this
task's own delegated remedy authority ("findings が出たら spec を修正して再
attempt") overrides — that delegation was for `design.md`, the artifact
this review gate actually reviews, not for reaching back into an
already-passed, different review gate's own artifact.

This finding is left unresolved for round 2. The orchestrator applies
only the two fully in-scope design.md-only fixes above and stops before
invoking round 3, to get a decision on how to proceed given the
boundary conflict (see the orchestrator's own status report to the
coordinator for the specific options under consideration).

## Next Steps

Apply the two design.md-only fixes above with `--edit-summary`. Do not
invoke round 3 yet — the remaining VERIFICATION-PATH-CONCRETE gap
component cannot be closed within this loop's own write authority, and
proceeding to round 3 without addressing it would either waste the
attempt's final round on a guaranteed-repeat finding or require an
undelegated boundary crossing. Escalated for a decision before
continuing.
