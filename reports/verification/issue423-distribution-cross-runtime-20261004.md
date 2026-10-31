# Issue 423 distribution cross-runtime continuation — 2026-10-04

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`
Observed HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`

This is local regression evidence, not a formal evaluator report, current-head CI, native Windows validation, installed-host activation, or a Done decision. Commands ran against the dirty owner working tree through `rtk proxy` with `login=false`. Existing dirty changes and historical evidence were preserved. Complete raw logs were not saved; the observations below come from tool stdout and exit status.

## Newly executed checks

| Command after `rtk proxy` | Exit | Result |
|---|---:|---|
| `pwsh -NoLogo -NoProfile -File tests/validate-capability-registry.tests.ps1` | 0 | 27 pass, 0 fail |
| `pwsh -NoLogo -NoProfile -File tests/registry-discovery.tests.ps1` | 0 | 21 pass, 0 fail |
| `bash tests/capability-registry-parity.tests.sh` | 0 | 22 pass, 0 fail, 0 designed-red |
| `bash scripts/check-sdd-structure.sh` | 0 | `check-sdd-structure: OK`; CLAUDE.md advisory |

The parity suite exercised current script wrappers in disposable simulated Claude Code, Codex CLI, and Copilot CLI installed-plugin layouts. It compared Bash/PowerShell output, digest JavaScript output, committed goldens, independent digest reconstruction, projection files and exit codes. Its built-in divergence canary was detected. This establishes fixture parity, not a live host session or whole-tree installation.

## Evidence and launch boundaries retained

- The recorded human FilesOnly build used installer `9b43d5eaf93a9cefffc562a3108f43ab2bc2a64c675a710ec5c59250f7abe719`, and proved installed validator/helper bytes and validator execution at that time. It is not a current-installer `87bcebf...` whole-tree receipt. The human-only build runner was not executed or copied into an alternative route.
- The two candidate-only registry-registration checks omitted by the prior normal run bind a historical proposal to HEAD `06bc32cc26f2d67adb02e827610b5230e1658f72` and the pre-repair canonical Registry hash. They are not outstanding current-source acceptance checks. Their pins were not rewritten to make the historical proposal appear current.
- T-001 remains Done; T-002 remains Implementation Complete; T-003 remains Blocked; T-004 through T-006 remain Planned. The T-003 attempt-4 required-input read refusal was not retried or routed around.
- T-002 evaluator preparation still records the `manifest-archive-input.json` versus accepted `manifest.json` filename mismatch, unavailable strong-tier selection from old implementation candidates, and the actual required-role/reference read refusal. This continuation neither resolves those conditions nor substitutes an unvalidated invocation. See `reports/verification/issue423-t002-evaluator-launch-preflight-20261004.md`.

No production/test source, frozen input, identity ledger, task lifecycle field, canonical implementation report, or review verdict was changed. No reservation, commit, push, or merge was performed. This note is not implicitly admitted to any evaluator manifest.
