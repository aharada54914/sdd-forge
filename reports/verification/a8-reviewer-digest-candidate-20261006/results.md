# A8 digest candidate — isolated verification result

Date: 2026-10-06
Owner/HEAD/risk/authority: see scope.md. Candidate only; not a formal review verdict.
RELEASE_READY: false

## Executed

- `rtk proxy python3 -B reports/verification/a8-reviewer-digest-candidate-20261006/candidate_test.py`: exit 0. Both Bash and PowerShell entrypoints on macOS: valid A/B with no ledger; changed bytes, absent input, run/session/sequence/previous changes, order/removal/duplicate, unlisted ledger/peer/other-feature/case/traversal paths, receipt uniqueness/tip/hash/extra line, duplicate JSON, input symlink/hardlink and reserve-option rejection. Fixture tree unchanged. Old-mode rejection status/stdout/stderr identical. Fixed launcher argv and original hashes checked. These are synthetic tests, not native permission or identity proof.
- `rtk proxy python3 -B reports/verification/a8-reviewer-digest-candidate-20261006/regression.py`: exit 0. Disposable overlay of the existing shared boundary suite: 32 citation anchors, TEST-RCB-001..010 Bash/PowerShell, regular/link and investigation completeness cases, final 84 PASS / 0 FAIL and 3 Python unit tests. Full output: shared-regression.stdout.txt and shared-regression.stderr.txt. All reservation effects were inside disposable fixtures.
- Final `rtk proxy git apply --check reports/verification/a8-reviewer-digest-candidate-20261006/candidate.patch`: exit 0.
- Final build rechecked all seven existing protected preimages against baseline; none drifted. Ledger remains c95ef67d1c227c8d31320a2dd526d50940dd52745240189e7e29eb9460986264; attempt-4/round-1 precheck remains 3718c701f23907c710c3c98cb1cc64faec5d906bdbd577b2882c92d5bca32467.

After executable tests, the only final change scoped both role prohibition sentences to ordinary/reservation modes, resolving their contradiction with the explicit calculation-only exception. No executable or test bytes changed after these runs. No redundant native attempt was made.

## Contract comparison and limits

Sequence >= 2 is inherited from original validate-review-context-set.sh:446, not a new policy. Feature grammar is inherited from :445, identity grammar from :496–498. The existing record and ordered-input recipes are retained. This mode intentionally accepts only a fresh successful reservation receipt with numeric pre-append tip, not historical verification output with `-` tip.

The ordinary PowerShell body is unchanged after the early optional dispatch. Existing macOS PowerShell ordinary-path regression passes. New mode requires POSIX descriptor-relative no-link reads: native Windows is unsupported/fail-closed, and neither these tests nor source inspection establish Windows execution. Normal Windows mode does not invoke the Python helper when ReviewerReceipt is absent; actual Windows regression was NOT RUN.

Raw admitted-file shasum commands alone cannot calculate the prescribed canonical ordered-input and record digests. Reusing normal validator verification would read the forbidden ledger. The 139-line common calculation module avoids duplicating secure input reads and canonical recipes across Bash/PowerShell; it is not an authentication service or a new evidence schema. It verifies arithmetic against the caller-saved receipt, not its provenance. Caller receipt equivalence and actual host identity correspondence remain mandatory outside it.

Native host capability is NOT VERIFIED: exact --allowedTools matching, inherited permissions, chaining/substitution rejection, custom-role availability and real host identity/receipt correspondence. No permission settings changed, no native launch/reservation occurred, no refused operation was rerouted. The launcher is an unexecuted candidate. Separate idle-identity contract candidate remains unapplied; both contract deltas require coordinated formal review/application. Other owners' validator changes must be integrated by hunks and final preimages re-pinned, never overwritten.

## Final artifact hashes

candidate.patch: f73564abaa6382d3a02e0198fd1f7eaed2bf5bc7f18fd42488a88c616bc6f8f7

Eight product targets below; paths are relative to candidate/:

| Target | SHA256 |
| --- | --- |
| plugins/sdd-quality-loop/scripts/validate-review-context-set.sh | 96cda1dde7dda85bd1fa16891f471fd8b3297b29c244bb22a4a040f6b33ca696 |
| plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 | 60695bb6c49820d13d9795ee6b4adc0127b415deb410b6b4144dee0c2b91f4c6 |
| plugins/sdd-quality-loop/scripts/reviewer-receipt.py | 08785f133567ed2fc24084332819f75d56e94e0afb6dfb33fa3b5cc2a2866b1b |
| plugins/sdd-review-loop/agents/spec-reviewer-a.md | 14a4e3aed4787df3e109d558e13491055f0555c12413eb0977553a5d27abaab7 |
| plugins/sdd-review-loop/agents/spec-reviewer-b.md | df8f332a3db9364a219f96602b59d196c9cffece5e69411a1db4fe4d15e278b5 |
| plugins/sdd-review-loop/references/review-context-boundary.md | a7661082974595f8172d30b42d73705cf089e3dc909cb69bf5f3808716f398dd |
| plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md | dc8bcead9e107d17cc51d9a1ce0118be38099516615d17e73befade1490f5957 |
| tests/review-context-boundary.tests.sh | 4b0b00e4b57ffb5ca6d786db08616adff1ac121e49644d2c23b8f38a74297087 |

The existing test-file changes only track six-line-shifted validator source anchors; they do not weaken assertions. The restricted launcher proposal is idle_launcher_candidate.py, outside the product patch. Coder/tester guidance was used to keep reproduction, isolated negative tests and original-byte preservation separate from formal admission.
