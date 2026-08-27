Task: Extend lite-gate to consume the Capability Summary and execute Registry-sourced checks
Task ID: T-004
Feature: epic-194-a6-lite-integration
Run ID: RUN-epic-194-a6-lite-integration-qg-T-004-seq0648
Host Session ID: SESS-qg-epic-194-a6-lite-integration-T-004-0648
Ledger Sequence: 648
Allowed-Input Manifest: reports/review-context/pending-epic-194-a6-lite-integration-sdd-evaluator-T-004-seq0648-manifest.json (sha256 50afcf17912f597e0ba4298e45ac0cd3aa1c8c763958d61dcfaef3e895e56ef0)
Attempt: 3 (cycle 3 of 3)
VERDICT: PASS

## Basis, stated plainly

The evaluator returned NEEDS_WORK with one Major and six Minors, and
explicitly flagged the Major as borderline: "If you judge the frozen text
controlling, this collapses to a Minor and the task is otherwise PASS-ready."

I reclassify that Major to Minor. The human adjudicated the specification
question and I record the reasoning rather than the conclusion alone:

- Done-When 5 names "all five new suites" and requires the staged candidate to
  carry "these suites'" CI steps. Five suites are registered in both
  `tests/run-all.{sh,ps1}` and the candidate. The criterion is satisfied as
  written.
- The Registration-Drift Check does pair the run-all append with the
  staged-candidate append, but it is scoped to "each of T-001..T-004's own
  commit A". The sixth suite arrived in a cycle-1 remediation commit, not
  commit A, so that clause does not reach it either.
- The frozen document is therefore silent on a suite added after freezing.
  Reading it to mean more than it says is the drift a freeze exists to
  prevent, so the omission is not a criterion failure.

This is a specification-interpretation call, not an evidence call. Nothing
about the implementation changed to earn it.

## Post-verdict evidence completion

The two steps were nonetheless added to the candidate (commit c93330d4),
because classification and action are different questions. The sixth suite
exists only because cycle 1 found AC-014 and AC-017 had no automated
enforcement, and those two are themselves frozen criteria. The candidate runs
per-suite steps with no aggregate runner, so leaving it unregistered would
have recreated the just-closed defect one location over.

The candidate now carries 12 step entries -- six suites across both runtimes --
and the file records inline why a sixth suite sits alongside a Done-When that
names five, so a later reader does not mistake it for drift. Its declared hash
is refreshed; the epic audit reports zero stale.

## What the evaluator established

Launch integrity was reconstructed, not trusted: the ledger minus its tail
reproduces the bound `identity_ledger_sha256`, all 648 record hashes recompute
with a continuous chain, and the tail matches the emitted
`REVIEW_CONTEXT_OK`. All 35 manifest hashes re-verified, zero mismatches.

All six suites re-run in both runtimes: 37 passed / 0 failed each, 74 combined.

The four SKILL.md semantic inversions were re-run through the genuine suite,
fixtures and simulator with only the target redirected to a mutant. Each trips
exactly its own named assertion -- TEST-026c, TEST-016f, TEST-016g, TEST-030e --
while every simulator-based sibling stays green, reproducing the
deliverable-versus-simulator drift property the coverage was built for. The
evaluator additionally proved TEST-014a and TEST-014b non-vacuous itself, and
confirmed TEST-017 carries a vacuity canary.

The CHANGELOG relocation was checked on both halves. The change: T-004's entry
now sits under `## Unreleased` citing #194, and diffing the commit shows 22
removed against 22 byte-identical added -- a pure relocation. The restraint:
`git blame` over the post-fix v1.11.0 block resolves to 18 commits, every
content-bearing one dated on or before the release cut, and the method was
proven non-vacuous by blaming the pre-fix block, where the moved entry does
appear and is the only one. Moving a correctly-placed entry would have
replaced one false record with another; none was moved.

SKILL.md is byte-identical to HEAD, so all of this coverage was added without
touching behaviour. Its growth from 84 to 134 lines traces to a different
feature's commit, not scope creep here. Outputs: all 24 rows re-hashed, zero
stale. Deterministic gates pass, including check-workflow-state at exit 0 --
the precondition tasks.md set for recording Done.

On AC-017's unreconstructable "immediately before the edit" capture: the
evaluator found the underlying fact verifiable from git anyway -- the lite-gate
skill has never been protected at any commit -- which is stronger than the
report's own claim, and TEST-017 now enforces it continuously.

## The blocker inversion, adjudicated a third time

T-004 is `Implementation Complete` while its blocker T-003 is `Blocked`. All
three cycles reached the same conclusion independently, each reproducing the
full suite in a scratch tree containing only `tests/`, `SKILL.md` and
`guard-invariants.json`. No T-004 suite or the simulator invokes
`check-risk-upgrade` or `lite-spec`. The dependency is serialization for the
shared run-all array and CI staging, not functional. T-004's evidence does not
rest on its blocker.

## Minors carried forward, not blocking

- The ps1 TEST-014b twin throws under StrictMode instead of emitting a clean
  FAIL when the note is deleted (detection preserved, diagnostic lost), and
  `-First 1` means a second contradictory note is caught by the sh twin but
  not the ps1 one.
- traceability.json's evidence arrays still cite the superseded seq0329 PASS.
- tasks.md's Quality-Gate Addendum still asserts that same overturned PASS.
- tasks.md is undeclared in Outputs.
- The relocated CHANGELOG entry says 58 combined assertions; it was 60 at
  authoring and is 74 now.
- The report's Session Handoff still says "re-delegate for cycle 2 of 3".

Each is agent-doable and none affects whether the implementation is correct.

## Decision

Zero Critical, zero Major after the reclassification. Every Done-When item is
satisfied, the deterministic precondition is met, and the coverage that closes
AC-014 and AC-017 now runs in CI.

T-004 -> Done.
