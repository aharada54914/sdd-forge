# Repo defect: spec-reviewer-a/b role files mandate 7 checks; spec-review-precheck.sh hardcodes 6

Status: candidate (not a formal WFI — `docs/workflow-improvements/**` is out
of scope for this orchestrator's task; filed here as evidence for a future
`workflow-retrospective` to triage). Same species as
`reports/notes/repo-defect-spec-review-precheck-reset-hash-staleness.md`
(commit `6228f51`) -- a review-loop gate script whose own hardcoded
assumption has drifted from the role files it's supposed to validate.

## This is a recurrence of a previously-documented trap

`~/.claude/projects/-Users-jrmag-Setup/memory/sdd-forge-spec-review-loop-mechanics.md`
(this repository author's own cross-session memory, 罠4, discovered
2026-07-22 at `epic-192-a4-facet-manifest`) already documents this exact
contradiction: `plugins/sdd-review-loop/agents/spec-reviewer-a.md`/
`spec-reviewer-b.md` define a 7th check ID, `DOMAIN-CONFORMANCE` (Major,
SKIP allowed, applies only when `domain/` exists), but
`spec-review-precheck.sh`'s `validate_reviewer_output` hardcodes exactly 6
`expected_ids` for each role and does not include it. That note's own
recorded resolution was: "instruct reviewers to omit `DOMAIN-CONFORMANCE`
entirely when `domain/` is absent, matching the `sdd-domain` feature's own
precedent" -- a workaround that only holds if the reviewer complies with an
instruction that contradicts its own role file.

## New evidence this session (epic-195-a7-compatibility, attempt-2/round-2)

This orchestrator gave spec-reviewer-a exactly that 罠4-style instruction
(omit `DOMAIN-CONFORMANCE`, return 6 checks) in its round-2 launch prompt.
The reviewer **explicitly refused**, per the coordinator's relay of its
final output: it held that its own role file "mandates a fixed 7-check
order [and] SKIP is a legitimate result," that omission "is a schema
change, not a re-serialization," and cited the fact that this was the
**second** such request (the launch prompt's own Authority note plus this
specific instruction) as part of why it declined further compliance. It
returned the full 7-check version (`REQ-TESTABILITY, GOAL-AC-TRACE,
AC-OBSERVABLE, SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT,
RISK-VALIDATION-SURFACE, DOMAIN-CONFORMANCE`, the last one `SKIP`/Major,
finding citing `domain/`'s absence) as its authoritative output instead.

This orchestrator did not attempt further persuasion (the refusal is a
legitimate injection-defense posture: an orchestrator instruction that
contradicts the reviewer's own authoritative role file should not be
followed just because it is repeated). The reviewer's re-reading its own
role file and declining to deviate from it is the correct behavior; the
defect is that this orchestrator's own launch-prompt instruction (itself
following the OLDER, already-recorded 罠4 workaround) was wrong to give in
the first place, once the role file's own text is read as the sole
authority (which this orchestrator's own launch prompts explicitly told
every reviewer to treat it as).

Byte-verified reviewer-a output (independently hash-checked before being
persisted, not trusted from the relay alone):
`reports/spec-review/epic-195-a7-compatibility/attempt-2/round-2/reviewer-a.json`,
sha256 `fc12136004aba0f9bea44cdc2e3857f3207a583afedac3d5de4701f17e40090b`.
`verdict: PASS` (correctly computed by the fixed formula -- `SKIP` is not
`FAIL`, so 7 checks with one `SKIP` and zero `FAIL` still yields `PASS`).

## Mechanical confirmation performed before deciding how to persist this evidence

Rather than guess whether accepting the 7-check version would later break
some other automated validator, this orchestrator read the actual scripts:

1. **`spec-review-precheck.sh`'s `validate_reviewer_output`** (hardcoded 6
   `expected_ids`, no `DOMAIN-CONFORMANCE`) is called ONLY from within
   `validate_contract` (lines 167-168), which is itself invoked only at
   `round > 1`'s own prior-round check (line 201) or a `--reset`'s
   previous-attempt-terminal check (line 217). Neither fires against THIS
   round's (attempt-2/round-2) own evidence unless a hypothetical round 3
   of this attempt, or a hypothetical future `--reset` to attempt 3, later
   needs to validate round 2 as a prior/terminal round. **If round 2 ends
   clean (both reviewers PASS), this orchestrator writes
   `Spec-Review-Status: Passed` directly per SKILL.md's own instruction,
   with no further `spec-review-precheck.sh` invocation needed for this
   attempt at all** -- so the immediate transition is not blocked by the
   6-ID hardcoding.
2. **`check-workflow-state.sh`** (the script `impl-review-precheck.sh` and
   `task-review-precheck.sh` both auto-invoke on every future precheck,
   `plugins/sdd-review-loop/scripts/impl-review-precheck.sh:269`) --
   read in full for its spec-stage reviewer-a/summary cross-check (around
   line 487-489): it requires `[$a.checks[] | .id] | sort` to equal
   `[$summary[0].reviewer_a_checks[] | .id] | sort` -- a **self-consistency
   check between `reviewer-a.json` and `integrated-summary.json`**, not a
   hardcoded expected-ID list. No `length == 6` or literal 6-item ID array
   exists anywhere in this script for the spec stage (confirmed by direct
   `grep`). **The 7-check version passes this validator cleanly, as long as
   `integrated-summary.json`'s own `reviewer_a_checks` mirrors the same 7
   IDs** -- which this orchestrator built it to do
   (`reports/spec-review/epic-195-a7-compatibility/attempt-2/round-2/integrated-summary.json`).

