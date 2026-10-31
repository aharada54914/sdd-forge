# Bounded T-005 signer-role error repair preflight

2026-10-14. Owner a8-release-sync-oct01/sdd-forge; HEAD
495c88d67af44530687ecea3ce9fb0a90a336539. Existing dirty work preserved.
Risk high, existing approved T-005 contract restoration, parent authorization
2026-10-14. No scope or acceptance weakening; no frozen artifact/status edits.

Persisted evidence field: validator diagnostic error code for registered signer
role mismatch. Counterpart: design.md:597,751–754,1226–1229 requires
ERR_SIGNER_ROLE_MISMATCH for operator/reviewer wrong roles; design.md:679 keeps
ERR_SIGNER_UNTRUSTED for issuer-ledger wrong role. Missing signer stays UNTRUSTED.
Failing mismatch tests: change only registered role with identity/key/signature
still valid, four record-slot/wrong-role branches across PASS/FAIL/SKIP. Separate
issuer-ledger wrong-role test must retain UNTRUSTED. Existing 281 cases retained.

Plan: preserve first quality result; add tests first and observe RED; split the
single signer_for condition; run complete Bash and PowerShell suites; fresh
independent review with new hashes. Only validator.py and run_cases.py may change.
No correction to accepted source map, no real signatures, no CI/human-copy writes.
