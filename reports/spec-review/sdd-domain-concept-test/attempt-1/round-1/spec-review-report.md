# Specification Review Report: sdd-domain-concept-test

- Attempt: 1
- Round: 1
- Input hashes: requirements `fb96814da783fc3eb04b431cea8443f473a5558e56907b5815f4e5d63cb1fc2f`, acceptance tests `91fd0fe4989274bffcf5deed36b4ce29b486a17dae17a2307c39aa82b39dcc2b`
- Reviewer A: run `01a0e3f0-7f9a-7951-bdde-34a7a653f659`, host session `01a0e3f0-7f9a-7951-bdde-34a7a653f659`, allowed input manifest `plugins/sdd-review-loop/references/spec-review-calibration.md` sha256 `537f776558cf4b4a99ee455a974857a67e249242dce5806e23d37d6802f2a385`; `reports/spec-review/sdd-domain-concept-test/attempt-1/round-1/precheck-result.json` sha256 `5dec179131f6184a4a531f75078279d061ff313e01a8824f4579ed297eebebf1`; `specs/sdd-domain-concept-test/acceptance-tests.md` sha256 `91fd0fe4989274bffcf5deed36b4ce29b486a17dae17a2307c39aa82b39dcc2b`; `specs/sdd-domain-concept-test/requirements.md` sha256 `fb96814da783fc3eb04b431cea8443f473a5558e56907b5815f4e5d63cb1fc2f`
- Reviewer B: run `01a0e3f8-bea6-78d3-9ef6-b4e54d53ef14`, host session `01a0e3f8-bea6-78d3-9ef6-b4e54d53ef14`, allowed input manifest `plugins/sdd-review-loop/references/spec-review-calibration.md` sha256 `537f776558cf4b4a99ee455a974857a67e249242dce5806e23d37d6802f2a385`; `reports/spec-review/sdd-domain-concept-test/attempt-1/round-1/integrated-summary.json` sha256 `435754693913d055284fd1e68e87aa1fd586a0aa386e9f73358a663c608adbe4`; `reports/spec-review/sdd-domain-concept-test/attempt-1/round-1/precheck-result.json` sha256 `5dec179131f6184a4a531f75078279d061ff313e01a8824f4579ed297eebebf1`; `specs/sdd-domain-concept-test/acceptance-tests.md` sha256 `91fd0fe4989274bffcf5deed36b4ce29b486a17dae17a2307c39aa82b39dcc2b`; `specs/sdd-domain-concept-test/requirements.md` sha256 `fb96814da783fc3eb04b431cea8443f473a5558e56907b5815f4e5d63cb1fc2f`
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Integrated Summary

Reviewer A: PASS 6, FAIL 0, SKIP 1. Reviewer B: PASS 5, FAIL 1, SKIP 1.
FAIL check: EDGE-CASE-COVERAGE (Major). Critical 0, Major 1, Minor 0.
No raw findings are copied into reviewer inputs.

`integrated-verdict.json` is derived from both validated reviewer outputs. A Critical or Major finding produces `NEEDS_WORK` before round three.

## Transition

The orchestrator records the validated contract and is the sole writer of `Spec-Review-Status`.
Status remains Pending. Historical round-one input hashes are retained. Acceptance coverage repair is reviewed only in a subsequent round; no historical reviewer output is recomputed.
