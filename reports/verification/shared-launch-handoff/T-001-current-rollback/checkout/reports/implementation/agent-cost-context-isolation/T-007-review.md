# Independent Review: T-007

Verdict: **FAIL**

## Review identity and input integrity

- Task: `T-007`
- Requirement: `REQ-011`
- Acceptance criterion: `AC-006`
- Acceptance test: `TEST-005`
- Review manifest:
  `reports/implementation/agent-cost-context-isolation/manifests/T-007-review.json`
- Isolation mode: `fresh-agent`
- Result: all 33 `allowed_inputs` existed and matched their declared SHA-256
  before review.
- Review used only the review manifest and its hash-validated allowed inputs.

## Findings

### Critical

None.

### Major

#### M-01 — TEST-005 and AC-006 are not complete

`specs/agent-cost-context-isolation/acceptance-tests.md:53-56` requires
`tests/run-all.sh`, `tests/run-all.ps1`, and both repository validators to
pass. The implementation evidence does not run either `run-all` command, and
records the complete PowerShell validator as blocked:

- `reports/implementation/agent-cost-context-isolation/T-007.md:60-72`
- `specs/agent-cost-context-isolation/verification/T-007/green.log:24-29`
- `reports/implementation/agent-cost-context-isolation/T-007.md:96-98` lists
  the missing commands as future work.

Independent focused execution reproduced:

```text
./tests/validate-repository.sh                         exit 0
pwsh -NoProfile -File ./tests/validate-repository.ps1 exit 1
```

The PowerShell failure is the existing fail-closed
`stage-provenance: task plan hash is stale` check
(`tests/validate-repository.ps1:5-9`). That stale provenance is not itself a
T-007 release-version implementation defect. It nevertheless means the
required validator did not pass, so T-007 cannot claim `TEST-005` or `AC-006`
complete.

Minimum correction: refresh the workflow-state provenance in its owning scope,
then capture successful executions of both `run-all` suites and both actual
repository validators before returning T-007 to independent review.

#### M-02 — The POSIX script is not an equivalent Bash repository validator

`tests/validate-repository.sh:1-63` checks only the two marketplaces and 18
plugin manifests. In contrast, `tests/validate-repository.ps1:5-9` first
enforces workflow-state provenance and the remainder of the PowerShell script
checks repository structure, public skills, required/forbidden paths, hooks,
templates, deterministic script pairs, and other policies.

This is not equivalent behavior under `REQ-010`, and the T-007 Done condition
at `specs/agent-cost-context-isolation/tasks.md:446-451` is demonstrably false:
on the same repository state Bash accepts while PowerShell rejects.
`.github/workflows/test.yml:44-50` labels both as repository validation, which
overstates the POSIX check and does not supply parity.

Minimum correction: either implement a genuinely equivalent Bash repository
validator with parity fixtures, or give the release-only script an accurate
name and add a separate full POSIX repository validator. CI must exercise the
real paired behavior.

#### M-03 — Checked-in release validation does not protect README or CHANGELOG

REQ-011 includes README and CHANGELOG. Their current contents are correct
(`README.md:3`, `CHANGELOG.md:5`), and all 18 manifests plus all 12 marketplace
entries independently report `1.5.0`. However, neither checked-in validator
reads README or CHANGELOG:

- `tests/validate-repository.sh:8-63`
- `tests/validate-repository.ps1:12-79`

An isolated mutation test changed both documents to `v9.9.9`; the POSIX
validator still printed `Repository release validation passed.` and exited 0.
The evidence at
`specs/agent-cost-context-isolation/verification/T-007/green.log:40-50` relies
on an ad-hoc Python scan that is not present in the validator or CI workflow,
so the regression protection is not durable.

Minimum correction: make both checked-in validators enforce the README release
line and exactly one current CHANGELOG heading, and add negative parity tests.

### Minor

#### m-01 — Historical CHANGELOG preservation is asserted but not independently reproducible from the review boundary

The current `CHANGELOG.md:1-17` is shaped as an additive v1.5.0 entry followed
by v1.4.0 history. The allowed evidence states that the v1.4.0-and-older suffix
was byte-compared with `git show HEAD:CHANGELOG.md` and passed
(`specs/agent-cost-context-isolation/verification/T-007/green.log:52-57`).
However, the review manifest contains neither the baseline suffix/hash nor a
machine-produced comparison artifact, so a fresh reviewer restricted to the
declared inputs cannot independently reproduce the no-rewrite claim.

Minimum correction: include a baseline hash or deterministic diff artifact in
the allowed review inputs. No historical rewrite was observed in the supplied
current file, but the evidence boundary is weaker than the task's explicit
Done condition.

## Independent checks

| Check | Result |
|---|---|
| 33 review-input SHA-256 values | PASS |
| 18 plugin manifest name/version pairs | PASS (`1.5.0`) |
| 12 marketplace name/version entries | PASS (`1.5.0`, one each) |
| README current release | PASS (`v1.5.0`) |
| CHANGELOG current release entry | PASS (one `v1.5.0` heading) |
| `sh -n tests/validate-repository.sh` | PASS |
| `./tests/validate-repository.sh` | PASS |
| Full PowerShell repository validator | FAIL: stale workflow-state provenance |
| Bash/PowerShell validator agreement | FAIL |
| Mutated README/CHANGELOG rejection by Bash validator | FAIL (mutation accepted) |
| `tests/run-all.sh` / `tests/run-all.ps1` evidence | MISSING |

## Conclusion

The release metadata itself is synchronized to `1.5.0`, but T-007 does not
satisfy its acceptance contract. TEST-005 is incomplete, the actual repository
validators disagree, and the new Bash script is a release-manifest subset
rather than a truthful equivalent repository validator.
