# Independent Review: T-005

## Identity

- Reviewer: `T-005-independent-reviewer`
- Run ID: `agent-cost-context-isolation-T-005-review-run-01`
- Session ID: `agent-cost-context-isolation-T-005-review-session-01`
- Agent Instance ID: `T-005-independent-reviewer`
- Model Tier: `standard`
- Isolation Mode: `fresh-agent`
- Input Manifest: `reports/implementation/agent-cost-context-isolation/manifests/T-005-review.json`
- Manifest Gate: PASS — all 19 `allowed_inputs` existed and matched their declared SHA-256 before substantive inputs were read

## Checks

- Read T-005, REQ-005, REQ-010, AC-002, the design and security boundaries, the implementation report, and Red/Green evidence from the hash-bound input set.
- Inspected both deterministic validators, all six reviewer prompts, the evaluator prompt, the quality-gate launch instructions, and the isolation test.
- `bash tests/review-agent-isolation.tests.sh`: PASS (`ok: spec, implementation, and task review roles are distinct and isolated`).
- Adversarial existing-file allowlist check: both Bash and PowerShell returned exit 0 and `REVIEW_CONTEXT_OK` when every role was given `private/arbitrary-existing.txt`, an existing hash-matching file outside every role prompt's declared allowlist.
- Cross-runtime whitespace-identity check: Bash returned exit 0 and `REVIEW_CONTEXT_OK` for a run ID containing one space; PowerShell returned exit 1 with `REVIEW_CONTEXT_IDENTITY`.
- Reviewed the rollback fixture and Red log structurally against T-005's explicit rollback and TDD proof requirements.

## Findings

### Critical

1. **The deterministic boundary accepts arbitrary existing unlisted files.** `validate-review-context-set.sh` lines 93-143 and `validate-review-context-set.ps1` lines 141-184 validate canonical syntax, existence, link status, and hash, but neither validator enforces the per-role allowlists declared by the reviewer/evaluator prompts. The only content-specific denial is a narrow raw-reviewer-report filename pattern. Both runtimes accepted a real hash-bound `private/arbitrary-existing.txt` for all seven roles. The shipped negative fixture at `tests/review-agent-isolation.tests.sh:129` substitutes a nonexistent path, so it tests file existence rather than allowlist membership. This directly violates REQ-005 and the security spec requirement that an unlisted file fail closed.

2. **The seven-role contract is not a feasible launch-time gate for the sequential workflow and no host launch integration for the six review stages is present in the allowed implementation.** Both validators require all six reviewers plus the evaluator in one exact seven-context document (`validate-review-context-set.sh:39-81`; PowerShell lines 81-97). At the first specification-review launch, later design/task/implementation/evaluator inputs and their actual host sessions do not yet exist. The Green fixture avoids this chronology by assigning the same already-existing requirements file to every future role (`tests/review-agent-isolation.tests.sh:67-106`), which the validators accept because they do not enforce role allowlists. The six prompt files merely tell an already-launched model to require `REVIEW_CONTEXT_OK`; only the quality-gate skill contains a caller-side validator invocation, and that occurs at the final evaluator stage. Consequently the evidence does not prove that each reviewer is rejected before launch on a missing, stale, or fabricated boundary as AC-002 requires.

### Major

1. **Identity freshness is caller-asserted rather than fail-closed.** Empty `reserved_run_ids` and `reserved_host_session_ids` arrays are valid in both validators. The contract therefore proves uniqueness only within the supplied seven entries; it cannot reject reuse from an implementation session, an earlier review round, or an earlier evaluation when the caller omits that identity. The adversarial existing-file fixture also passed with both reserved arrays empty. REQ-005 requires reused review/evaluation sessions to be rejected, not merely identities that the untrusted manifest happens to reserve.

2. **Bash and PowerShell behavior is not equivalent.** Bash checks only `length > 0` for run/session and reserved IDs (`validate-review-context-set.sh:53-69`), while PowerShell uses `IsNullOrWhiteSpace` (`validate-review-context-set.ps1:103-130`). A whitespace-only run ID was accepted by Bash and rejected as `REVIEW_CONTEXT_IDENTITY` by PowerShell. This violates REQ-010, and the parity fixtures omit whitespace identities.

3. **The rollback fixture does not prove the rollback boundary requested by T-005.** T-005 requires restoration of the 1.4.0 reviewer/evaluator prompts and quality-gate invocation rules. The fixture at `tests/review-agent-isolation.tests.sh:141-173` copies the current T-005 artifacts, damages two copies, then restores those same current artifacts from a backup and reruns the current validator. It never restores or validates the 1.4.0 boundary, so the task's rollback Done When item is unproven.

4. **The Red evidence does not establish the required committed-test-before-implementation ordering.** `red.log` archives baseline commit `1bba72f` and then overlays `tests/review-agent-isolation.tests.sh` from the later working tree before running it. That demonstrates that a strengthened test fails against baseline product code, but not that the failing test itself was committed before implementation began, which is the explicit T-005 Done When requirement.

### Minor

- None.

## Verdict

**FAIL**

T-005 has unresolved Critical and Major findings. The current Green suite is insufficient to establish REQ-005, REQ-010, and AC-002.
