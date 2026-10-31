# A19 native delivery completed; review is not admitted

Observed 2026-10-06. This is a launch audit, not a specification verdict.

- Applied recovery helper SHA-256: `0461760864371ed8995de5caa6631117ed674b2a7a16ab5988af11e54e26a6de`.
- Applied-helper inventory regression: five cases passed; normal A19 round-1 precheck exited 0.
- One reservation consumed sequence 1206, run/session `da097895-8e92-4519-bf20-fc4b5f29ac5c`, record `0599e72ba9a2382aad1b7540bfbc7f45b3424abaefc010fb686933e4d9964a95`.
- One Claude Sonnet native first turn completed, CLI exit 0 and transport `DELIVERY_OK`. See `reviewer-a-delivery-proof.json`; this proves delivery/identity, not full reviewer admission.
- Native tool observations include all five admitted input reads, including continuation reads for long requirements/investigation, and their file hashes.
- The raw wrapper's REQ-TESTABILITY finding explicitly says the reviewer did not recompute the receipt record hash because record text was not supplied. Native tool observations contain neither a boundary-document read nor a record-text hashing command.

`plugins/sdd-review-loop/references/review-context-boundary.md` requires receipt-chain recomputation from the invocation fields, including the ordered `allowed-inputs-v1` digest for new spec reservations. Raw record text does not need to be supplied separately: it is derivable. The role requires this check and must fail closed when it cannot perform it. A returned PASS cannot replace the missing computation.

The raw model output remains only in `reviewer-a-cli-wrapper.json`. No `reviewer-a.json`, integrated verdict, reviewer-B launch, status change, commit, push or merge was produced. Sequence 1206 is consumed and must not be reused; do not resume this reviewer to repair admission.

## Bounded next repair

The fixed prompt in `validate-nontty-spec-launch.py:78` refers to the canonical contract without delivering its hash recipe or explicitly permitting its control-document read. The caller additionally preauthorizes only file-hash Bash patterns, not the role's narrowly permitted no-newline record-text hash operation. No such operation was attempted, so its runtime rejection is unproven.

Before another reservation, reconcile the fixed prompt/control-input contract and narrow hash-command permission. Make an unreserved native diagnostic prove the complete receipt computation, input hashing and denial on a modified receipt. Keep the existing role, ordinary hooks, immutable history and no-write boundaries. Do not broaden to arbitrary shell execution or treat caller-side recomputation as reviewer-side proof. Any protected launch-contract change requires its sanctioned application and regression/independent review before a new admitted attempt.
