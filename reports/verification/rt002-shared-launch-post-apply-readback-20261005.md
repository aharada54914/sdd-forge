# RT002 shared-launch post-application readback — 2026-10-05

Owner checkout: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`
HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`
Scope: post-application local readback and original-path regressions only. No evaluator reservation, formal quality-gate verdict, installed-host activation, CI, or Done decision is claimed.

## Application readback

The maintainer reported running `reports/verification/rt002-shared-launch-human-apply-20261004.py --apply` and a successful 11-target final-hash readback. This record independently checked the current owner bytes against the fixed `candidate-hashes.json` and `binding-followup-hashes.json` proposed SHA-256 values, with the second manifest taking precedence for seven shared paths. All 11 target paths were present as files and matched the final hashes (exit 0); this independent check did not use a no-follow file-type test:

| Target | Observed and expected final SHA-256 |
|---|---|
| `.github/workflows/test.yml` | `685f84399694b3daf355e0f92e6e1fc33bd36d072a3e1e2c5fc628a506c02ada` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1` | `92051fb870653bfbefc548d014af4ff91e6e2e4403bb51fc4c556a794b04056f` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` | `33ae6b9e80338715a3e607eaf50fdee3ad63a437d1077698dd1ba277b80d577c` |
| `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` | `d0326f3617f0bf6de6ba7f99d7edc2388c79a6731866328133cff7bb1815b722` |
| `plugins/sdd-review-loop/references/review-context-boundary.md` | `5ae94f4e3ba0d19c0765e7252b2fa1c660eb44a8cf7c8312f0986959b16cc24d` |
| `tests/issue311-scratch-isolation.tests.py` | `257c55dec7d8ab16af355317c723534bf13cf2e22c992255ef0bef688e5bf39f` |
| `tests/review-agent-isolation.tests.sh` | `c4317193451966dd9b55ba7d22c200a1ce5269d121aaca72907359018d07dd7f` |
| `tests/review-context-boundary.tests.sh` | `e99614b63db1bf1af2b41683003500f83110681268b35492ef18ce589c75f496` |
| `tests/review-implementation-binding.tests.py` | `d7af8955d31908e0a99d897098a62dff69752240bbb44f3c37a50ca55ae2165d` |
| `tests/review-scratch-history.tests.py` | `f7508af43ff163a0d4ad97835e6574a1e658bfc6a54a6f4bcdb4b24bb78bbfe8` |
| `tests/run-all.sh` | `30a0caf034ba9414a1760a0603085056a410f45a68b0d03cb64336e83d79075a` |

The helper's default read-only command stopped at `.github/workflows/test.yml` with `STOP: unexpected target bytes/presence` (exit 1): it intentionally checks the *before* hashes and is not an after-state verifier. No second application was attempted. The owner status lists `reports/verification/rt002-shared-launch-backup-pqlunur1/`; this record does not independently verify backup contents or claim a restoration run.

## Original-path post-application regressions

All commands ran in the owner checkout. These are fresh post-application executions, distinct from the 2026-10-05 pre-application baseline and older #423/fixture results.

| Command | Exit | PASS | FAIL |
|---|---:|---:|---:|
| `rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge` | 0 | 60 | 0 |
| `rtk proxy python3 tests/review-scratch-history.tests.py --repo /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge` | 0 | 26 | 0 |
| `rtk proxy bash tests/review-agent-isolation.tests.sh` | 0 | 26 | 0 |
| `rtk proxy bash tests/review-context-boundary.tests.sh` | 0 | 84 | 0 |
| `rtk proxy python3 tests/review-implementation-binding.tests.py --repo /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge` | 0 | 34 | 0 |

The five suites total 230 PASS and 0 FAIL. The runner output covered local Bash and PowerShell cases. `review-context-boundary.tests.sh` also reported 32 citation anchors verified. The implementation-binding suite covered Bash and PowerShell (17 cases each), including valid reservation and malformed input rejection. No native installed-host dispatch is inferred from these suites.

## Formal gate boundary

`specs/epic-189-a1-rt002-repair/tasks.md` currently records T-001 as Approved / Implementation Complete and T-002 as Draft / Planned. The owner `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` requires fresh, pre-reservation implementation provenance: current hash-pinned inputs, actual implementation run/session, a `task-input-manifest/v1`, and a canonical absolute implementation scratch root. The existing canonical T-001 report is a report-assembly run with a relative scratch declaration, not that new run. Its historical bytes are archived in `specs/epic-189-a1-rt002-repair/verification/T-001/provenance-recovery-candidate-20261004/canonical-report-before-recovery.md`; do not rewrite either historical report or handoff.

Next authorized sequence: isolated implementation revalidation against pinned current inputs; new noncanonical report and task-input manifest carrying observed identities and hashes; independent hash checks and canonical report adoption; only then prepare the evaluator's one-role manifest with distinct run/session/scratch and current ledger chain, preflight it, reserve exactly once, and launch the isolated evaluator. No reservation or formal quality-gate was made in this readback. T-001 still needs its own original functional-suite and installed-activation evidence evaluated under that fresh gate. T-002 release, Windows, latest-head CI, merge, and post-merge obligations remain separate and Draft.
