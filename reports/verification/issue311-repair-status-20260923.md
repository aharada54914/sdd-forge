# Issue #311 repair status

## Reproduction

On `codex/t002-failure-diagnostics`, the first reservation-only patch is
present, but the branch predates the full scratch-root contract on
`origin/main`:

- `python3 tests/issue311-scratch-isolation.tests.py --repo .`: **PASS 1 / FAIL 27**
- `bash tests/review-agent-isolation.tests.sh`: fails when the new check reads
  an uninitialised `scratch_root` under `set -u`.
- `issue311-fixture-followup-20260923.patch`: does not apply at line 393
  because the branch lacks its annotation/WFI-034 fixture context.

The fixture failure is therefore a baseline mismatch, not evidence that the
follow-up patch itself is syntactically invalid.

The reproduction was repeated after the failed apply and remains **PASS 1 /
FAIL 27**; no protected file was changed by the agent.

## Candidate verification

The complete candidate aliases, based on `origin/main` plus the new evaluator
reservation requirement, pass independently:

```text
PASS: 28; FAIL: 0
```

This covers Bash and PowerShell clean reservations, missing roots, equal and
ancestor/descendant overlaps, historical records, tampered/deleted snapshots,
and later reuse.

The candidate `tests/review-agent-isolation.tests.sh` was also re-run after
the failed patch attempt: **PASS 26 / FAIL 0** (Bash and PowerShell).

## Human-only application

Protected validators and critical fixtures cannot be written by the agent.
The guarded application script is:

```sh
cd /Users/jrmag/sdd-forge
ISSUE311_APPLY=1 bash reports/verification/issue311-human-apply-20260923.sh
```

It backs up the five protected files, installs the verified candidate aliases,
takes the reviewer-isolation fixtures from `origin/main` instead of applying
the stale follow-up patch, runs syntax checks, then runs the 28-case contract
suite and the existing isolation suite. It does not commit, push, merge, or
change review status.

Candidate script SHA-256 (after preflight hardening for pwsh and origin/main fixtures):

```text
e361d15b37c4a8cbb63b6c6920742410cd08ca1ace22cc2ae1b391aea8ec8aa5
```
