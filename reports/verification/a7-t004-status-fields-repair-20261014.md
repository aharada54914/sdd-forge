# T-004 status-field repair preflight — 2026-10-14

Run ID: a7-t004-status-fields-repair-20261014
Task Attempt Count: 3

This non-frozen implementation addendum preserves the existing task attempt;
the bounded independent-review correction is repair loop 1 of at most 3.
No new formal gate attempt, reservation, approval or Done status is asserted.

Authority: parent relayed user-approved continuation of A7 T-004, including
approved-scope implementation repairs and fresh independent Codex evaluation
under a separate-evidence exception. Product-hook execution is not required by
that exception. Legacy ledger and frozen evidence remain unchanged.

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`, detached, existing dirty tree.
Risk: high (T-004 classification retained). Both structural suite twins are
already dirty; preserve all existing content except the scoped field extractor
correction. New regression evidence lives in the T-004 verification directory.

## Preflight evidence-field counterparts and failing tests

| Persisted/compared field | Counterpart | Required mismatch test before implementation |
| --- | --- | --- |
| lite-track tasks.md `Status` field-name set | unchanged tasks-lite.md `Status` | Remove bare `Status:` only from isolated F2 positive control; suite must fail the tasks.md status-field comparison |
| lite-track tasks.md `Approval` field-name set | unchanged tasks-lite.md `Approval` | Remove bare `Approval:` only from isolated F2 positive control; same named failure required |
| mutation killed/survived classification | nonzero suite exit plus exact named diagnostic | Existing sourced classifier rejects success exits and unrelated failures; each isolated mutation is classified separately |

The new driver must demonstrate the current false-GREEN before modifying either
suite. Required focused GREEN: two mutations killed in each runtime and an
isolated positive control containing both fields passes. Run unchanged corpus
activation regression in both runtimes, but expect it to expose the historical
F2 defect rather than treating it as GREEN. Also run existing five activation
mutations in both runtimes; syntax/parity sweep; independent fresh-input review.

Preflight correction: F1 does not include tasks.md; F2 includes tasks.md but
already lacks both bare fields. The first driver execution exited 2 at its
source-change guard (no field to remove); this was a driver error, not TDD RED.
The corrected driver constructs a positive F2 control only inside disposable
scratch and removes one field at a time. It does not update the recorded corpus.
After extractor repair, the original F2 fixture must remain an explicit known
failure until its recorded-response provenance is lawfully repaired/refreshed.

The separately discovered YAML-value parsing concern is not repaired by this
field-name change and must not be reported as resolved. No YAML dependency,
grammar narrowing, template/corpus refresh, or protected workflow edit is in
this correction.

## Executed result and independent scoped review

Before correction, `status-field-mutation-20261014.sh sh` and `ps1` each
exited 1 with `0 killed, 2 survived`: both missing-field mutations produced
success exits (77/0 Bash and 84/0 PowerShell). This is observed TDD RED,
not an infrastructure failure.

Only the prefix group in `status_fields` / `Status-Fields` was made optional
(`tests/structural-compatibility.tests.sh:132`, `.ps1:126`). Existing
prefixed names remain detected; bare `Status` and `Approval` are now included.

| Command from owner (each prefixed by `rtk proxy`) | Exit | Actual result |
| --- | --- | --- |
| `bash specs/epic-195-a7-compatibility/verification/T-004/status-field-mutation-20261014.sh sh` | 0 | positive control 77 passed, 0 failed; 2 killed, 0 survived |
| same command with `ps1` | 0 | positive control 84 passed, 0 failed; 2 killed, 0 survived |
| `bash specs/epic-195-a7-compatibility/verification/T-004/activation-regression-20261004.sh sh` | 1 | retained original F2: 76 passed, 1 failed |
| same command with `ps1` | 1 | retained original F2: 83 passed, 1 failed |
| `bash specs/epic-195-a7-compatibility/verification/T-004/activation-mutation-20261004.sh sh` | 0 | 5 killed, 0 survived |
| same command with `ps1` | 0 | 5 killed, 0 survived |
| `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-195-a7-compatibility` | 0 | workflow-state: ok |
| `bash plugins/sdd-quality-loop/scripts/check-traceability.sh specs/epic-195-a7-compatibility/traceability.json . require-evidence` | 0 | 7 links passed |
| `bash -n specs/epic-195-a7-compatibility/verification/T-004/status-field-mutation-20261014.sh tests/structural-compatibility.tests.sh` | 0 | syntax accepted |
| `git diff --check -- tests/structural-compatibility.tests.sh tests/structural-compatibility.tests.ps1 specs/epic-195-a7-compatibility/verification/T-004/status-field-mutation-20261014.sh reports/verification/a7-t004-status-fields-repair-20261014.md` | 0 | no whitespace diagnostic |

The activation mutation results require each exact named diagnostic, but the
underlying original F2 is independently RED; these five results are detection
evidence, not an overall baseline GREEN. F5/F6 remain governed SKIPs, not
executed behavioral PASSes.

Fresh-context independent Codex reviewer `status_field_diff_review` returned
scoped PASS with no new finding. It extracted the functions from the actual
files and independently confirmed five bare/prefixed positive examples and
four lowercase/uppercase negatives identically in both runtimes, verified the
two hashes, and inspected the driver classifier/source isolation. It did not
rerun the entire mutation driver. Its conclusion does not change the broader
T-004 NEEDS_WORK, formal status, ledger, CI or hook status.

Current suite hashes: Bash
`54c85bdc012b603a49e5dfd829af7015da0ec1111b8e32decbdc3cc84118a4b9`;
PowerShell
`8893fb86e57f2cdf2c7f7c578ff6e9c748ac2b125c0c4f70e27f819b944cd3f1`.
The old declaration and first independent-input manifest remain untouched;
their two old suite hashes no longer bind these current bytes. Use new
inputs for any later evaluation; do not reinterpret the old manifest as
current. The other 18 of 20 declaration rows were rechecked unchanged.
