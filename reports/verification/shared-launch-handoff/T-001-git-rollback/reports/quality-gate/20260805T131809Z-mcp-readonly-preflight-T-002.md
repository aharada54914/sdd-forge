# Quality Gate Report: T-002 (mcp-readonly-preflight)

Task ID: T-002
Feature: mcp-readonly-preflight

**Persistence note (orchestrator).** The evaluator returned the verdict JSON
below and the orchestrating session wrote it verbatim; no wording, number,
verdict or finding was altered.

```
RUN_ID: RUN-mcp-readonly-preflight-qg-T-002-seq0508
HOST_SESSION_ID: SESS-qg-mcp-readonly-preflight-T-002-0508
ALLOWED_INPUT_MANIFEST: reports/review-context/pending-mcp-readonly-preflight-sdd-evaluator-T-002-seq0508-manifest.json  sha256=08509d900f38c93eeda3ad75b1b6ad6eda4f39b7c30a36d20f82434378f7cdae
VERDICT: NEEDS_WORK
```

- Model: claude-fable-5 (session-inherited by the sdd-evaluator subagent)
- Effort: frontmatter-controlled, record-only (effort_applied=null)

## Evaluator verdict

NEEDS_WORK. One Major (recommended Deferred), four Minor.

1. **Major — Deferred (per the evaluator's own required disposition).**
   Done-When bullets 3-4 demand exercised runtime (TEST-010/TEST-011) and
   differential (TEST-013) ship runs; neither occurred, and the security spec
   calls TEST-012/TEST-013 "the load-bearing pair" retiring the B2 threat
   this feature itself creates (security-spec.md:83,91). The ship-leg runs
   are structurally unexecutable while the candidate is only staged, and
   requirements.md:39 mandates this task's Done-When be expressed in staged
   terms — the bullets conflict with that mandate. Disposition followed
   exactly as the evaluator required: the explicit deferral of
   AC-010/AC-011/AC-013 (ship leg) to post-human-apply verification, naming
   the concrete runs, is recorded in blocking review ticket
   docs/review-tickets/RT-20260805-002.yml so the feature's central security
   control is not silently lost.
2. **Minor — Accepted.** TEST-018 ship-leg grid cell overstates an
   environment observation as an exercised run; the file bounds its own claim
   honestly (verification/T-002/03-dual-runtime-manual-verification.md:41-47).
3. **Minor — Accepted.** The byte-identity diff evidence paraphrases the diff
   body ("(22 inserted lines: ...)") instead of verbatim output; the hunk
   header 53a54,75 is verbatim and the evaluator corroborated it
   independently via five spec-recorded live-file citations each landing
   exactly 22 lines later in the candidate.
4. **Minor — Deferred.** AC-025 conformance rests on ad hoc commands with no
   registered suite case binding candidate to manifest (its model QGCL-015 is
   a registered case); infra-spec.md:14 leaves adding a suite to OQ-009.
5. **Minor — Accepted.** Batch pre-reservation makes the launch validator
   replayable only for the last-reserved identity; the evaluator re-derived
   the pre-reservation ledger hash itself to confirm genuineness. Framework
   observation, shared with T-001's report.

The evaluator's summary confirms first-hand: all 17 manifest hashes verify;
ledger chain clean with its identity exactly once at seq 508; the staged
candidate carries the 3 required elements, all four forbidden-surface
absences, D-001 attempt-and-degrade with no detect-then-branch wording,
unconditionality across all three invocation forms and both tracks, and the
two-element divergence rule; the candidate sha256 recomputed by the evaluator
equals the MANIFEST entry (AC-025 verified-by-evaluator); no completion-
faking — every testable claim was true and open items are disclosed
specifically.

## Gate decision

Done is blocked pending the human-apply handoff: the one Major finding's own
disposition is a deferral that can only be discharged after the human applies
the staged candidate to the live protected path (an action agents cannot
perform by design). Ticket RT-20260805-002.yml carries the post-apply
verification runs. No evaluator cycle can change this before the apply
happens, so per the skill's stop-early rule no further cycle is spent.

**Status: T-002 retains Implementation Complete.**

Retrospective: not invoked (gate did not reach Done).
