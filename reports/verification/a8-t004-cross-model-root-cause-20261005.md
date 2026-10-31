# A8 T-004 remaining boundary: current-state correction

Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`.
Scope: read-only evidence inspection and this non-frozen addendum. No suite rerun, model call, reservation, contract edit, canonical report promotion or historical rewrite.

## Why check-contract remains false

This is T-004's own unfinished verification, not a failure in the separate cross-model-verification feature. `T-004.contract.json:7,10,22` explicitly declares cross_model required and a required cross-model-verification check with passes=false and empty evidence. The aggregate `T-004.cross-model.json` does not exist. `check-contract.py:368-388` enforces the descriptor in addition to its ordinary required-check/evidence rules. There is no demonstrated implementation defect to repair by changing this check.

Two panel results already exist: Anthropic PASS with four Minor findings and OpenAI PASS with zero findings. Both are blind=true and bind the identical body digest. Fresh read-only recomputation returned:

- Bundle SHA256: `79a74fd5abfe5609b4fd2f6f93bd796dcb57e2629ba0c588ca444b0add8a2ead`.
- Body SHA256 (eight header lines removed): `3dc43bd2241d3e746a9cacdb6de3dcdb331f8d9b507b95c3d294cf1c9cfb181a`.
- Anthropic verdict SHA256: `dbafaa02d07657894b231464665b029fd0f843b1e72d2377606a0ce9e97742d6`.
- OpenAI verdict SHA256: `562852a77fda79db0d570408eeaa2787516f088944f1f89bcc6594cb32a80cf5`.

These observations establish the saved bundle/verdict pairing, not freshness against a future recovery report. The collection note and runtime evidence remain unchanged.

## Important ordering distinction

The saved collection handoff asks for a separately obtained primary evaluator verdict before aggregation. That is not a mandatory argument of the deterministic script: `check-cross-model.sh:197-214` and `cross-model-verification-policy.md:209-218` explicitly make primary divergence comparison conditional on --evaluator. A panel-only aggregate can legitimately have evaluator_verdict=null. Do not invent a primary PASS or treat such an aggregate as primary verification. The ship flow requires same-invocation cross-model collection before quality-gate (`plugins/sdd-ship/skills/ship/SKILL.md:296-322`); old collected files alone do not prove that invocation condition.

Thus the absence of a primary is not a technical impossibility of panel-only aggregation. The coordinator must choose the correct current invocation and input revision, preserve the old collection, and later compare the actual primary result without weakening that requirement. No aggregate was written here because collection handoff and current recovery input adoption are not this bounded investigation's authority to finalize.

## Correction to the earlier continuity summary

`a8-t004-owner-continuity-20261005.md:61-62` referred to non-adopted attempt-5 output but omitted the completion addendum at the TOP of `a8-t004-task-rereview-transport-audit-20261004.md:3-25`. Current attempt-5 round-1 has reviewer B retry3, task-review-contract and integrated-verdict PASS. Contract B identity is `RUN-epic-196-a8-integration-task-a5r1-b-retry3-1791113814` / `f782c743-cf5d-47b9-8bca-ce11c6bd1536`, matching the saved invocation and ledger entry. Earlier failed/non-adopted retries remain historical facts; they are not the current adopted B. This correction does not claim a new formal task review or replay the gate.

## Remaining legitimate primary launch sequence

1. Complete the approved fresh isolated implementation recovery: observed distinct run/session/scratch, pinned current inputs, new noncanonical report and exact task-input-manifest/v1. The old canonical T-004 report currently lacks those fields (`Run ID` is historical); do not retrofit it. Use a new `handoffs/<directory>/manifest.json`, and keep scratch in the report rather than inventing a manifest schema key.
2. Independently compare old archive/new report and hashes, then perform sanctioned canonical adoption. Declare every evaluator-needed source/test/evidence/archive exact path/hash in Outputs (or legitimate cycle-specific Post-Fix Artifacts). The implementation manifest's allowed inputs do not expand evaluator access.
3. Resolve current sanitized panel input revision and same-invocation collection requirements; do not silently reuse a digest for changed inputs. Keep the four Minor findings for primary disposition. Panel-only consensus, if produced, must explicitly retain the missing primary comparison.
4. Coordinator prepares one-role quality invocation with implementation_manifest binding, unique evaluator run/session and feature-wide nonoverlapping scratch. Reverify admitted hashes and reserve only immediately before actual fresh launch. This agent makes no reservation. Evaluator remains read-only; scratch is not canary/write permission.
5. Actual primary verdict plus cross-model comparison, completed contract, evidence bundle and exact integrated-head CI remain separate proof obligations. T-007 registration wording and T-008 native signatures are not discharged by T-004 synthetic tests.

No evidence supports weakening history, deleting cross-model requirements, granting a waiver, or setting Done. The next implementation action is fresh recovery provenance, not repeating unchanged local regression suites.
