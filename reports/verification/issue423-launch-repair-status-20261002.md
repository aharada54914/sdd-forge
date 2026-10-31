# Applied launch candidate: follow-up verification

## CI coverage audit (2026-10-02)

The migration CLI regression is already registered through
`tests/registry-migration-cli.tests.sh` in `tests/suite-inventory.posix`.
`bash tests/run-ci-unwired.sh --list` exited 0 and included that wrapper;
the workflow's required POSIX unwired shards consume this inventory.
No duplicate CI registration is needed. This listing is coverage-routing
evidence, not a new test execution or proof for uncommitted recovery changes.

## Approved recovery follow-up (2026-10-02)

The human approved a limited recovery contract preserving the old implementation
record while admitting newly executed, isolated, hash-pinned revalidation.
The quality-gate skill now describes this recovery using the existing manifest
and validator contracts. The reserve fixture covers rejection of an undeclared
supersession archive and acceptance only after exact Outputs/hash declaration.
Its Bash syntax check and both-shell fixture execution exited 0. Independent
read-only review found no issues in this limited diff; this is not a formal
quality-gate verdict. Parent `git diff --check` also exited 0.

The parent ran the current T-001 inventory suite: 17 tests passed (exit 0).
This owner-worktree execution is not isolated recovery evidence.

Fresh revalidation agent `/root/issue423_t001_fresh_revalidation` allocated
`/private/tmp/issue423-t001-revalidation.k6ucSM`, but its read-only input/hash
collection was denied by PreToolUse before execution. The directory is empty;
no new manifest, snapshot, report, reservation or formal verdict was generated.
The proposed run identifier `issue423-t001-revalidation-k6ucSM` therefore does
not identify a completed execution. Historical canonical reports remain intact.
Recovery execution, formal review, current-head CI and merge remain pending.

The earlier statement below that the recovery contract was not implemented is
historical and is superseded only by this limited contract update, not by a
claim that recovery execution or delivery succeeded.

## Subsequent owner-worktree verification (2026-10-02)

The three-file repair is now applied. Readback SHA-256 values are:

- validator Bash: `9c9161adfea720f21809b8d1b67b2749c579eb44f5a7f778968228824b3dc4ef`
- boundary reference: `5f9ce08931640ab5f461223ce7ca1aa7fc92dde89266320d4e847f29ff7ac504`
- boundary suite: `26b225f91180b1817a010c3e6ef5b9408974f8c41548a965b008beceae53ca78`

The helper's original-input hash check refused a repeat application; direct
readback matches all three candidate hashes. No repeat application was made.
The earlier pending-application and failing-test notes below are historical.

Executed in this owner worktree on macOS, all with exit 0:

| Command (via rtk proxy) | Observed result |
| --- | --- |
| `bash reports/verification/issue423-quality-launch-reserve-fixture.sh` | 13 negative cases and positive control passed in both Bash and PowerShell; disposable ledgers only |
| `bash tests/review-context-boundary.tests.sh` | 32 citation anchors; reservation/verification checks; final investigation matrix 84 PASS / 0 FAIL |
| `python3 tests/issue311-scratch-isolation.tests.py --repo .` | 28 PASS / 0 FAIL |
| `python3 tests/review-scratch-history.tests.py --repo .` | 26 PASS / 0 FAIL |
| `bash tests/review-agent-isolation.tests.sh` | sequential isolation passed; included history checks 26 PASS / 0 FAIL |
| `git diff --check` | no whitespace errors |

Command output was observed through the execution tool; this is a result summary,
not a saved full-log artifact. These fixture results do not establish a live
evaluator launch, native Windows execution, formal quality verdict, current-head
CI, or merge. No historical identity or report was reconstructed as fact.

### Remaining live-launch blockers

Read-only audit confirmed matching task/run/session identities in the T-001 and
T-002 handoff manifests and implementation reports. It did not establish the
absolute historical implementation scratch roots: both reports record relative
paths (T-001 line 48, T-002 line 60). Saved absolute test-snapshot paths are not
proof of the original worker scratch root. The Bash validator requires the
absolute root before reservation (lines 648–658).

T-002 additionally has a manifest digest but no required `Input manifest:`
path/digest citation (implementation report line 68; validator lines 946–951).
The implementation report is frozen by quality-gate/SKILL.md lines 163–171.
The gate-time discrepancy mechanism cannot repair these pre-reservation
conditions because no evaluator may yet be reserved.

No live reservation was attempted. Historical outputs remain unchanged. A
prospective recovery contract is needed; it must preserve the missing-evidence
finding and require newly observed execution in an explicit isolated scratch
root with a hash-pinned manifest, rather than assert a historical root or relax
the ordinary launch checks. This report does not approve or implement that
contract, and does not grant a quality verdict.

## Earlier verification history

The eight targets match the original human helper's OUTPUTS hashes. Reverse
patch check and whitespace check passed. Application is not test success.

The Bash evaluator path calls `admission_json_members` without its required
filename at line 928. Under `set -u`, this exits before the intended diagnostic.
PowerShell scratch tests pass; Bash accounts for all 13 failures in each of the
scratch-isolation (15 passed / 13 failed) and scratch-history (13 / 13) suites.
The boundary suite also detects stale citations in its document and anchors.

The primary agent's one-line apply_patch was refused by PreToolUse. No alternate
executor applied it. `issue423-launch-repair-human.py` prepares that call repair
and four citation remappings in the boundary document and test (three files).
Its default read-only pin/count check passed; --apply has NOT been executed.

The separate disposable reserve fixture constructed a double slash when TMPDIR
already ended with `/`. Trimming that separator fixes the fixture, not the
validator's path contract. After this applied fixture-only repair, missing
declaration, undeclared handoff, missing pinned input and altered manifest each
passed in Bash and PowerShell. The next case, mismatched_run, stopped with Bash
exit 1 and empty output, consistent with the uncorrected line 928. Later cases
were not executed. Production identity ledger and reviewer outputs are untouched.

After human application, run:

```sh
rtk proxy bash reports/verification/issue423-quality-launch-reserve-fixture.sh
rtk proxy bash tests/review-context-boundary.tests.sh
rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo .
rtk proxy python3 tests/review-scratch-history.tests.py --repo .
rtk proxy bash tests/review-agent-isolation.tests.sh
rtk proxy git diff --check
```

Use this checkout, not the dirty root checkout. Verify the helper's printed
candidate hashes before running. No reservation, task status, verdict, commit,
push, CI or merge was performed during this follow-up. Formal quality gate is
still pending; existing CI for the earlier commit does not cover these bytes.
