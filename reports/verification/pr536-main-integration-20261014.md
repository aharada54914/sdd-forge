# PR 536 main integration verification

Scope: existing strict literal proxy role-read allowance; protected/high-risk.
Owner: isolated PR 536 integration checkout, branch codex/pr536-integration-20261014.
Starting PR head: 891dcdd9561dfa2feaa854c670058af06d7961d5.
Integrated main: d9c8e7acf11ab93b98fd2b09562a7383a27da67b.
Checkout was clean before merging main without committing; incoming changes are
preserved. No approval, historical verdict, installed baseline or task state changed.

## Executed merged-tree regressions

All commands exited zero:

- Bash guard-parity: 114 passed, 0 failed.
- Bash guards: 135 passed, 0 failed.
- Bash guard-negative-corpus: 47 passed, 0 failed, 0 skipped.
- PowerShell hooks: Hook guard tests passed.
- Bash phase2-guard-invariants: 42 passed, 0 failed.
- PowerShell phase2-guard-invariants: 55 passed, 0 failed, 1 existing skip.
  TEST-013 installed runner-refresh assertions remain skipped; no installation
  was changed. This is not installed-host verification.
- Human-copy mirror freshness: 6 passed, 0 failed, 19 informational pending
  unapplied candidates. Manifest integrity and applied byte parity passed.
- git diff --cached --check: passed.

## Independent review

A fresh read-only Codex reviewer without inherited conversation reviewed the
13-file PR diff against the integrated main, including all three runtime parsers,
call order, option/quote boundaries and persisted refusal regressions. Result:
PASS, no findings. It independently ran Bash parity (114/0), PowerShell hooks,
mirror freshness (6/0, 19 informational pending) and whitespace validation.

This uses the user's independent Codex review exception; it is not an entry in
the formal SDD review ledger or a task Done verdict. Historical evidence remains
unchanged. The earlier ephemeral 54-case driver was not rerun here.

## Remaining delivery checks

Exact committed-head CI, merge and post-merge CI are pending at authorship.
Local PowerShell execution does not establish native Windows behavior.
Product installation and live host activation are not claimed by this repair.
