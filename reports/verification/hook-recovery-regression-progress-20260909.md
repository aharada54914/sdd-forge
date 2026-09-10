# RT-20260909-002 initial adapter regression slice

Date: 2026-09-09
Status: expected RED, not implementation complete or formal PASS.
Authority: the latest explicit semantic/recovery approval recorded in RT002.

## Supersession and safe continuation

This record supersedes the next-action advice in
`hook-diagnostic-handoff-20260909.json`: the semantic/recovery amendment is
now approved and independently scrutinized. Do NOT repeat that approval
request. Preserve the older record as historical context.

The old diagnostic-only human helper is now stale because its pinned test
hashes predate the new regressions. Do NOT direct the user to apply it.
Its hash checks should reject the current tests; do not remove those checks.
A combined reviewed candidate and a newly pinned human application helper
must replace it before any application. No old helper was executed here.

## Executed tests

Both original repository wrappers were tested, without executing copied or
renamed production validators. Logs were captured in this directory:

- `bash tests/check-hook-activation-handshake.tests.sh`:
  `hook-host-denial-posix-red-20260909.log`, 95 PASS / 22 FAIL, exit 1.
- `pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1`:
  `hook-host-denial-pwsh-red-20260909.log`, 94 PASS / 22 FAIL, exit 1.

Each suite retains the earlier 3 diagnostic-text failures. The new slice adds
20 assertions: 19 fail as expected and one passes (a last-false duplicate
cleanup record already cannot confirm, but is classified under the wrong
category). Existing three-runtime positive activation fixtures remain GREEN.
PowerShell ran on macOS, not native Windows. No live host challenge was run.

Observed missing behaviors:

1. Valid new-schema exact denial is unavailable (legacy missing-flag exit 65).
2. Seven explicit schema values fall through to otherwise valid Claude
   evidence and incorrectly activate under the newly approved contract.
3. Duplicate cleanup executed members are last-wins: false then true produces
   cleanup confirmed; true then false denies but not as unreadable evidence.

## Source identity and remaining work

- Unchanged production Python SHA-256:
  `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`.
- Shell suite SHA-256:
  `fef6f097b282430c4f3c466a02a2e177b1b707196c92462114a7eb7e91acef33`.
- PowerShell suite SHA-256:
  `15564d4e0eb33a0ef6fe226c96177fc93e150b2f62a06d2df221897aa13b5e27`.
- Scoped `git diff --check` succeeded.

This is an INITIAL slice, not the full reviewed matrix: add individual
nonce/raw-envelope/missing-field/extra-field/duplicate-member/runtime/type/
challenge-template cases before preparing the production adapter. Then carry
out candidate review, repair-specific formal provenance reviews, protected
human application, complete original-path GREEN verification and a fresh
installed-path native host challenge. The historical Done remains unchanged.
Ordinary independent static review by /root/hook_contract_security_review
verified both hashes and found no blocking harness defect. The reviewer
confirmed the 19 new expected failures and correctly serialized duplicates.
It identified an inherited minor looseness: PowerShell's Assert-Eq uses -eq.
The three NEW status assertion sites were therefore tightened with -ceq
before passing a boolean to Assert-Eq; unrelated legacy assertions are intact.

Revised PowerShell suite SHA-256:
`0bb79358049168e1bbfa955a904a8872906bafbe25a49ff45cac53bc559f8579`.
Its original-path rerun is captured separately in
`hook-host-denial-pwsh-case-sensitive-red-20260909.log`: 94 PASS / 22 FAIL,
exit 1, the same expected RED with exact-case assertions. Scoped whitespace
validation also passed. Neither this static review nor an expected RED closes
RT002.
