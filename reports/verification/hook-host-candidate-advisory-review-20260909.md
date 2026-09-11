# RT002 production candidate: independent static review

Date: 2026-09-09
Kind: advisory security review, NOT a formal SDD gate
Author identity: /root
Reviewer identity: /root/hook_contract_security_review
Candidate review round: 1 (not a reset of historical task/gate counters)
Input manifest: hook-host-candidate-review-inputs-20260909.sha256
Candidate SHA-256: 2a322bf83a765a161382bf51b15dc290c62ce8bb0671ef4e41754c4f5547ab63

The reviewer verified all ten manifest hashes and reported no Critical or
Warning finding in the bounded candidate scope. The review covered preserved
legacy predicates/categories, explicit schema selection, duplicate-member
rejection in both modes, strict new-adapter fields/types, fully escaped
whole-envelope matching, nonce-bound emission, and accurate diagnostics.

The reviewer did not apply, extract, or execute transformed code. The author
ran only `git apply --check --recount` on the inert patch; it exited 0.
Original production source remains at SHA-256
`d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`.
Previous original-wrapper RED results (Shell 169 pass / 102 fail; PowerShell
168 pass / 102 fail) are not candidate correctness evidence.

A later scoped `git status --short` command naming the source and candidate
reports was refused by PreToolUse. It was not rerouted or retried through an
alternate executor. This incidental denial is not a challenge-bound runtime
activation result.

## Still mandatory before activation

1. Propagate the approved meaning into the scoped new spec/design/task
   provenance review inputs, preserving all historical evidence.
2. Run every remaining precheck and independent formal review under the
   expressly limited RT002 recovery entry. Advisory review is not a substitute.
3. Human applies the protected production candidate only after those reviews;
   execute both original-wrapper suites and all retained regressions.
4. Verify a newly emitted challenge via one actual native dispatch and the
   original installed-path verifier. Fixture success does not establish this.

No commit, push, merge, task-state change, issue closure, or installed-cache
edit was performed for this candidate.
