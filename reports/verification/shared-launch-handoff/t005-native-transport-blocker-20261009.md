# T-005 native transport blocker

Owner: shared-review-launch-integration/sdd-forge
Observed HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807

No implementation, approval, verdict, task status or ledger change is made by this record. Existing dirty files and historical evidence remain intact.

## Observed boundary

T-005 attempt 6 local regressions are recorded separately; they do not prove native admission or formal quality evaluation. The next unreserved native diagnostic used invocation `reports/review-context/shared-launch-T005-quality-017c10b4-2937-4075-ad93-727610cca773.json`. Its `reports/quality-gate/launch-017c10b4-2937-4075-ad93-727610cca773/native.jsonl` records diagnostic session `4fc00e9f-191c-4f49-a1be-4c2814499c87` and `reservation: not performed`.

The diagnostic timed out at 300 seconds while reproducing a 640-input hash command. The successful command result was persisted/truncated at approximately 81.2 KB; the transport expects the complete ordered hash output. Extending the timeout alone does not resolve the output contract. No formal verdict or CI success is inferred from this diagnostic.

## Contract boundary

`specs/shared-review-launch-repair/tasks.md`, T-005 Done When, explicitly says: "Re-run T-001 launch/permission regressions after shared-file edits; do not change its CLI/permission contract." T-001 is already Done. The current approved task order is T-001 -> T-005 -> T-002 -> T-003 -> T-004. A transport repair must not silently be implemented as T-005 or rewrite the prior T-001 PASS.

## Proposed bounded repair — not implemented

Use one hash-pinned read-only verification command shared by diagnostic and formal launch, instead of requiring the model to regenerate the full path/hash command and its full output. Preserve verification of every ordered input, required dependencies, allowed paths, invocation and receipt bindings. Return compact count/digest evidence; do not treat model claims as verification. Test missing, modified, duplicate, reordered and out-of-scope inputs, compound commands, and helper mutation. Preserve exact permissions and pre-reservation ledger immutability.

This changes the T-001 command/output contract and requires an explicitly scoped repair authorization and independent formal verification. It is not authorization to implement the subsequent four-point architecture early, relax required checks, reinstall anything, or alter frozen evidence.

## Resume

After that scoped contract decision, create the bounded repair ticket, establish failing regression evidence, implement and independently verify the shared transport, then rerun native admission and T-005 quality evaluation. Continue remaining approved tasks and exact-head CI before merge. The four-point architecture remains sequenced after that merge.
