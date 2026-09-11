# Specification Review Report: epic-136-phase4-docs

- Attempt: 3
- Round: 2
- Input hashes: requirements `a40f30c7431397e7ec5ace116fbce8480de4712013c17c6ef2a02373610046ff`, acceptance tests `e2b40c38cf9a0550370f7dbb3ddec43ca93b976f91d157fd195edb7751b1ca29`
- Reviewer A: run/session `01a07cb8-0e4b-74d1-b510-b38d3488bf04`; exact input manifest: spec-review-contract.json#/reviewers/0/allowed_input_manifest.
- Reviewer B: run/session `01a07cbd-e7fe-7a80-b5c9-434b95741ecc`; exact input manifest: spec-review-contract.json#/reviewers/1/allowed_input_manifest.
- Verdict: `NEEDS_WORK`
- Warning count: 0

## Integrated Summary

| Reviewer | Check | Severity |
|---|---|---|
| A | CONSTRAINTS-EXPLICIT | Major |
| B | ASSUMPTIONS-RESOLVABLE | Major |

Each reviewer returned BLOCKED: BL-005 requires current protected-target verification, but the allowed package lacks a complete current comparison and source fingerprint. Both independently identify the same evidence gap. Each has five PASS, one FAIL and one DOMAIN-CONFORMANCE SKIP. Critical 0, Major 2, Minor 0 are failed-check counts, not two distinct bugs.

The deterministic integration rule at spec-review-precheck.sh:313-327 derives NEEDS_WORK for Major findings in round 2, including reviewer BLOCKED outputs. This distinction preserves both original verdicts and is not a waiver or approval.

Read-only validation 447370 verified exact schemas, identities, manifests, current input hashes, ordered checks, distinct sessions, and the A-derived sanitized summary before this contract was written. A and B used actual completed native host turns and reserved sequences 964/965; no result was inferred from a wait timeout.

## Transition

Retain Spec-Review-Status: Pending. No implementation or merge is authorized by this round. The proposed remedy is an authorized hash-pinned investigation record containing the complete current target comparison, followed by an amended requirements clarification identifying who performs the current-state collection and what the isolated reviewer verifies. Preserve the isolation allowlist and protection rules.

An orchestrator read-only Node collection command was rejected by the current PreToolUse hook; no hash or computed comparison was obtained, and no alternate execution was attempted. Resolve that collection boundary before consuming its results. No additional review was launched from this unresolved evidence state.
