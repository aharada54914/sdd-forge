# A8 BLOCKED continuation v2 — candidate only

Date: 2026-10-05
Scope: independent-review Major repair; four product files in a candidate patch.
Owner: a8-release-sync-oct01/sdd-forge.
Observed HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`.
Risk: high (admissible review history / evidence semantics).

## Supersession and cause

The v1 patch, runner and result remain unchanged historical records. They are
not approved for application: the independent technical review at
`reports/verification/a8-blocked-continuation-independent-review-20261005.md`
found that Pending/no-tasks skipped history validation while accepting forged
Critical counts. Its Major finding is accepted.

`check-workflow-state.sh:1910` / `check-workflow-state.ps1:2429` dispatch history
validation under Passed, not Pending. Calling the whole workflow validator
therefore did not establish the premise needed by the newly admitted BLOCKED
branch. The helper `plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh:239-270`
(`assert_contract_reviewer_agreement`) compares requirements, acceptance and
design pins across reviewers and contract; it does not recalculate counts or
bind the integrated verdict. It cannot close this defect by itself.

## Limited repair

`a8-blocked-continuation-v2-20261005.patch` supersedes v1 and changes only:

- `plugins/sdd-review-loop/scripts/impl-review-precheck.sh`
- `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1`
- `plugins/sdd-quality-loop/scripts/check-workflow-state.sh`
- `plugins/sdd-quality-loop/scripts/check-workflow-state.ps1`

The precheck still admits only exact BLOCKED with prior round below 3, before
the unchanged ADR/core/layer/input-hash checks. It now calls a validation-only
`--feature <slug> --impl-history <attempt>:<round>` mode, independent of the
current design status. That mode reuses the existing immutable-snapshot
canonical validators, without duplicating their count/identity rules:

- Bash: `workflow_adr_history_bindings`, source lines 146-430.
- PowerShell: `Read-AdrHistoryEvidence`, source lines 1709-1770, which composes
  `Get-AdrHistoryBinding` and `Test-AdrHistoryOutputs`.

The explicit mode requires an ADR binding extension; it does not broaden
legacy admission. It forbids combination with `--opening`, requires a feature,
rejects malformed/duplicate/mis-cased mode arguments and unsafe slug paths,
and exits with `workflow-state: impl-history: ok` only for the specified saved
history. This is deliberately not `workflow-state: ok`: it is neither full
workflow validation nor launch authorization. Normal dispatch is unchanged.

The only temporary writes performed by the canonical Bash validator are its
existing private snapshots, removed by its existing exit trap. The new mode
does not alter source state, historical evidence, status, approval, or identity
reservation. It does not compare corrected current ADR bytes to old bindings.

## Evidence-field preflight and negative cases

No new persisted review field is introduced. The newly consumed fields retain
their existing canonical counterparts and mismatch rejection:

| Consumed evidence | Counterpart | Failing fixture |
|---|---|---|
| Contract Critical/Major totals | Reviewer FAIL check severities and integrated counts | forged-zero-critical / forged-major-count |
| Integrated verdict | Contract and computed reviewer outcomes | integrated-verdict-mismatch |
| Reviewer run identity | Reserved contract reviewer identity | identity-mismatch |
| Reviewer manifest hash | Precheck, core/layer/ADR bindings | reviewer-pin-mismatch |
| Historical round | Requested previous slot and continuation limit | round-limit |

## Validation

Commands, through `rtk proxy`:

```text
git apply --check reports/verification/a8-blocked-continuation-v2-20261005.patch
python3 reports/verification/a8-blocked-continuation-v2.tests.py
```

The runner uses disposable copies of the current checkout. It preserves the
owner's historical bytes and checks their hashes after execution. Pending is
modeled only in the fixture by changing the copied status and removing its
copied tasks; it uses the normal precheck, not provenance mode. Passed retains
the copied A8 history and uses provenance re-review. No fake Passed status is
used to obtain history validation.

Coverage includes both runtimes and both states: normal BLOCKED, forged Critical
and Major totals, integrated-verdict disagreement, run-identity disagreement,
manifest disagreement, mis-cased/unknown verdicts, and round-limit rejection.
The existing ADR generation suite is run unchanged inside the copied candidate.
Direct CLI checks include valid explicit history plus missing feature/value,
zero attempt, duplicate mode, mis-cased mode, `--opening` collision, unsafe slug,
and nonexistent round.

The final hash-pinned runner execution completed with exit 0: 2 expected RED
reproductions, 36 GREEN precheck assertions (both runtimes and both states),
30 unchanged ADR-generation regression assertions, and 18 direct CLI assertions.
Its final output was `owner_history_unchanged=true; failures=0`. These results
apply to the final patch and runner hashes below, not an earlier v2 execution.
The four product source paths also had an empty `git diff --stat` after testing.

Independent-review limitation (reported after this run): the reviewer found a
legacy compatibility regression absent from this runner's coverage. For legacy
BLOCKED history without an ADR extension, Pending/no-tasks passed both original
prechecks but was rejected by both v2 prechecks because explicit history requires
the binding extension. This is reviewer-reported reproduction, not an additional
author-run test. The Pending forged-count hole is reported closed, but v2 is not
accepted for application. Candidate changes and helper generation are stopped
pending the owner's direction; the frozen patch and runner remain unchanged.

## Hash pins and application boundary

| File | SHA-256 |
|---|---|
| Original impl precheck Bash | `9c79ab9c9cc821a7a4a36df713633063321a34573f320c7b235d5761db89f621` |
| Original impl precheck PS1 | `72e03cfad7d35f8eb444fdd8db82b2aab705bdc33882e3dd4750d4a8017a47c4` |
| Original workflow-state Bash | `001f6962590b7d9dc9a831d8d90d7171174cca6d890e94b376881ab0193bd85f` |
| Original workflow-state PS1 | `13351170ba1284d2fa1eb0d096d6e5faf506e3ce0a3a22a3cb81d09b10a028db` |
| v2 patch | `23b6de2e8887170f5ae827b658162ab4439408182417cf2c37ed1377962db17e` |
| v2 fixture runner | `4747d2b0ed21ff76e4859209cbe9a7a462e297d8541c80d0c2061342dc4a1b61` |

Product source application: NOT APPLIED. Existing dirty changes, design, old
verdicts, ledgers and task states were preserved. Read-only patch dry-run exited
0. Human-apply helper: NOT CREATED. No review launch/reservation, baseline
installation, formal approval, Windows-native run, full workflow regression suite,
exact-final-head CI, Git operation, or Done transition is claimed.
