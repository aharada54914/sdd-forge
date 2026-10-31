# T-005 attempt-6 caller fixture preparation (diagnostic only)

Scope: approved T-005, caller-side delivery repair only. Owner checkout:
`/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`.
Observed HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807`.
Risk: existing high-risk task; no product implementation, authorization, review
criteria, lifecycle, ledger or frozen evidence changes are authorized here.
Writes are limited to this new attempt-6 handoff directory. Existing attempt-5
and earlier records remain unchanged. The owner has extensive existing tracked
and untracked work, including validators, review skills, reports and specs; none
is reset, committed or modified by this fixture preparation.

This record was added after initial helper/package construction, before local
selfcheck. It is not a retrospective assertion that preflight preceded those
helper writes. The delegated scope and constraints preceded construction.

## Cross-artifact validation plan

| Persisted field | Counterpart | Failing mismatch check |
| --- | --- | --- |
| Source path, SHA-256, mode inventory | Manifest allowed_inputs and snapshot bytes | Reject hash mismatch before output creation; compare restored modes |
| Pack SHA-256 and object IDs | Actual pack and restored Git object inventory | Reject corrupted pack; compare exact object set |
| Three historical commit identities | Original Git commit objects | rev-parse exact IDs and Red parent |
| Red changed paths | Original diff-tree | Compare complete changed-path list |
| Baseline presence and archive hash | Original rollback tree | Assert eleven present, two absent; compare archive SHA-256 |
| Output isolation | Standalone bare repository | Reject alternate/common directories and remote/include/promisor config |

Only three commit objects plus all their trees/blobs are delivered. Parent and
rollback commits are shallow boundaries; Red is not shallow, so its parent diff
remains available. No ancestry is fabricated. No owner .git pointer, alternate,
remote or network fetch is required. Repository-history content is preserved as
Git objects, not rewritten text. Local selfcheck is not native reviewer execution,
formal independent review, quality-gate PASS, CI, installation or task completion.

## Local result (2026-10-09)

`rtk proxy node handoffs/shared-review-launch-repair-T-005-attempt-6/selfcheck.cjs`
completed with exit 0. The saved diagnostic is `selfcheck-ktTtAT/result.json`;
complete original suite stdout/stderr are `selfcheck-ktTtAT/suite.stdout` and
`selfcheck-ktTtAT/suite.stderr`. Source inventory: 17 repository inputs and four
preparation inputs. All snapshot files remained mode 0444 with identical SHA-256.
Executable copies used the source-mode inventory. The unchanged original
`tests/review-agent-isolation.tests.sh` ran from output/work with TMPDIR under
output and T005_SOURCE_GIT_ROOT pointing only to output/git-history.git.
It finished with `PASS: 26; FAIL: 0`, including Bash and PowerShell scratch-history
checks, plus the sequential reviewer/evaluator checks and rollback comparisons.

Restored history contains exactly 1,190 objects and passes git fsck. Exact commit
IDs, Red parent, both changed paths, eleven baseline present paths, two absent
validator paths, and archive SHA-256 match the owner's original Git results.
Archive SHA-256: `0a3f2382ba6778aa5d6adcb8d54ebc8c7fb1fad47f39d0fc7607bc77977e6ffc`.
Pack size: 1,263,181 bytes. Pack SHA-256:
`abb124c03ca33abcbaaecc196cf121ff917a63b3dd4d8d3b000e37cb285ae1ea`.
Expected cat-file errors for the two absent baseline validators are preserved in
prepare.stderr; they are checked negative results, not preparation failures.

Negative cases passed: altered pack rejected before destination creation;
external/symlinked snapshot rejected; altered manifest inventory hash rejected at
admission (`selfcheck-admission.cjs`, `selfcheck-ktTtAT/admission-result.json`).
These diagnostics do not assert OS sandbox enforcement: native isolated launch
and official manifest admission remain the parent's work. No formal reservation,
review result, task state, commit, or product file was changed by this subtask.

Pinned preparation hashes:

| File | SHA-256 |
| --- | --- |
| git-history.cjs | 6e9923e5d44fe437ff4deec30ae005bfa5d0e5e980efe45152a1af49cae5f5b7 |
| git-history.json | d4429cc2ff9fe43e1fb564da4e1fc528f0cd2233805fe1cd44ebe627f6e05501 |
| prepare-fixture.cjs | 304a3b36ac48abe6ec078a6df999a0f8584aeef997df806088f00c836b59789c |

The selfcheck manifests are diagnostic-only and not official attempt manifests.
