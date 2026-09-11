# RT004: required-input omission rescued by a later contract replacement

Status: reproduced product RED; no implementation or formal PASS.

## Execution and observation

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --late-contract-only`

Session 61680 ended with exit 1: 4 passed / 1 failed. The failure is
`bash late-contract-rescue`, which returned 0 where rejection (1) is required.
Log: `/tmp/rt004-late-contract.A3Hzlp`, SHA-256
`b50a6054f389186300547a0b00d4da1cbe7d88875b192a9a96836d25a404e9fa`.

Source SHA-256:

- `tests/impl-review-adr-inputs.tests.sh`:
  `f66e61c292bfadf51b69e043cef83a03bd36362c455961678d4e5f694ae005ed`
- `tests/fixtures/adr-jq-read-boundary.py`:
  `e35f8e95734b0102204799d9a81a4bddfb0284ce9ba847de70a3e0ac334c1c7c`

This selector runs Bash legacy, complete-contract control, unchanged missing
contract, and late replacement, plus the PowerShell legacy control. It is
NOT PowerShell mutation coverage. Default execution also includes the three
new Bash cases; no existing mandatory case was removed.

## Counterexample and controls

1. Start with the existing completed workflow-state-integrity review data.
   Use real Git at SCRIPT_ROOT and the same legitimate historical calibration
   pin as the preceding history regression. Grow only the private fixture's
   live calibration so the historical fallback is necessary.
2. Complete-contract control: the actual original Bash validator succeeds.
   The boundary observer runs and reports identical before/after bytes.
3. Missing-input control: remove calibration from both role reservations and
   both reviewer outputs. Without replacement, the original validator rejects
   with `impl reviewer manifests omit required inputs`.
4. Replacement case: begin with the same incomplete data. After the real jq
   reviewer/output consistency check completes successfully, replace only the
   private fixture's contract with its complete original version. Both reviewer
   outputs still omit the input. The original validator incorrectly succeeds.

The replacement receipt records a change from
`1585f3059db6229ba541b9b2c73d855de78612c2d038154ba9ed45d33fd28191` to
`40034006d773c1d6aa8aa0e31108b50a7335b4b9bcaac42aae36bb9db060c2aa`.
The control reports the latter hash unchanged. Fixture-specific absolute paths
mean these hashes may differ in a subsequent run.

## Scope of the scheduling seam

Only the test's jq dependency is delegated through the observer. The observer
runs the actual resolved jq executable with unchanged arguments and inherited
standard streams, then preserves its exit status. It never substitutes a jq
answer. The boundary requires the actual impl-stage reviewer consistency
expression; a one-use receipt proves the boundary was reached. The negative
test additionally depends on both positive control and static omission rejection.

The validator executes at its original repository path. No validator is
copied, extracted, rewritten, sourced or run through an alternative denied
route. Only the private data contract is replaced; actual repository review
evidence, Git history, protected code and plugin cache remain untouched.

This is deterministic sequencing, not a timing sleep or probabilistic race.
It exposes a coherent-read defect, not arbitrary JSON-parser behavior. The
later calibration helper must read the verified snapshot for BOTH current and
historical manifest lookups, while resolving Git history from the original
contract identity. A direct helper mock would not prove this caller behavior.

## Review, failed setup and remaining work

Parent review checked delegation, fixture-only writes, control dependencies,
unchanged historical Git lookup and fail-closed boundary receipt assertions.
This is not independent formal review. Shell syntax check passed.

Preservation rerun after these additions:
`rtk proxy bash tests/impl-review-adr-inputs.tests.sh --history-pin-only`
completed in session 67796 with 6 passed / 0 failed, exit 0.
Log: `/tmp/rt004-history-recheck.EmFr59`. Bash and macOS PowerShell both
retain legitimate historical acceptance and forged-hash rejection.

Initial session 33490 ended 3/2 because the static omission test expected an
incorrect diagnostic string. The actual omission diagnostic above was confirmed
against supplied source and output, then used exactly. The late replacement
already returned incorrect success in that first run. Session 61680 establishes
the intended product RED after correcting the test-only diagnostic.

Stage-owned snapshot implementation and independent review remain outstanding.
This covers the later contract consumer, not mutations of each other captured
file, allocation/cleanup failures, signals or native Windows. A future validator
that rejects before this scheduled boundary needs an explicit earlier-rejection
test; lack of a receipt must not silently be counted as this mutation passing.
The full history suite was not executed here; do not combine partial runs into
a purported full-suite result. No commit, push, merge, issue closure, task Done
or review-verdict change was performed.

GitHub recheck in this turn: 11 open PRs, all returned running-check lists empty;
the heads and failed-check sets remain unchanged from the prior inventory.
No currently live CI job was found to wait on, and missing checks on conflicted
PRs were not interpreted as success.
