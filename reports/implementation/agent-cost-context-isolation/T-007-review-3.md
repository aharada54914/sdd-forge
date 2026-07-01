# Independent Re-Review: T-007 (Attempt 3)

Verdict: **PASS**

## Review identity and input integrity

- Task: `T-007`
- Requirement: `REQ-011`
- Acceptance criterion: `AC-006`
- Acceptance test: `TEST-005`
- Review manifest:
  `reports/implementation/agent-cost-context-isolation/manifests/T-007-review-3.json`
- Isolation mode: `fresh-agent`
- Result: all 37 `allowed_inputs` matched their declared SHA-256 values before
  content review.
- Scope: only the review manifest, its hash-validated allowed inputs, and the
  explicitly required validator/test executions were used.

## Findings

### Critical

None.

### Major

None.

### Minor

None.

## Prior Major disposition

### M-01 — TEST-005 and AC-006 did not pass

**RESOLVED.**

The T-008 rollback suite was registered before T-008 could begin even though
T-008 is blocked by T-007. Removing that premature registration eliminates the
dependency deadlock without weakening the implemented T-001 through T-007
regression boundary:

- `tests/run-all.sh` still registers
  `review-agent-isolation.tests.sh`, `agent-model-routing.tests.sh`,
  `task-context-isolation.tests.sh`, `turn-first-workflow.tests.sh`, and
  `retrospective-loop.tests.sh`.
- `rollback-1.5.0.tests.sh` is no longer registered before its T-008 contract
  and executables exist.
- Independently rerunning `tests/run-all.sh` completed with exit 0 and
  `All POSIX regression tests passed.`
- Independently rerunning `tests/run-all.ps1` completed with exit 0 and
  `All PowerShell regression tests passed.`

The correction is exactly one line. Re-inserting
`tests/rollback-1.5.0.tests.sh` immediately after
`tests/retrospective-loop.tests.sh` in the current runner as an in-memory
stream produces SHA-256
`abb309a46cf7d8d06f749139b905eab150a48b9d3b567b69e24788eef386e263`,
which exactly matches the pre-correction `tests/run-all.sh` hash bound by
`T-007-attempt-3.json`. No other runner content changed.

## Independent checks

| Check | Result |
|---|---|
| 37 review-input SHA-256 validations | PASS |
| `./tests/validate-repository.sh` | PASS, exit 0; `workflow-state: ok`; `Repository validation passed.` |
| `pwsh -NoProfile -File ./tests/validate-repository.ps1` | PASS, exit 0; same success output |
| `./tests/repository-release-validation.tests.sh` | PASS, exit 0; 8/8 checks |
| `./tests/run-all.sh` | PASS, exit 0; all registered POSIX regression tests |
| `pwsh -NoProfile -File ./tests/run-all.ps1` | PASS, exit 0; all PowerShell regression tests |
| T-001 through T-006 added POSIX suites remain registered | PASS |
| Exact one-line removal reconstruction | PASS; reconstructed hash equals the prior manifest-bound runner hash |
| 18 Claude/Codex/Copilot plugin manifests | PASS; every version is `1.5.0` |
| 12 entries across both marketplaces | PASS; every version is `1.5.0` |
| README current release | PASS; first version declaration is `v1.5.0` |
| CHANGELOG current release | PASS; exactly one `v1.5.0` heading |
| Version validator | PASS; all six expected versions and README/CHANGELOG checks enforce `1.5.0` |
| Historical CHANGELOG suffix | PASS; current v1.4.0-through-EOF suffix is 44,892 bytes with SHA-256 `798a23e751e51d416666fb5b72776bc191e27ecc47e412aa7e6c6c5fa142948e`, identical to the hash-bounded prior-review baseline |

## Conclusion

REQ-011, AC-006, and TEST-005 are satisfied. The prior dependency deadlock is
resolved by removing only the premature T-008 aggregate registration, current
T-007 coverage remains intact, both aggregate suites and both repository
validators pass, validator parity passes 8/8, every release surface reports
`1.5.0`, and the historical CHANGELOG suffix is unchanged.

There are no Critical or Major findings.
