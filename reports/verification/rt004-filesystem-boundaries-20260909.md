# RT004 actual filesystem admission baseline

Date: 2026-09-09
Status: RED; not implementation completion, independent review or quality PASS.

Approved scope: RT-20260908-004 filesystem rejection regressions. The existing
shared test now adds FIFO, directory, symlink and missing-file modes for both
actual validators and both implementation reviewer roles: 16 additional cases,
164 total. All earlier 148 cases remain. Product validators are unchanged.

Each fixture hashes regular ADR bytes before replacing the fixture entry. FIFO
contents are never opened by fixture construction. The FIFO invocation runs the
actual repository validator in a new process group with a 15-second watchdog;
a timeout returns 124 and cannot count as a successful rejection. Signal and
launch-failure exit codes likewise cannot satisfy the negative assertion.
Every negative result must still preserve the fixture ledger hash.

## Review and executed evidence

Primary review found a test-infrastructure false-positive risk: Popen launch
failure could return 1 and be mistaken for product rejection. The test now
reports launch OSError as 125; a timeout/kill race handles ProcessLookupError
but still reports timeout, never success. This source review is not the formal
independent security review of the product correction.

- `rtk proxy bash -n tests/impl-review-adr-inputs.tests.sh`: exit 0.
- `rtk proxy git diff --check`: exit 0.
- `rtk proxy bash -c 'set -o pipefail; bash tests/impl-review-adr-inputs.tests.sh 2>&1 | tee /tmp/rt004-filesystem-boundaries-reviewed-20260909.log'`:
  terminal exit 1, **100 passed / 64 failed**. Handle 7608 is terminal.
- Independent output count: 100 `ok`, 64 `not ok`, including 16 `fs-*` passes.
- Earlier pre-review run handle 31124 also ended exit 1 with 100/64; its log is
  `/tmp/rt004-filesystem-boundaries-20260909.log`. Do not poll either handle.

SHA-256 of final test source:
`f8ad416e14f68722e9bb28e81916970dc6e97116c04c0fd2712743885bf9dbff`

SHA-256 of reviewed-run log (also identical to first-run log):
`a77ebdb10968c2bc6a70d7d3f6e69f9d4d3851cc3cc418ddaa9116de6d2b5340`

The unchanged 64 failures remain genuine missing product behavior. Current
blanket ADR rejection also rejects these filesystem entries; their passes do
NOT prove the unused candidate path helpers work. Candidate execution was not
attempted. The tests must pass together with valid ADR acceptance after the
complete product repair. Runtime environment was macOS Bash and PowerShell,
not native Windows. Timeout and failed-launch branches were source-reviewed,
not experimentally fault-injected. Socket/device fixtures, parent reparse/case
checks, complete-set consumers and downstream contract tests remain required.

## Integration state

Fresh `gh pr list` observation: all seven open heads unchanged and no live
CheckRun. PR400 has no failed CI but unresolved formal findings; PR245 is DIRTY
with no Actions evidence. PR401/394/390/381/371 retain failed checks. No check
was waived or restarted. No commit, push, merge, issue closure or frozen review
state modification occurred. Continue the complete approved RT004 patch data;
do not ask the human to apply an incomplete package or bypass protection.
