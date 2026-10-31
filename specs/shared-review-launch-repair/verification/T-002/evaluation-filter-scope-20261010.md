# T-002 evaluator input correction

Owner: shared-review-launch-integration/sdd-forge; HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807.
Risk: high (review input boundary). Existing 111 dirty entries are retained.
Scope: caller-owned input preparation only. The rejected, unreserved manifest
is retained unchanged. Verify every old entry, then exclude only raw reviewer
reports already forbidden by the canonical validator. No source validator,
approval, lifecycle, historical evidence or ledger changes are authorized here.

Contracts: review-context-invocation/v2 and the existing supplemental declaration.
The initial filtered delivery also failed canonical ROUND validation without
reservation: it retained another feature's historical precheck, which the
validator selected as the current round. Exclude the historical
`reports/{spec,impl,task}-review/workflow-state-integrity/` fixture artifacts
from direct evaluator delivery as well. The implementation report explicitly
classifies these as disposable test fixtures, not evaluator evidence. Preserve
the report, its Outputs inventory, all original fixtures and both rejected
deliveries. Keep test source and recorded execution evidence. This delivery is
not a writable regression fixture; it does not claim tests were rerun there.

Validation: filtering positive/negative cases; all old input hashes; new scratch
readback; canonical evaluator delivery preflight without reservation. Only the
normal launcher may subsequently reserve a fresh identity after its diagnostics.
