# RT002 root checkout regression attempt

Readback of the user's three-file application matched all expected SHA-256s:

- verifier: `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`
- Bash suite: `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c`
- PowerShell suite: `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd`

Both suites were started in the primary checkout on 2026-10-03. They reached
the self-registration check, which executes `bash tests/run-all.sh --list`.
That checkout's older runner has no `--list` handling: its loop at line 153
executes the full inventory. Both attempts therefore started unrelated suites
instead of obtaining the expected list. The coordinator terminated only these
two newly started process trees (18 processes observed). These runs are
INTERRUPTED, not PASS; neither proves current-root regression completion.
The final Bash exit was 1 (101 PASS / 883 FAIL after interruption removed its
temporary directory); PowerShell exited 143. Those post-interruption failures
are contaminated and must not be counted as verifier regression findings.
Nested suites also reported missing fixture files, so concurrently executing
these old full runners is not a valid isolated verification strategy.

The bounded integration checkout already has the inventory-backed runner and
its `--list` branch. Do not copy its whole runner into the dirty primary tree:
the change also depends on `tests/suite-inventory.posix` and other integration
work. Complete validation against the coherent integration checkout, and
reconcile the primary checkout through the normal reviewed integration path.
No production source, approval, ledger or review verdict was changed here.
