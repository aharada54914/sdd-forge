# A9 candidate operator entry points

This directory is a reviewable candidate. It is not the live Context or evidence
of approval, promotion, a release observation, or a completed rollback rehearsal.

For a future approved `required` → `advisory` rollback, use the
[bound rollback admission and application procedure](../../../../docs/adr/0035-a9-bound-rollback-admission.md).
Its default mode validates the actual supplied HMAC approval and Ed25519 receipt
without applying them. The explicit `--apply` route invokes the existing safe
publisher only after admission. A separately signed applied attestation and
current-file verification are required for the signed rehearsal result.

For Phase-2 promotion, the [bound admission contract](../verification/promotion-admission-contract.md)
connects the release preflight, original findings and WFI artifacts, three-OS
compatibility, signed live-host proof, and a completed signed rollback rehearsal
to the real Phase-2 HMAC approval and an operator-signed decision.
`scripts/validate-a9-promotion.py` validates by default; its explicit `--apply`
route rechecks the evidence before using the existing three-file publisher.
An `ADMISSIBLE` result does not publish, and `APPLIED` does not claim the
subsequent real feature acceptance condition has completed.
