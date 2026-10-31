# RT002 T-001 public publication boundary (2026-10-03)

This is a public-safe, non-frozen summary, **not** the canonical implementation report, a replacement for any hash-bound original, a quality-gate input declaration, or a gate verdict. T-001 remains Implementation Complete; no independent quality-gate PASS or Done decision is claimed. T-002 retains native Windows, latest-head CI, merge, and post-merge obligations.

## PR-head implementation

The following three tracked files have no worktree difference from `HEAD` at this publication audit. The SHA-256 values are the canonical T-001 report's exact source/suite values; CI can recompute them on the published PR head and run both original-path suites there.

| Tracked path | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` | `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` |
| `tests/check-hook-activation-handshake.tests.sh` | `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` |
| `tests/check-hook-activation-handshake.tests.ps1` | `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd` |

Local owner observations record Bash 984 PASS / 0 FAIL and PowerShell 985 PASS / 0 FAIL with exit 0. These are local observations; CI must generate its own result. Native installed-owner refusal and isolated restore/refusal checks were observed locally, but their original evidence is not published by this summary.

## Exact proposed staging boundary

For a minimal publication of this summary, stage **only** `specs/epic-189-a1-rt002-repair/verification/T-001-public-safe-summary-20261003.md`. The three implementation files above are already in `HEAD` and need no new staging. This stage proposal does not include `AGENTS.md`, `specs/workflow-state-registry.json`, the canonical/legacy implementation reports, any RT002 verification originals or raw logs, helper scripts, host responses, or unrelated dirty files. No staging, commit, or push was performed here.

This minimal set allows public CI to check the three published file hashes and execute their test suites. It **does not** allow public CI to replay the complete T-001 SDD quality gate: the canonical report's `## Outputs` includes original evidence files intentionally withheld from public GitHub. Omitting them leaves those path/hash references unresolved in a public-only checkout. Sanitizing an original changes its hash; neither a sanitized derivative nor this summary may be substituted under the original path/hash or added silently as a gate input. The full original-byte gate remains local to the authorized checkout and its exact manifest.

The published summary is permitted as a non-frozen addendum by `AGENTS.md:60-63`. Formal evaluator admission is stricter: `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:160-177` limits the manifest to exact paths and hashes declared in the implementation report (or a legitimately pinned post-fix gate report), and `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:820-885` requires each candidate to be an existing regular file whose actual hash matches. Thus public-safe summary publication is not formal gate evidence. The existing private evidence and report must be kept unchanged for local review; the denial at evaluator launch remains a refusal, not an invitation to bypass it.

## Publication exclusions requiring separate treatment

The local audit found host-local absolute-path patterns in the following untracked source records: `reports/implementation/epic-189-a1-rt002-repair-T-001.md`, `reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py`, `reports/verification/rt002-source-three-file-human-20261003.py`, `reports/verification/rt002-installed-118-human-20261003.py`, `reports/verification/rt002-delivery-readiness-20261003.md`, `reports/verification/rt002-formal-input-readiness-20260927.md`, and these six T-001 evidence records: `native-owner-cli-startup-20261003/observation.md`, `native-owner-cli-20261003-f31929/observation.md`, `completion-preparation-20261003/entry-observation.md`, `restore-installed-118-self-test-20261003.log`, `restore-self-test-20261003.log`, `owner-regression-readback-20261003.md` (each relative to `specs/epic-189-a1-rt002-repair/verification/T-001/`). This is a path-pattern screen, not a complete secret scan. Original native host responses and test transcripts are also excluded as raw evidence regardless of a path-pattern match. Do not `git add` the whole RT002 spec or reports trees.

Before any broader public artifact set is proposed, perform a separate complete secret/privacy audit and reconcile every referenced original path/hash without altering frozen or hash-bound bytes. Until then, public CI verifies the published implementation only; local-only evidence and the pending independent gate retain their separate status.
