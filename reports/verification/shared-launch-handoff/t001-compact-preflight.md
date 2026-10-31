# T-001 compact verifier repair preflight

Owner: shared-review-launch-integration/sdd-forge. Baseline HEAD:
`9ce19abe90df0cb83e385f96855e4843318a8807`.
High-risk, explicitly approved T-001 repair; existing dirty launcher work is retained.
No reservation, verdict, approval, lifecycle or Git history changes are authorized here.

The existing oversized model-reemitted commands are replaced with a shared,
source-hash-pinned read-only verifier. Legacy caller behavior remains available.

| Evidence field | Counterpart | Required failing mismatch regression |
|---|---|---|
| invocation digest | invocation bytes | invocation mutation rejected |
| ordered input digest | receipt record and all manifest entries | missing or changed input rejected |
| raw input set digest | launch-time admitted raw hashes | normalized task or any raw input drift rejected |
| boundary digest | boundary bytes | boundary mutation rejected |
| verifier digest | executed source bytes | source mutation rejected before execution |
| receipt record/chain | reconstructed invocation record | receipt mismatch rejected |
| command and output | diagnostic/formal exact-command policy | compound command or altered output rejected |

Parent owns permanent regressions and independent review. This implementation owns
the transport, probe and launcher only. Required validation: syntax, affected
regressions, exact-command guard negative cases, then independent review. Native
formal launch, full CI and merge are not claimed by local fixture success.
