# A7 shared non-TTY file-hash delivery repair (candidate, 2026-10-07)

## Attempt 15 follow-up preflight (2026-10-07)

- Owner/HEAD: A7 shared launcher owner in `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`, detached `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`. The checkout has extensive pre-existing dirty changes, including the preceding bounded validator candidate; preserve all unrelated bytes. Issue/task: #195 A7 post-implementation task provenance re-review, attempt 15 round 1.
- Risk/contracts: high-risk protected evidence/identity transport. The approved follow-up does not alter authorization, hashes, reservation, or reviewer verdict semantics. `control_prompt` requires all hash results before substantive Read, but says nothing about ordering two admitted Reads after the hashes. The existing postflight incorrectly treats a pending Read as a pending hash (`validate-nontty-spec-launch.py` `require(not pending, 'impl Read overlapped pending hash proof')`). Native attempt-15 transcript has all file/control hash results before parallel admitted Reads; its first two Read calls overlap. That attempt is stopped, cannot be adopted or rerun with the same identity, and reviewer B was not reserved.
- Separate prompt/role conflict: the task reviewer role text suggests grep Bash generally, while the non-TTY exact-permission policy admits only pinned hash and domain-presence Bash. The native reviewer proposed a grep Bash that the guard denied. Keep that denial effective. Scope the task role instruction to the exact-permission session, direct review analysis to admitted Read, and repeat this in the launcher prompt; do not expand the allowlist.
- Validation plan: RED for parallel admitted Read after complete hash proof and role/prompt exact-command instruction; GREEN after the minimal validator/role/prompt change. Negatives retain early Read while a hash is pending, unknown/duplicate IDs, unreturned Read before StructuredOutput, and out-of-scope Bash rejected by the session guard and postflight. Rerun affected non-TTY suites and obtain independent final-diff review before any new formal reservation.

### Attempt 15 follow-up execution

- RED: new parallel-admitted-Read fixture failed with `ValueError: impl Read overlapped pending hash proof`; prompt/role consistency assertion also failed before changing transport. The formal attempt-15 transcript was not modified or adopted.
- GREEN: validator now distinguishes pending Read results from pending non-Read proof; admission still checks exact allowed path and unique use/result IDs, all hashes precede substantive Read, and StructuredOutput requires no pending tool. The task reviewer A/B general Bash sentence now defers to the session's exact-command allowlist, and the canonical prompt directs analysis through admitted Read. Neither guard nor allowlist was expanded.
- Negative fixtures: pending hash before Read, unknown Read result ID, incomplete Read result, unreturned Read before StructuredOutput, and denied out-of-scope grep Bash remain rejected. `tests/a7-nontty-impl-contract.tests.py` 12/12; `tests/unified-task-launch.tests.py` 9/9; `tests/task-structured-output.tests.py` 13/13; `tests/quality-nontty-transport.tests.py` 7/7; `tests/unified-launch-order.tests.py` 8/8. Total 49/49 local tests; independent final-diff review pending.
- Candidate SHA-256: validator `f020b295fdf26dca471c22077ad5221971c753b348c84aee68090649135aff8c`; task role A `729855940bd6df1dbd685d5735bd001def0e0d9dedf592659bbc44db5e5e3d5a`; task role B `7d3cb289e0fc5fd26b79d957a8e61e7896e3ca80a884f3e0c3a4433e05945cc0`; A7 transport test `363b23e32cf86eb8791b25f3451437868b84366297c4832c192b3fe9c581008c`; structured-output test `681130535f853f5bb9f98f982c4d523adc9fbb63b00aef60ce3582430499156d`.

## Pre-edit record

- Issue/task: Epic #195 A7 shared review launcher maintenance; no task status or review verdict is changed by this candidate.
- Owner checkout: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`, detached HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`.
- Dirty state: the checkout already contains extensive unrelated modified and untracked work. The two owned files are untracked at the start of this repair: `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py` SHA-256 `5426afc28dd12d3e8429b5df953297d4c6ad72b08449a90446b81dd89ca3deb9`, and `tests/a7-nontty-impl-contract.tests.py` SHA-256 `c8819dbbb841a3ab4e5eb7f24b25f2f07cb70114cfafaefadf81c762cb9ea1fe`. Preserve all other work.
- Risk: high, because this changes a shared launch evidence/enforcement condition. It does not relax exact command permission, receipt or input identity, required checks, reviewer independence, or canonical output verification. This is a candidate for the existing formal path, not a review PASS.
- Affected contract: the current prompt and postflight require every hash tool result before the next call. The approved bounded delta permits overlapping *file* SHA-256 calls only after the first Bash succeeds. File-call issue order remains manifest order, results are matched by unique `tool_use_id` to exact command/path/digest, receipt-text hashes stay sequential, and no substantive Read or StructuredOutput precedes completion of every required hash. The one permitted first-Bash fact-forcing retry remains immediate and byte-identical.
- Readers/writers: `validate-nontty-spec-launch.py` builds the prompt and verifies the native transcript; the existing exact-permission policy and guard consume its unchanged per-file command list. Spec/impl/task/quality non-TTY callers consume this shared transport. No ledger writer, reservation, frozen evidence, or installed control baseline is in scope.
- Validation plan: add disposable transcript fixtures for overlapping file calls (including out-of-order results) and negatives for issue-order drift, duplicate pending command/ID, wrong result ID/digest, missing result, first-Bash overlap/refusal, early substantive Read, and overlapping receipt-text hashes. Observe RED before changing transport, then GREEN; run affected transport/caller tests, static diff/whitespace checks, and independent final-diff review. Native formal review, reservation and public CI are excluded here.

## Evidence-field preflight

| Persisted field or proof | Counterpart | Failing mismatch fixture |
|---|---|---|
| Tool-use `id` and Bash command | Tool-result `tool_use_id` and exact allowed command | Unknown/duplicate result ID and duplicate pending command reject |
| File hash result | Raw admitted path hash or boundary-document hash | Wrong digest and missing result reject |
| File hash call order | Ordered manifest plus boundary path | Out-of-order call rejects despite valid digests |
| Completion before substantive Read/StructuredOutput | Full required-hash set and no pending tools | Early Read/output rejects |
| First-Bash refusal/retry | Immediate identical first command, once | Overlap or different retry rejects |
| Ordered inputs and receipt-record hash | Reconstructed input text and receipt text | Overlapping text-hash calls reject; mismatched digest rejects |

No new verdict or traceability claim is persisted by this candidate.

## Executed candidate evidence

- RED: the new parallel-file transcript fixture was rejected by the original postflight with `ValueError: impl hash commands were not serialized` (12-test suite, one error). No formal reviewer was launched.
- GREEN: after the bounded validator change, `rtk proxy python3 -B tests/a7-nontty-impl-contract.tests.py` passed 12/12. The suite includes out-of-order file results, first-file-success and issue-order guards, duplicate/pending/mismatched tool identities, exact digest plus output path, non-hash Bash/Read overlap rejection, first-Bash retry, and serialized receipt-text hashes.
- Caller regressions on the same candidate: `tests/unified-task-launch.tests.py` 9/9, `tests/task-structured-output.tests.py` 13/13, `tests/quality-nontty-transport.tests.py` 7/7, `tests/unified-launch-order.tests.py` 8/8. The task structured-output fixture was updated to emit the actual file-path label for native file hashes; its receipt-text fixture continues to emit `-`.
- This is a local candidate regression result, not independent diff approval, a formal review verdict, whole-repository CI, or installed-baseline proof. Frozen review evidence, ledger reservations, approvals, and task status were not changed.
