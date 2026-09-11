# RT-20260908-004 lexical boundary baseline — 2026-09-09

Status: RED baseline extended; not implementation completion or a formal PASS.

The existing approved shared admission suite now has thirteen additional modes,
each exercised with both actual validators and both impl reviewer roles: 52 new
executions, 148 total. The previous 96 executions remain present. Only the test
fixture table and mode selection changed; no protected validator was changed.

New positive modes: two preceding backslashes (even escape count), three-space
indentation, and a tilde fence closed by a longer matching run with whitespace
suffix before a real declaration. New paired empty-set/injected-member modes:
leading tab, an unclosed longer inline span, malformed filename suffix, too-short
fence closing run, and a non-whitespace suffix on an apparent fence close.
Expected sets are explicitly assigned, not computed by a duplicate lexer.

## Actual checks

- `rtk proxy bash -n tests/impl-review-adr-inputs.tests.sh`: exit 0.
- `rtk proxy bash -o pipefail -c 'bash tests/impl-review-adr-inputs.tests.sh 2>&1 | tee /tmp/rt004-lexer-boundaries-20260909.log'`: terminal exit 1,
  **84 passed / 64 failed**. Handle 46560 is terminal; do not poll or restart it.
- Independent count of `ok:` and `not ok:` lines: 148, matching the summary.
- `rtk proxy git diff --check`: exit 0.

This ran Bash and PowerShell on macOS, not native Windows. Twelve new failures
are the three positive modes crossed with the two runtimes and two roles; each
is rejected as a real but role-unlisted ADR path. Forty new negative/empty-set
cases pass. These passes do not prove a lexer exists: current blanket rejection
of ADR entries also rejects unauthorized injections. Rerun the entire suite
after positive admission is implemented. The earlier 52 failures remain; do not
rewrite their evidence or report this as a passing repair.

SHA-256:

- `tests/impl-review-adr-inputs.tests.sh`: `3fd1c7abbd1fef99c6769f6217f5ad85ea26e573f9b3e7e3c5045b2a897818b7`
- `/tmp/rt004-lexer-boundaries-20260909.log`: `f9a460c536f599cef3bdb84d7bc6d58be9265aef7cbe78855acada466fc2be2d`

## Primary review and next action

Primary review under the reviewer skill found no Critical issue in the bounded
test additions. Warning: admission fixtures are not complete persisted-contract
or task-stage fixtures; positive baseline failure currently occurs at the
allowlist before later consistency validation. Mixed fence characters, additional
delimiter boundaries, filesystem/reparse-point cases, and complete precheck
serialization still need coverage in the final runtime package. This is not an
independent security review or a quality-gate decision.

Continue the already approved RT004 runtime human-application patch, including
both admission validators, precheck generation/verification and downstream
consumers. Do not apply the existing incomplete five-document patch alone. The
recorded protection denial remains in force: no renamed/copied validator or
alternate wrapper was used. Preserve all historical failures and real ledger
records. Formal review and native mandatory CI remain prerequisites to merge.

Fresh GitHub observation: seven open PR heads remain unchanged; all listed
Actions checks are terminal. PR400's published head has all 25 Actions checks
successful, but its uncommitted review amendments are not covered. PR245 has
no Actions checks and is conflicted; the other five PRs have failed checks.
No CI rerun, commit, push, merge, issue closure or task-state change occurred.
