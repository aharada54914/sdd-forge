# Independent Re-Review: T-007 (Attempt 2)

Verdict: **FAIL**

## Review identity and input integrity

- Task: `T-007`
- Requirement: `REQ-011`
- Acceptance criterion: `AC-006`
- Acceptance test: `TEST-005`
- Review manifest:
  `reports/implementation/agent-cost-context-isolation/manifests/T-007-review-2.json`
- Isolation mode: `fresh-agent`
- Result: all 37 `allowed_inputs` passed repository-containment,
  regular-file, and SHA-256 validation before any allowed input was read.
- Review used only the manifest, its hash-validated allowed inputs, the
  explicitly requested validator/test executions, and current Git `HEAD` for
  the explicitly requested CHANGELOG-history reproduction.

## Findings

### Critical

None.

### Major

#### M-01 — TEST-005 and AC-006 still do not pass

The attempt-2 evidence records:

```text
./tests/run-all.sh
Exit: 1
Result: FAIL — unrelated T-008 prerequisite
```

This conflicts with all three governing statements:

- `requirements.md:148-149`: AC-006 requires repository validation, Bash
  tests, and PowerShell tests to pass.
- `acceptance-tests.md:53-56`: TEST-005 runs `tests/run-all.sh`,
  `tests/run-all.ps1`, and both repository validators.
- `tasks.md:446-451`: T-007 is Done When TEST-005 passes, both validators
  agree, and no historical release entry is rewritten.

The missing `contracts/rollback-1.5.0.json` is legitimately owned by T-008:
T-007 explicitly excludes rollback execution (`tasks.md:453-455`), while
T-008 plans the rollback hash inventory and transaction
(`tasks.md:461-507`). This establishes an implementation-scope boundary, but
it does not waive T-007's explicit passing-test completion criterion.

The current task plan also makes this a dependency deadlock rather than a
valid implicit waiver: T-008 lists T-007 as its blocker
(`tasks.md:521-523`), while T-007 cannot satisfy its literal TEST-005
condition until T-008 supplies the rollback contract. Therefore T-007 cannot
be marked `Implementation Complete` under the current approved task contract.
Human-controlled task/spec reconciliation must either move the aggregate-suite
condition to the post-T-008 boundary or otherwise explicitly revise the
dependency and acceptance contract; alternatively, T-008 must be completed
and `tests/run-all.sh` rerun successfully before T-007 completion.

The review-2 allowlist does not include `tests/run-all.sh`,
`tests/rollback-1.5.0.tests.sh`, or the absent rollback contract, so this
review did not treat the implementation report's “only” diagnosis as an
independently rerunnable fact. The authorized `green.log` provides the
recorded failing command, exit code, output tail, and diagnosis. Regardless
of whether that diagnosis is exhaustive, exit 1 is sufficient to leave
TEST-005 and AC-006 unsatisfied.

Minimum correction: resolve the approved task-contract/dependency conflict,
then provide hash-bounded evidence that the resulting T-007 completion
criteria pass. Do not mark T-007 `Implementation Complete` while its current
explicit TEST-005 condition is failing.

### Minor

None.

## Prior-finding disposition

| Prior finding | Disposition | Exact evidence |
|---|---|---|
| M-01 — required repository/test commands incomplete | **OPEN (Major)** | Both validators now pass and `run-all.ps1` is recorded passing, but authorized `green.log` records `run-all.sh` exit 1. |
| M-02 — POSIX validator was not equivalent | **RESOLVED** | `tests/validate-repository.sh:4-11` resolves its peer and `exec`s `pwsh -NoProfile -File validate-repository.ps1`; independent executions of both entrypoints returned 0 with identical success output. |
| M-03 — README/CHANGELOG not protected | **RESOLVED** | `tests/validate-repository.ps1:34-46` validates the first README release declaration and exactly one CHANGELOG v1.5.0 heading. `tests/repository-release-validation.tests.sh:69-101` exercises valid, README mutation, duplicate CHANGELOG heading, and restored-valid cases through both entrypoints; independent run passed 8/8. |
| m-01 — historical CHANGELOG claim not reproducible | **RESOLVED** | Independently reproduced from current `HEAD` `9ad373e50a93ece2a270ce126e811ad3caaa3bb0`: both HEAD and working-tree suffixes from the first `## v1.4.0` heading through EOF are 44,892 bytes with SHA-256 `798a23e751e51d416666fb5b72776bc191e27ecc47e412aa7e6c6c5fa142948e`; `cmp` returned 0. |

## Independent checks

| Check | Result |
|---|---|
| 37 review-input path/type/SHA-256 validations | PASS |
| `./tests/validate-repository.sh` | PASS, exit 0; `workflow-state: ok`; `Repository validation passed.` |
| `pwsh -NoProfile -File ./tests/validate-repository.ps1` | PASS, exit 0; `workflow-state: ok`; `Repository validation passed.` |
| Normalized task-plan provenance through both repository entrypoints | PASS; the authoritative workflow-state precheck reported `workflow-state: ok` in both executions |
| `./tests/repository-release-validation.tests.sh` | PASS, exit 0; 8/8 checks |
| 18 Claude/Codex/Copilot plugin manifests | PASS; all versions `1.5.0` |
| 12 entries across both marketplaces | PASS; all versions `1.5.0`, one per expected plugin in each marketplace |
| README current release | PASS; first version declaration is `v1.5.0` |
| CHANGELOG current release | PASS; exactly one `v1.5.0` heading |
| Version validator release constants and document checks | PASS; `tests/validate-repository.ps1:14-20,34-46` identifies and enforces `1.5.0` |
| Historical CHANGELOG suffix vs current Git HEAD | PASS; byte-identical, 44,892 bytes, SHA-256 `798a23e751e51d416666fb5b72776bc191e27ecc47e412aa7e6c6c5fa142948e` |
| `tests/run-all.ps1` | PASS only as hash-authorized implementation evidence; not independently rerun by this review |
| `tests/run-all.sh` | **FAIL**, exit 1 in hash-authorized implementation evidence |

## Conclusion

Attempt 2 fixes validator equivalence, durable README/CHANGELOG validation,
normalized task-plan provenance, and reproducible historical CHANGELOG
evidence. All inspected release surfaces consistently identify `1.5.0`.

The verdict remains **FAIL** because the approved T-007 contract requires
TEST-005/AC-006 to pass and the Bash aggregate suite is recorded failing.
T-008 owns the missing rollback implementation, but that scope boundary cannot
silently override T-007's approved completion criterion.
