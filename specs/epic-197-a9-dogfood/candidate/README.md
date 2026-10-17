# A9 candidate operator entry points

This directory is a reviewable candidate. It is not the live Context or evidence
of approval, promotion, a release observation, or a completed rollback rehearsal.

For a future approved `required` → `advisory` rollback, use the
[bound rollback admission and application procedure](../../../../docs/adr/0035-a9-bound-rollback-admission.md).
Its default mode validates the actual supplied HMAC approval and Ed25519 receipt
without applying them. The explicit `--apply` route invokes the existing safe
publisher only after admission. A separately signed applied attestation and
current-file verification are required for the signed rehearsal result.
