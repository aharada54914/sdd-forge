# Specification Review Report: epic-195-a7-compatibility

- Attempt: 2
- Round: 3 (final round of this attempt)
- Input hashes: requirements `be0cd28571cc64784c89d687c5c38b8ccbe14bd7dfab0a5ba4c73c8a26311ac9`, acceptance tests `7b62c3391ddc58131cf1d1a16644e116b3030562e47a15fcd66ee4ef3c8aa24d`
- Precheck: manual fallback per AGENTS.md's "Review gate precheck fallback"
  (issue #61) — see `manual-precheck-note.md` in this directory and
  `reports/notes/candidate-manual-precheck-round3.md`'s "Human
  authorization" section for the full authorization record.
- Reviewer A: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-a-seq0333`, host session `SESS-spec-spec-reviewer-a-epic-195-a7-compatibility-0333`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json (5 files, see `spec-review-contract.json` for hashes)
- Reviewer B: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-b-seq0334`, host session `SESS-spec-spec-reviewer-b-epic-195-a7-compatibility-0334`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json, integrated-summary.json (6 files, see `spec-review-contract.json` for hashes)
- Verdict: `PASS`
- Warning count: `0`

## Integrated Summary

Reviewer A (checks REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE,
SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE,
DOMAIN-CONFORMANCE — 7 checks per its own role file's unconditional
order): 6/7 PASS, 0/7 FAIL, 1/7 SKIP (DOMAIN-CONFORMANCE, `domain/`
absent).

Reviewer B (checks AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE,
ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS,
DOMAIN-CONFORMANCE — 7 checks, same role-file basis): 6/7 PASS, 0/7 FAIL,
1/7 SKIP (DOMAIN-CONFORMANCE). Independently confirmed round 2's own
DOWNSTREAM-READINESS finding resolved: AC-034's updated enumeration was
cross-checked against every one of `acceptance-tests.md`'s 9 rows naming
a "named SKIP" condition — all 9 accounted for, none omitted.

Finding counts (both reviewers combined): 0 Critical, 0 Major, 0 Minor.

`integrated-verdict.json` is derived from both validated reviewer outputs.
With zero Critical/Major/Minor findings from either reviewer, the merged
verdict is `PASS` with `warningCount: 0`, regardless of round number. This
is attempt 2's own final round (round 3); a clean pass here reaches
`Spec-Review-Status: Passed`.

## Full history of this attempt (recorded per orchestrator instruction, for a complete record of how this attempt reached Passed)

**Attempt 1** reached `Spec-Review-Status: Passed` cleanly
(attempt-1/round-2). Subsequently, `impl-review-loop`'s own attempt-1/
round-2 reviewer-b raised a Major finding (VERIFICATION-PATH-CONCRETE):
fixture state F3 (Context-present-advisory) had a `structural` comparison
`design.md`'s own Compatibility Matrix and Observable×fixture-state
judgment table already claimed, but no Acceptance Criterion covered it.
This spec-addendum orchestrator was delegated to resolve it, per this
repository's established addendum route (spec edit → spec-review-loop
re-attempt).

**Attempt 2, round 1**: added AC-042/TEST-042 (F3/REQ-002 structural gap),
mirrored in both requirements.md and acceptance-tests.md (commit
`2ab5d09`). Ran `spec-review-precheck.sh --reset` (commit `ad67b5c`).
**Defect #1 surfaced**: the script computes `requirements_sha256` *before*
its own `--reset` sed mutation (`Passed`→`Pending`), so the persisted
`precheck-result.json` recorded a stale hash that could never equal the
live post-reset file any future round would need to validate against —
documented at
`reports/notes/repo-defect-spec-review-precheck-reset-hash-staleness.md`.
Round 1 verdict: `NEEDS_WORK` (reviewer-b: AMBIGUITY, EDGE-CASE-COVERAGE,
DOWNSTREAM-READINESS, all Major — F5/F6's own analogous REQ-002 gap and an
AC-007 track ambiguity).

