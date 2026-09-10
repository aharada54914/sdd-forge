# RT004 original contract identity: regression baseline

Status: limited baseline verified; RT004 remains open. No formal gate PASS.

## Change and execution

Added `history-pin-control` and `history-pin-forged` to the existing workflow
history suite. Existing cases remain in the default run. The optional
`--history-pin-only` selector runs only these two cases plus the legacy control
in each runtime; it does not replace any mandatory CI command.

Executed:

```bash
rtk proxy bash tests/impl-review-adr-inputs.tests.sh --history-pin-only
```

Final run: 6 passed, 0 failed, exit 0, session 33080 completed. Bash and
PowerShell ran on macOS; this is not native Windows evidence.
Full output: `/tmp/rt004-history-pin.d9KEgE`, SHA-256
`d09b4aa01c4d9c54f3fe79aa7574ef23dbd5305c11fd4318cbadc380628b1bce`.
Test source SHA-256:
`d89761dfcfbf11551ab80dacf2a19e6cc7233a26ce4d99e559cde294b1b382b7`.

## What this proves

The test runs the original validators, copies only fixture data/reference
documents and uses existing Git history at the original SCRIPT_ROOT. No
validator is relocated or extracted; no Git command is mocked; no commits
are created. For the selected original contract, the unique introducing
commit is `04cf0ad29001d7e58f7aea63a0f5cf631437af16` and is checked as an
ancestor of HEAD before the test proceeds.

The calibration reference has historical hash
`85c9c6ceb80e86ae54b4ccda64d00c2e84eda8241e315aaafba60ac2c6d3e851`;
after fixture-only growth its live hash is
`47a7ee51a9ca2cab24b73dc0776db8883788d58c11d188b86ba5826f042520a5`.
The fixture asserts these differ and both contract manifests pin the
historical bytes. The integrated verdict is restored to PASS, so the opening
NEEDS_WORK early return cannot substitute for the intended checks.

The negative fixture changes both contract and output calibration pins to
the same forged hash, checked to match neither live nor historical bytes.
Success requires exit exactly 1 and the exact stale-input diagnostic. It
also requires that runtime's positive history control succeeded first.

Parent review checked the original-path boundary, positive-control dependency,
preservation of the existing case list and the failure predicate. No Critical
defect was found in this limited addition. Independent lifecycle design review
is recorded separately; this is not an independent formal test review.

## Failed first run retained

Initial session 31857 returned 4 passed / 2 failed: both forged cases correctly
returned exit 1, but the test's diagnostic assertion accidentally omitted the
word `input`. The assertion was corrected to the actual supplied contract
diagnostic, without relaxing exit or rejection requirements. This was a test
assertion error, not the intended product RED. Session 14080 then passed 6/0;
the final run above additionally binds the forged case to its positive control.

## Limits and next action

- These are preservation tests for already-supported history semantics, not
  proof of a fixed snapshot lifetime or a TDD RED for the new lifetime change.
- The positive case reaches both the manifest loop and later calibration
  check. The forged case fails at the first one. A separate late-read mutation
  case is still needed to detect an original-JSON reread in the later helper.
- Investigation growth/non-growth, allocation/cleanup/signal behavior and
  deterministic capture-to-consumption mutations remain unverified.
- The 118-case workflow suite has not been rerun this step. Its last actual
  result remains 14 passed / 104 failed; do not combine that run with this one
  into an invented full-suite result.
- Production and composed candidate code were not changed. The candidate
  SHA-256 remains
  `fee3d720fc6b3517e5e4a9fe474d86bc838d6b62f684cec2b61e5b4da7ebff34`.
- No commit, push, merge, issue closure or review-verdict change occurred.
