# Issue 290: current regressions and remaining protected applications

Date: 2026-10-06. Owner: `/Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge`.
Observed HEAD: `badbb7aa5d16114be542c33018967c58770d1a41`.
This is a non-frozen coordination record, not a formal review or task verdict.

## Executed on current original paths

- `rtk proxy bash tests/validate-approval-sidecar.tests.sh`: **113 PASS, 0 FAIL**, exit 0.
- `rtk proxy pwsh -NoProfile -File tests/validate-approval-sidecar.tests.ps1`: **112 PASS, 0 FAIL**, exit 0, PowerShell on macOS (not native Windows).
- `rtk proxy git diff --check`: exit 0.
- `rtk proxy python3 -B reports/verification/issue290-minitems-suite-human-apply-20261005.py --check`: exit 0; `READY: exact source and patch pins; dry-run only; originals unchanged`.

The current original test hashes were remeasured after the runs and dry-run:

| Original | SHA-256 |
|---|---|
| `tests/validate-approval-sidecar.tests.sh` | `72511d69f5407e5f186beb3b32ebb8c5a0fa47b94807f319341f04429dad43e6` |
| `tests/validate-approval-sidecar.tests.ps1` | `a8ed8ee80504e1ff75fbe38c1f33e8a3e614b0c38906f38a88a2d6e19fa7eb09` |

No matching owner test/implementation process was observed before starting these regressions. Terminal output and exit codes were observed; complete raw logs were not saved in this run. No source, task status, verdict, reservation, or Git history was changed.

## Candidate results are separate

The earlier isolated candidate results of Bash **115** / PowerShell **114** are recorded in `issue290-minitems-registered-suite-20261005.md`. They are NOT current-original results. The two permanent minItems tests per runtime remain unapplied. The historical dispatcher-suite RED reconstruction was actually refused, as recorded in `issue290-minitems-suite-red-blocked-20261005.md`; it was not retried or routed through another executor.

## Minimum human operations

Both helpers below exist and their bytes were verified in this run. They independently check current target pins, retain backups, and require interactive confirmation. Stop if either refuses; do not force or substitute an older helper.

### 1. Permanent minItems regression tests (two files)

Helper SHA-256: `a63f2e4e147dc6ba3a53ed37a874f24673dff4dd71952eb967a81a92f767f04a`.

```sh
cd /Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge && rtk proxy python3 -B reports/verification/issue290-minitems-suite-human-apply-20261005.py --apply-human
```

Confirmation: `APPLY-ISSUE290-MINITEMS-SUITES`.
Then rerun both original-path suites and retain their output. This application does not reconstruct the historical RED case or grant a review PASS.

### 2. Native reviewer identity wording (two roles and boundary contract)

Helper SHA-256: `bb080598a6bb0c95d66a93895a288b7d53032f3d2924a913de067223896197d0`.
Current role/boundary hashes measured in this investigation match its before pins: `e114b7a6…`, `4f0add21…`, `b537052a…`.

```sh
cd /Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge && rtk proxy python3 reports/verification/issue290-role-identity-current-human-apply-20261005.py --apply-human
```

Confirmation: `APPLY-ISSUE290-CURRENT`.
Then run the ordinary precheck and fresh independent task-stage reviewers under the launch contract. Do not reuse diagnostic identities or prior outputs. This record does not perform or authorize duplicate reservations.

## Remaining delivery

T-001 is Approved / In Progress; T-002 through T-006 are Approved / Planned. Current task-stage evidence requires rebinding after the documented plan amendment. T-005 has no task dependency, but any implementation must use its own approved implementation context and current prerequisites; no T-005 implementation was started here. T-002/003/004/006 retain their declared dependencies.

The above tests do not prove formal review, quality-gate completion, native Windows behavior, CI, merge, or Done. After protected application, perform the focused original-path regressions, complete provenance review and T-001 evidence, then proceed in dependency order. Historical RED preparation remains a distinct unresolved evidence item, not silently satisfied by GREEN tests.
