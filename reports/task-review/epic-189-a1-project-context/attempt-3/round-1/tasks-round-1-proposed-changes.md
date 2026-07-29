# Task Review Report: epic-189-a1-project-context — Round 1 / Attempt 3 (Post-Implementation Provenance Re-Review, post-WFI-018)

## Verdict: NEEDS_WORK (Major 1 / Critical 0; round 1 of 3)

| Field | Value |
|---|---|
| Reviewer-A (seq0341) | PASS 14/14, findings [] |
| Reviewer-B (seq0342, run-3, accepted) | NEEDS_WORK — DEPENDENCY-OVERLAP Major (T-003); TASK-SIZE / RISK-APPROPRIATE converged to PASS-with-advisory under WFI-018 citing attempt-1/round-2 prior PASS evidence |

## The finding (substantive, NOT covered by the WFI-018 convergence rule — the reviewer itself correctly scoped it as a new cross-artifact inconsistency)

design.md ("HMAC preimage and signing", ~795-813) requires
`generate-approval-sidecar` to resolve the three provenance fields at
signing time, with `weakening_verdict` set to "the EXACT verdict
`detect-policy-weakening` (REQ-006) computes for this transition — the
same invocation this REQ already makes" — i.e. the generator invokes the
detector itself and NEVER accepts an externally-supplied verdict. But
tasks.md T-003's Out of Scope states the opposite ("this task only
ACCEPTS a verdict it is given and embeds it, it does not compute one"),
T-003 has no ordering relationship with the detector task, and no task's
Planned Files owns wiring the invocation into
`generate-approval-sidecar.py` later (T-006 shares REQ-004 but does not
list the generator). Risk: generator ships permanently accepting an
externally-supplied verdict — a security-requirement regression against
REQ-006's anti-tamper design.

## Frozen-artifact reconciliation (why a tasks.md content remedy is sanctioned here)

- STEP 6 (round < 3, Major findings): "Review proposed changes and edit
  specs/<feature>/tasks.md. Then re-invoke with --edit-summary" — the
  state machine's own remedy channel.
- The provenance re-review boundary ("does not license content changes to
  frozen artifacts") bars using RE-BINDING as a pretext for edits; it does
  not disable the review loop's finding-driven remedy channel — otherwise
  a genuine defect found during a provenance re-review would be
  structurally unresolvable, which the SKILL cannot intend. The
  判断7/WFI-018 line bars only TYPE-H re-judgments of byte-identical
  previously-passed content; THIS finding is a genuine contradiction with
  the CURRENT authoritative design (amended through the impl gate after
  task attempt-1), i.e. the frozen text is wrong relative to the document
  it must refine — the exact class the loop's remedy exists for.
  Precedents: impl attempt-3 round-1 remedies to frozen-gate design.md
  (`00ed0918`); task attempt-1 round-1 remedy to tasks.md (`2b72c8d2`).

## Proposed remedy (minimal, design-consistent, cycle-free)

1. **T-003 Out of Scope** — replace the contradicting bullet: T-003 builds
   the generator INCLUDING the provenance-resolution seam design.md
   requires (bootstrap case fully; non-bootstrap transitions call the
   in-process seam which fails CLOSED with a named diagnostic until the
   detector exists; never accepts a caller-supplied verdict); the
   detector's own computation stays out of scope (T-005).
2. **T-005 Planned Files** — add `generate-approval-sidecar.py`
   (existing-by-T-003, edited): completing the seam by wiring
   `detect-policy-weakening` in-process, per design.md.
3. **T-005 Blockers** — `T-002, T-004` → `T-002, T-003, T-004` (T-005 now
   edits a file T-003 creates). Cycle check: edges T-003→T-002,
   T-004→T-003, T-005→{T-002,T-003,T-004} — DAG, no cycle (T-003 gains NO
   new blocker; the naive alternative of blocking T-003 on T-005 would
   cycle via T-004 and is rejected).

T-006 needs no change (its TEST-019 exercises the generator but does not
edit it). traceability.md rows are requirement-level and unaffected.

## Next Steps

Apply the three edits (minimal, explicit-path commit) → round-2 precheck
(`--provenance-rereview`; the round>1 changed-tasks check passes because
the remedy changes the tasks hash) → fresh reservations → both reviewers
→ expected merged PASS.
