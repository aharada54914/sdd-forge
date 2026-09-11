Feature: epic-194-a6-lite-integration
Tasks: T-001, T-002, T-003
Ruling: OWNER ADJUDICATION — proceed to Done over the OpenAI-only holdouts (Option A)

# Cross-Model Consensus Adjudication (2026-08-28)

## Context

After all three tasks reached independent fresh-context evaluator PASS
(seq 0913/0914/0915, zero Critical / zero unaccepted Major each), the
blind cross-model panel ran two rounds on regenerated sanitized bundles.
Round 2 (bundles `46c0cb72…` / `d6481a72…` / `27f1eaa3…`, all digests
matched under `--expect-digest`):

| Task | Evaluator | Anthropic (claude-fable-5) | OpenAI (gpt-5) | Aggregate |
|---|---|---|---|---|
| T-001 | PASS | PASS (6 Minor) | NEEDS_WORK (0 Major, 2 Minor) | FAIL |
| T-002 | PASS | PASS (4 Minor) | NEEDS_WORK (3 Major) | FAIL |
| T-003 | PASS | PASS (5 Minor) | NEEDS_WORK (2 Major) | FAIL |

Zero Critical across all twelve verdicts of both rounds. The
`check-cross-model` aggregates record `result: FAIL` honestly
(`all_pass: false`, `any_critical: false`). Per the policy, a FAIL
aggregate blocks auto-Done and hands the decision to a human.

## The ruling

The session presented the owner two options: **A** — weight the two deep
mutation-backed evaluator cycles plus the Anthropic all-PASS panel,
adjudicate the OpenAI holdouts as accepted at their assessed dispositions,
and proceed to Done (with T-002's two mechanical items available as
follow-up); **B** — fix the two mechanical T-002 items and run a third
round, noting the T-001/T-003 interpretation items would likely persist.

The owner selected, verbatim: 「a」 (2026-08-28, in direct reply to that
presentation).

## Disposition of each surviving OpenAI finding

1. **T-001 (both findings, Minor severity)** — restatements of the
   `Test-PostCopyHashes`/`FailedTarget` live-state-report defect and its
   missing assertion. Already adjudicated by the owner on 2026-08-28,
   verbatim: 「① T-001: runner の失敗時レポート欠陥はminor」. Recorded as
   an accepted Minor in the seq-0914 pre-gate declaration and the cycle-2
   evaluator PASS. The OpenAI verdict itself held them at Minor severity
   (zero Majors) while voting NEEDS_WORK, which the policy treats as
   vendor discretion; the ruling accepts the findings at their recorded
   Minor disposition.
2. **T-002 Major (unit/acceptance evidence covers only the fragment
   suite)** — a pointer-scope artifact of the 2026-08-28 contract reissue,
   not an implementation defect: all four suites are green at the current
   bytes (98/98 per runtime, re-run independently by the seq-0915
   evaluator and visible in the regression capture). Accepted; a combined
   fresh capture and repoint is sanctioned follow-up hardening.
3. **T-002 Major (regression excerpt "reports two failing suites")** — the
   two suites in the tail are `deterministic-lane-selfcheck` and
   `design-system-contract`, the repository's documented designed-red
   baseline pair, identical in every accepted capture of this campaign.
   Accepted as a baseline-documentation visibility gap in the excerpt
   header, not a failing regression.
4. **T-002 Major (byte-identical comparison normalizes trailing
   newlines)** — technically true of the comparison mechanism (`$(...)`
   command substitution / PowerShell line-join), which predates this
   campaign and passed spec review with the original TDD evidence.
   Accepted as follow-up hardening (compare via files + `cmp` for strict
   byte identity), alongside the evaluator's own runtime-hash-assertion
   hardening Minor.
5. **T-003 Major (ship-time recheck carries no Capability fragment; and
   the defense-in-depth fixture criticism)** — assessed as a spec
   misreading: design.md's REQ-005 contract and the OQ-002 resolution
   specify the Capability-derived signal at INTAKE time, explicitly
   "layered with, not a substitute for" the ship-time keyword recheck,
   which is intentionally unmodified; the Non-goals bullet excludes new
   evaluator machinery. The seq-0913 evaluator verified the layering
   clause-by-clause against the staged text. Accepted at that reading.

## Consequence

The three tasks' `Status` fields in `specs/epic-194-a6-lite-integration/tasks.md`
flip from `Implementation Complete` to `Done` under the existing
sudo-format `Approval: Approved` lines, with this document as the
human-decision record required by the cross-model policy for a FAIL
aggregate. The follow-up hardening items (combined T-002 green capture and
repoint; strict-byte comparison; runtime baseline-hash assertion; staged-
mirror SUT binding for three suites) are recorded for a future chore and
do not gate Done.
