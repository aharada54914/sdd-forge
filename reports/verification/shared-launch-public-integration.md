# Shared review launch publication assembly

- Scope: approved shared-review-launch-repair T-004 integration; A7 and issue #423 launch callers. This is not completion of those product epics or the subsequent immutable-input architecture.
- Owner branch: `codex/shared-launch-public-integration`.
- Starting HEAD: `0b2951b6855bbd136938fafa901ee8af8bbe4855`; initial working tree clean.
- Candidate source: local verification commit `a2379c76c51a63069fa710b157636aa68be54076` is not a publication baseline. Transfer selected artifacts only, not its private history.
- Risk: high. Review authorization, input identity, isolated delivery, workflow-state verification, snapshot validation, and mandatory CI registration are affected.
- Preserve canonical approvals and historical review evidence. Do not publish private launch logs or implementation-host paths, overwrite other checkouts, or infer final-head CI from fixture results.
- Required validation: transferred byte identity and modes; mirror/generated-file consistency; workflow-state and review-input validation; affected Bash, Python, Node and PowerShell regressions; independent evaluation; latest publication-head mandatory CI including Windows; merge and post-merge verification.
- Existing full Bash and PowerShell fixture runs succeeded on macOS. Publication-head validation, independent evaluation, Windows CI, merge and post-merge verification remain pending.

## Publication worktree checks

Executed against the transferred, uncommitted candidate on macOS; these are not final-head CI results.

| Check | Observed result |
| --- | --- |
| `tests/repository-release-validation.tests.sh` | 8 passed, 0 failed |
| Default `check-workflow-state.sh` invocation | exit 0, `workflow-state: ok` |
| `tests/unified-launch-order.tests.py` | 9 passed |
| `tests/host-review-preflight.tests.py` | 19 passed |
| `tests/quality-nontty-transport.tests.py` | 20 passed |
| `tests/shared-launch-build.tests.py` | 1 passed; isolated FilesOnly installation, no host registration |
| `tests/human-copy-mirror-freshness.tests.sh` | 6 passed, 0 failed, 17 informational pending |
| `git diff --check` | exit 0 |

Historical rollback and full-suite results remain separate from this candidate's checks. Formal quality evaluation, exact-head Windows and other mandatory CI, merge, and post-merge checks are not yet established by this record.

## Independent diff review and full-suite preparation

An independent read-only reviewer checked the publication candidate against
`0b2951b6855bbd136938fafa901ee8af8bbe4855`: no Critical or Major findings.
The reviewer executed transport (20), launch-order (9), and structured-output
(13) regressions: 42 passed. This diff review is not a formal quality-gate verdict.

The first publication-worktree POSIX run encountered missing Ajv dependencies in
`adversarial-review-contracts.tests.sh`. After the existing CI-MCP lockfile was
installed with `npm ci --prefix mcp/ci-mcp --ignore-scripts`, the focused suite
passed. The initial failure remains a failure; it is not retroactively a clean
full-suite run. That dependency installation reported four high-severity audit
entries, which remain separate from launcher correctness and need disposition
before release. No dependency versions were changed by this preparation.

## First full-run failures and bounded repairs

The first POSIX run exited 1 with six failing suites. Besides the Ajv preparation
above, the evaluation-preparation suite lacked its two existing delivery helpers.
Both helpers were transferred unchanged from the owning checkout; its focused
regression then passed all 16 cases. No acceptance condition was removed.

The four remaining focused runs failed only their unchanged-workflow assertions
because this integration intentionally modifies the uncommitted workflow:

| Suite | Passed | Failed |
| --- | ---: | ---: |
| capability-registry-parity | 21 | 1 |
| facet-manifest-parity | 328 | 1 |
| resolve-project-context-parity | 69 | 1 |
| component-path-ownership-parity | 20 | 1 |

Their behavioral and negative cases passed. Preserve these observed failures;
rerun the unchanged tests after committing the candidate. A checkpoint commit is
not quality-gate acceptance, publication, or proof of final-head CI success.
