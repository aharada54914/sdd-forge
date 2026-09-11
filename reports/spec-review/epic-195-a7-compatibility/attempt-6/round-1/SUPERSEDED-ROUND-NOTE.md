# This round replaced an earlier attempt-6 round-1. Read this first.

An earlier spec-review attempt 6 round 1 ran on 2026-08-25 and is **not** the
review recorded in this directory. It is preserved in git, not lost:

- `346ae974` — the original round-1 artifacts and both reviewers' verdicts
- `404d0390` — the same artifacts rebuilt to the precheck validator's exact
  schemas, plus the analysis of why round 2 could not open

Recover it with:

    git show 346ae974 --stat
    git restore --source=404d0390 -- reports/spec-review/epic-195-a7-compatibility/attempt-6/round-1

## Why it was replaced

The earlier round was procedurally malformed in one specific way: reviewer B
was reserved against reviewer A's five inputs and blinded through its prompt
instead of through this round's `integrated-summary.json`. That artifact is
not documentation of the blinding — it **is** the blinding. Pinning it in B's
manifest is what makes blindness a verifiable property of the sealed evidence:
a later auditor can read B's input set and confirm it contained A's counts and
check ids and no finding text. An auditor cannot see a prompt at all.

`spec-review-precheck.sh`'s `validate_contract` enforces this — reviewer B's
pinned set must equal reviewer A's plus this round's `integrated-summary.json`.
Replicating that comparison showed reviewer A matching `expected_a` exactly and
reviewer B missing exactly that one path, with no extra.

## Why the round could not simply be repaired

Every forward route was sealed by a different rule, each quoted from
`plugins/sdd-review-loop/scripts/spec-review-precheck.sh`:

- Re-reserving reviewer B into the sealed round with the correct input set is
  refused by `validate-review-context-set.sh`:
  `REVIEW_CONTEXT_ROUND: manifest freezes specs/epic-195-a7-compatibility/requirements.md
  at a hash this round's precheck did not pin: the document changed mid-round`.
  Round 1 is sealed against pre-amendment bytes, and `requirements.md` was
  amended as round 1's own remedy.
- Round 2 requires the prior round's contract to validate (`:339-340`), which
  it cannot for the manifest reason above.
- Round 3, the only route to a terminal `BLOCKED`, requires round 2 first.
- Attempt 7 requires attempt 6 to hold a terminal `PASS` or `BLOCKED` contract
  (`:354`); attempt 6 round 1 was `NEEDS_WORK`, which is neither.
- Resetting attempt 6 in place requires the round destination not to exist
  (`:138`, "replay is forbidden").

## The defect this exposes, stated as a defect

The spec-review state machine admits a state from which **no legal transition
reaches a terminal contract**. A `NEEDS_WORK` attempt whose round-1 contract
cannot validate has no path to `PASS` and no path to `BLOCKED`, and the only
recovery available is a reset that replaces the very artifacts documenting how
the state was reached. That recovery trades evidence legibility for liveness,
which is the wrong trade to have to make. Recorded here rather than treated as
a quirk that was routed around.

## What this round reviews

The remedies committed in `c50c8028`, none of which any reviewer has yet seen:
the eleven-site scope authorization recorded as its own investigation.md entry,
and `AC-026`'s ordering defect tracked in `requirements.md` as `OQ-004 (open)`
and as a `High` entry in the Risks register.
