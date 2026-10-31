# Quality Gate — T-008 check-domain-conformance script and quality-gate wiring

Task ID: T-008
Feature: sdd-domain
Risk: medium
Required Workflow: acceptance-first
Gate run: 2026-07-07 (second cycle; first cycle 2026-07-06 ended BLOCKED, see reports/quality-gate/T-008.md)

VERDICT: PASS

> Re-run after both first-cycle blockers were resolved with recorded human
> decisions: RT-20260706-001 (check-placeholders case-sensitivity fix, applied
> by the human via the scratchpad->cp procedure), RT-20260706-002 (jq 1.7.1 +
> MSYS-safe shim installed, sha256-verified), and RT-20260707-001 (sdd-domain
> task-review provenance grandfathered in specs/workflow-state-registry.json +
> contracts/workflow-state-registry.schema.json per human decision).

## Scripted gates (Step 6, in SKILL.md order — all fresh runs 2026-07-07)

| Gate | Result | Evidence |
| --- | --- | --- |
| check-risk | PASS | "Risk check passed for task T-008." |
| check-placeholders (4 changed files) | PASS | specs/sdd-domain/verification/T-008.placeholder-scan.log |
| check-design-system | SKIP | no `design-system/` directory in this repo |
| check-domain-conformance | SKIP | no top-level `domain/` directory in this repo |
| check-workflow-state (no --feature) | PASS | specs/sdd-domain/verification/T-008.workflow-state.log ("workflow-state: ok") |
| check-task-state | PASS | "Task state check passed for 11 task(s)." |
| check-contract | PASS | "Verification contract passed for task T-008." |
| check-traceability | PASS | "Traceability check passed for sdd-domain: 11 link(s)." |

Contract: specs/sdd-domain/verification/T-008.contract.json — unit-tests
(10/10 Pester), acceptance-tests (same suite), regression (258/258), and
placeholder-scan all passes:true with fresh evidence logs; lint/typecheck/
build/others waived with reasons (shell stack).

## Independent critical review (Step 8)

Isolated sdd-evaluator, launched only after atomic identity reservation:

- Manifest: reports/review-context/pending-T-008-evaluator-manifest.json
  (review-context-invocation/v2, 12 allowed inputs, all hashes verified)
- Reservation: validate-review-context-set.sh --reserve -> REVIEW_CONTEXT_OK
  record_hash 987179843e4731364495ba3e9c12d2b06cfba9f4633d595391f22c5ec926bf75,
  ledger sequence 26
- run_id: RUN-20260707T0556Z-sdd-evaluator-T-008
- host_session_id: SESS-quality-sdd-domain-T-008

Evaluator verdict: **PASS**. Evidence it verified first-hand (not report
claims): re-ran the Pester suite (10/10), executed both script twins against
its own constructed fixtures covering all six Done-When scenarios plus
bad-invocation/no-args/missing-contract/reversed-relation edges (exact
claimed outputs and exit codes observed), confirmed .sh/.ps1 behavioral
parity on identical fixtures, verified the quality-gate SKILL.md wiring
bullet (lines 54-63) against real behavior and its Step 6 ordering, and
probed the .sh `eval` with shell metacharacters in `Bounded-Context:`
(no injection; value handled as data).

## Findings classification (Step 9)

1. [Minor] Manifest `identity_ledger_sha256` no longer matches the on-disk
   ledger after reservation — **Rejected (works as designed)**: the manifest
   binds the PRE-reservation ledger hash; the --reserve step itself appends
   record 26, so the post-launch whole-file hash necessarily differs. The
   per-record hash chain (a277a566... -> 987179843...) proves the
   reservation; validate-review-context-set verified the bound hash before
   appending. No action.
2. [Minor] .ps1 twin omits the source line number in Check-2 finding text
   while .sh includes it (parity gap in message prefix only; counts, verbs,
   exit codes identical) — **Deferred** to RT-20260707-002 (gate-script edit;
   outside this gate's authority to modify).
3. [Minor] No Pester scenario covers Check-2 (term marker) or Check-3
   (missing aggregate card) paths; evaluator verified both behave correctly
   by direct execution — **Deferred** to RT-20260707-002 (test addition).
4. [Minor] The `[[term:Name]]` heading-marker convention is introduced by the
   implementation and not defined in any spec; opt-in, no false positives
   against current artifacts, explicitly flagged in the implementation
   report per design.md OQ-001 — **Deferred** to RT-20260707-002 (human
   confirmation of the convention when `domain/` adoption begins).

No Critical or Major findings. No unresolved blocking item remains.

## Evidence bundle

Generated with generate-evidence-bundle (never hand-authored) and validated
with check-evidence-bundle; see
specs/sdd-domain/verification/T-008.evidence.json. Medium risk: spec_revision/
build_env/review_verdict and HMAC signature are not required at this tier.

## Done Decision

All Done Decision conditions met: check-risk, check-contract,
check-traceability, and check-evidence-bundle pass; acceptance criteria
(AC-009, AC-015) have tests (plus evaluator-executed coverage of the two
untested paths, deferred as a test-addition ticket); no unresolved
Critical/Major finding; no UI surface; contract and implementation agree;
traceability current; every earlier cannot-verify item is resolved by
evidence or a resolved review ticket. Task set to **Done**.

[INFO] retrospective deferred: approved task(s) still pending Done (T-002,
T-009, T-010, T-011 and others not yet Done; workflow-retrospective will run
when every approved task in sdd-domain reaches Done).