**Conclusion:** the 7-check version is safe to persist as this round's
authoritative evidence for every validator that will actually run against
it going forward (including the auto-invoked `check-workflow-state.sh` a
future `impl-review-precheck.sh` round will call). The only latent risk is
`spec-review-precheck.sh`'s own `validate_reviewer_output`, and only if a
hypothetical future round 3 or attempt-3 reset ever needs to validate round
2 as a prior/terminal contract -- structurally the same class of "landmine
that only bites a future round" as the reset-hash-staleness defect, not an
immediate blocker.

## Recommended fix directions (not applied — `plugins/**` is out of scope
here; same human-judgment-gate treatment as the reset-hash-staleness
candidate)

Two independent real epics now (`epic-192-a4-facet-manifest`, per 罠4;
`epic-195-a7-compatibility`, this note) have hit the same role-file/script
drift, and this time a reviewer's own correct refusal surfaced it as an
actual blocked workaround rather than a silent, papered-over gap. Two
directions, either of which resolves the drift (a human/maintainer
decision, not this orchestrator's to make unilaterally):

1. **Extend `spec-review-precheck.sh`'s `expected_ids` to 7**, adding
   `DOMAIN-CONFORMANCE` to both roles' lists -- treats the role files (which
   both explicitly and elaborately define this check's own conditional
   logic) as authoritative, and is consistent with this session's own
   "worktree role file is the sole authority" instruction to every
   reviewer.
2. **Revert the role files to 6 checks**, removing `DOMAIN-CONFORMANCE`
   entirely (or making it genuinely optional / only present when `domain/`
   exists, rather than "always present, SKIP when absent") -- treats the
   script's hardcoded list as authoritative and the `DOMAIN-CONFORMANCE`
   addition to the role files as the actual drift to undo.

Whichever direction, `check-workflow-state.sh`'s own self-consistency-only
design (option, not requiring a change) already tolerates either shape
gracefully -- only `spec-review-precheck.sh`'s hardcoded list needs to move.

## Impact on this session

Recorded honestly; reviewer-a's own output is persisted verbatim and
unmodified/untruncated (no re-serialization, no dropped check) at
`reports/spec-review/epic-195-a7-compatibility/attempt-2/round-2/reviewer-a.json`.
`integrated-summary.json` for the same round mirrors all 7 checks so the
one validator that will actually run against this evidence
(`check-workflow-state.sh`, via any future `impl-review-precheck.sh`
round) stays self-consistent. Reviewer-b's own round-2 launch prompt is
built by reading `spec-reviewer-b.md`'s own "Output Format" section
directly and quoting only its actual text (7-check order, ending
`DOMAIN-CONFORMANCE`), never instructing it to omit anything.

## Update (2026-07-23): the predicted latent risk is now confirmed real, blocking round 3

The "Mechanical confirmation" section above predicted this would only
matter "for a hypothetical future round 3 or attempt-3 reset." Round 3
became real the same session: `spec-review-precheck.sh
epic-195-a7-compatibility 2 3 --edit-summary="..."` was run against the
live, remedied spec (AC-034 enumeration fix, commit `556034c`) and
**fails**, before creating any round-3 directory (`ERROR:
spec-review-precheck: prior round contract is malformed or does not
require work`).

Root cause precisely isolated (not assumed): `validate_contract` (called
at `round > 1`, line 201) calls `validate_reviewer_output` on round 2's
own `reviewer-a.json`, comparing `[.checks[].id] | join(",")` against the
hardcoded 6-ID `expected_ids` string. Round 2's actual value is
`REQ-TESTABILITY,GOAL-AC-TRACE,AC-OBSERVABLE,SCOPE-BOUNDARY,
CONSTRAINTS-EXPLICIT,RISK-VALIDATION-SURFACE,DOMAIN-CONFORMANCE` (7 IDs);
the hardcoded expectation has only the first 6 — exact-string-equality
fails. This is a **different root cause** from attempt-2/round-1's
reset-hash-staleness defect (round 2 never used `--reset`, and its own
`requirements_sha256`/`acceptance_sha256` are internally consistent
throughout) — same failure message, same general "review-loop gate script
drift" class, distinct mechanism.

**This orchestrator did not self-authorize a second manual-precheck
fallback for round 3.** The human's own 2026-07-22 authorization (recorded
verbatim in `reports/spec-review/epic-195-a7-compatibility/attempt-2/round-2/manual-precheck-note.md`)
was explicit and narrow: *"this manual-precheck deviation for
epic-195-a7-compatibility attempt-2/round-2 only -- not a standing
exemption from issue #61."* Round 3 is a different round, blocked by a
different defect; extending that authorization to cover it without asking
again would be exactly the "generalize one approval to later actions"
pattern this orchestrator's own operating rules prohibit. Escalated to the
coordinator/human for a fresh decision rather than proceeding.
