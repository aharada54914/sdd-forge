# Issue #423: applied owner-worktree regression

Date: 2026-10-01
Base commit: 06bc32cc26f2d67adb02e827610b5230e1658f72
Result: focused regressions passed; formal quality verification and delivery pending.

This addendum supersedes the owner-application-pending statements in the
dated migration handoff. It does not change historical verdicts or task status.
The human applied six Registry/Resolver targets. Readback matched:

| Targets | SHA-256 |
| --- | --- |
| Canonical and vendored capability Registry | 42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1 |
| Resolver and A5 human-copy Resolver | ae27deb32d5af3d31dcbfd505812fd737603a9d682476451a855d48fb36ed511 |
| Generated gate capabilities | e9db61b7a9eeb28c1c50668e017fd8d570e490684daf68bc5d98f5348b0a31e1 |
| A5 human-copy manifest | cde02121eed5f7d0e9726c77b223bc72ff5e462cbd139bfcdcda45f09178ec5d |

## Regression repairs

Three test drivers retained assumptions about the illustrative capability
being present in production. Provider-neutrality cases now use the existing,
schema-validated example fixture; the actual Registry still has its own
provider-neutrality assertion. Missing-implementation and legacy-obligation
baselines use the retained pre-migration Registry. New assertions require the
applied canonical Registry to validate and match the approved candidate.
No rejection assertion, iteration count, or validator check was removed.

Observed RED before these repairs: contract boundaries had 19 IndexErrors
across 28 methods; registration had one failure; migration had three failures.
These were stale test assumptions after the approved application, not proof
that production should again contain the nonexistent migration checker.

## Executed in the owner checkout

All commands below used `rtk proxy` and returned exit 0.

| Command | Result |
| --- | --- |
| `python3 specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py -v` | 28 passed |
| `python3 specs/sdd-domain-multitarget/verification/T-002/registry-registration.tests.py -v` | 3 passed, 2 pre-application candidate-only cases skipped |
| `python3 specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/registry-migration.tests.py -v` | 11 passed |
| `bash tests/resolve-project-context-cli.tests.sh` | 13 passed, 0 failed |
| `bash tests/resolve-project-context-lite.tests.sh` | 18 passed, 0 failed |
| `git diff --check` | No whitespace errors |

The separate paired-regression report records the earlier, larger regression
run against the same six applied hashes. Those checks are not rerun or added
to the owner-run counts here. macOS PowerShell is not native Windows evidence.

## Formal-review blocker and resume point

The quality-gate launch contract requires the canonical identity ledger to
already contain the invoking implementation identity
(`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:184`). Neither the
owner ledger nor the root checkout ledger contains the recorded T-001/T-002
implementation IDs (`sdd423-t001-20260928-737dfb49` and
`sdd423-t002-20260928-b2e4033f`). No retrospective reservation was fabricated.
The original implementation reports also cannot be rewritten to claim later
repair bytes: new evaluator inputs need a valid post-fix artifact declaration
under the same skill's lines 161–176.

Next: recover a legitimate implementation-identity chain and declare current
post-fix hashes, then reserve a fresh isolated evaluator and run the formal
gate. Keep RT-20260930-001 open until that gate is complete. T-003 must not
start by assuming T-002 is Done. Current-head CI, native Windows checks,
merge, and post-merge confirmation remain unperformed for this checkpoint.
