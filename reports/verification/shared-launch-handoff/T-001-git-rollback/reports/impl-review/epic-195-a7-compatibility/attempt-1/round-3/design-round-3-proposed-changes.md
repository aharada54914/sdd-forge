# Implementation Policy Review Report: epic-195-a7-compatibility — Round 3 / Attempt 1

## Verdict: NEEDS_WORK (round-level formula) — Attempt 1 outcome: BLOCKED (round 3, Major finding remains)

| Field | Value |
|---|---|
| Feature | epic-195-a7-compatibility |
| Round | 3 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-07-23T10:11:33Z |

`integrated-verdict.json`'s own `verdict` field reads `NEEDS_WORK`, computed
by `impl-review-loop`'s own SKILL.md STEP 5 formula (`findings_critical ==
0` and `findings_major > 0` → `NEEDS_WORK`), which is round-independent.
Separately, per STEP 6's own state-machine outcome logic ("Round == 3,
Critical or Major findings remain → BLOCKED"), **this is Attempt 1's
terminal outcome: BLOCKED** — round 3 is this attempt's own final round,
and a Major finding survives. `Impl-Review-Status` is left `Pending`
(unchanged) per STEP 6's own BLOCKED branch, which specifies no header
update.

## Reviewer-A Findings (Structural Soundness)

11/11 PASS or SKIP, 0 FAIL. `FRONTEND-BACKEND-CONSISTENCY` SKIP
(non-fullstack feature type). No findings. Reviewer-A independently
evaluated the same F3/REQ-002 cell reviewer-B's own finding below cites
and judged it, via `TEST-STRATEGY-COVERAGE`, as an intentionally-closed
gap — AC-042/AC-043 self-validate against design.md's existing text — not
a coverage defect.

Non-finding transparency note (not a check FAIL, carried into round-3
context for reviewer-B, who reached an independent conclusion on the
adjacent cross-reference question): `design.md:99-104`'s Layer
Specifications prose still asserted "no layer files are produced" while
the four layer spec files exist on disk. Reviewer-A judged this
non-substantive to its own checks.

## Reviewer-B Findings (Implementability/Risk)

10/11 PASS/SKIP, 1 FAIL:

- **NO-REQ-CONTRADICTION (Major, FAIL)** — design.md does not cite
  AC-042 or AC-043 anywhere (zero matches). Specifically: (1) the
  F3/REQ-002 Compatibility Matrix cell (design.md:275) does not follow
  the Disposition legend's own `SKIP-with-activation → <AC-id>` format
  and does not cite AC-042; (2) the F5/F6 rows (design.md:277-278) do
  not cite AC-043; (3) the REQ-007 allowlist-manifest worked JSON example
  (design.md:389-465) has no AC-042 or AC-043 entries; (4) trailing prose
  (design.md:468-475) still describes a future F5/F6 assertion as an
  unauthored "future TEST-0NN" case, despite AC-043/TEST-043 now being
  finalized in the Spec-Review-Status: Passed spec.

Reviewer-A and reviewer-B examined the same underlying facts (design.md's
own text, and the now-finalized AC-042/AC-043) and reached opposite
conclusions through their own distinct check lenses (reviewer-A's
`TEST-STRATEGY-COVERAGE` vs. reviewer-B's `NO-REQ-CONTRADICTION`) — this
is a legitimate, independently-reasoned disagreement grounded in concrete
textual requirements (the Disposition legend's own stated format, and
literally stale prose), not a contradiction requiring reconciliation by
this orchestrator. Both reviewer verdicts stand as recorded.

## Proposed Changes

Per the coordinator's remedy direction (grounded directly in reviewer-B's
own cited evidence, no new design invented):

1. `design.md:275` (F3/REQ-002 cell): cite AC-042 in the Disposition
   legend's own `SKIP-with-activation → <AC-id>` format.
2. `design.md:277-278` (F5/F6 rows): cite AC-043 in the same format.
3. `design.md:389-465` (REQ-007 allowlist-manifest worked JSON example):
   add AC-042/AC-043 entries.
4. `design.md:468-475` (trailing prose): update from "future TEST-0NN"
   to reflect AC-043/TEST-043 as finalized.
5. `design.md:99-104` (Layer Specifications prose, reviewer-A's own
   transparency note, not a finding): update to honestly reflect that
   the four layer spec files now exist, addressing the stale
   inconsistency before it becomes a future finding.

## Next Steps

Apply the proposed changes to design.md. Per SKILL.md STEP 7, `--reset`
is the SKILL's own normal flow for a round-3 BLOCKED outcome (distinct
from a mid-attempt NEEDS_WORK, which would instead re-invoke the same
attempt with `--edit-summary`): archive attempt 1 as-is, start attempt
2/round 1, `Impl-Review-Status` reset to `Pending` by the precheck
script itself. No human escalation required for this transition (per
this repository's own precedent, e.g. Epic A5's task-review self-driving
through an analogous attempt 1 BLOCKED → attempt 2/3 sequence) — this
orchestrator proceeds directly, reserving escalation only for a genuine,
inexplicable script-level failure during the reset itself.