**Human decision #1** (2026-07-22): after this orchestrator prepared two
non-applied candidates (A: a script patch, empirically tested and
reverted; B: a manual-precheck fallback per AGENTS.md issue #61) and
escalated rather than self-authorizing either, the human selected option
B, scoped explicitly to that one round only ("Bで今ラウンドを解錠し、A
は後で本体repoへの独立PRとして提出"). Applied in commit `c5de142`.

**Attempt 2, round 2**: remedy for round 1's 3 findings (AC-007 F4
clarification, AC-043 for F5/F6, AC-034 enumeration update — commit
`d1dae1b`). Reviewer A: clean 7-check PASS (its own role file's
unconditional `DOMAIN-CONFORMANCE`-inclusive order); this reviewer
**correctly declined** an earlier launch-prompt instruction (following
this repository's own older, already-documented 罠4 workaround) asking it
to omit that check, citing its own role file as sole authority — a
legitimate refusal this orchestrator did not contest, and which prompted
mechanical confirmation that accepting the 7-check shape was safe for
every validator that would actually run against it
(`reports/notes/repo-defect-spec-reviewer-domain-conformance-check-count-mismatch.md`).
Reviewer B independently confirmed all 3 round-1 findings resolved but
surfaced 1 new Major (DOWNSTREAM-READINESS: AC-034's own enumeration still
omitted AC-036/AC-037). Round 2 verdict: `NEEDS_WORK`.

**Defect #2 surfaced**: attempting round 3's automated precheck failed
with the same symptom as defect #1 but a different, precisely-isolated
mechanism — `validate_reviewer_output`'s hardcoded 6-ID `expected_ids`
rejects round 2's own legitimate 7-check `reviewer-a.json`. Documented as
an update to the same defect note. This orchestrator did **not**
self-extend the round-2 authorization (explicitly scoped to "this round
only, not a standing exemption") to cover a differently-caused block on a
different round, and escalated for a fresh decision, with a ready-to-
approve candidate already prepared
(`reports/notes/candidate-manual-precheck-round3.md`).

**Remedy for round 2's finding**: AC-034's enumeration updated to include
AC-036, AC-037 (commit `556034c`).

**Human decision #2** (2026-07-23): "判断2・5については認可する" ("I
authorize judgments 2 and 5"), with the coordinator identifying "判断2" as
this exact round-3 manual-precheck candidate, scope again explicitly
limited to this round only. Applied in commit `4cf1535f`.

**Round 3, reviewer-a's first launch instance** (seq0333) **declined to
launch entirely** — no substantive file read, no output — citing:
narrative-only (not tool-verifiable) reservation claims; a hash typo plus
inline correction introduced during the coordinator's own prompt-assembly
step (not in this orchestrator's launch-prompt file or reservation
manifest, both correct throughout) that read as a possible
hash-laundering pattern; and general distrust of the manual-fallback
route. **This was a legitimate refusal, not an error to route around.**
Identity `seq0333` was never consumed and remained valid; the coordinator
retried the *same* identity (this repository's own ECONNRESET-class
same-identity-retry precedent) with a corrected launch prompt that has
the reviewer independently self-verify the identity ledger, its own
reservation manifest, and the human-authorization note directly via
`Read`, rather than asking it to trust narrative claims. Recorded in
`reports/notes/candidate-manual-precheck-round3.md`'s "Launch history"
section. The retried instance completed cleanly (PASS, 7 checks). This
same self-verification launch-prompt style was used proactively for
reviewer-b's own round-3 launch and it also passed cleanly without
incident.

**Round 3**: clean PASS from both reviewers, as recorded above. Two
distinct review-loop-script defects were found and worked around (never
patched on the live path, never waived as findings) across this attempt,
each requiring its own, separately-scoped human authorization — this
attempt's own Spec-Review-Status transition reflects real, independently
verified review content throughout; no shortcut was taken on the
substance of any finding.

## Transition

The orchestrator records the validated contract and is the sole writer of
`Spec-Review-Status`. This contract is a clean PASS on this attempt's
final round, so `Spec-Review-Status` is updated from `Pending` to
`Passed` (after confirming `check-workflow-state.sh --feature
epic-195-a7-compatibility` reports green, per instruction).
