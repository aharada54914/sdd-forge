# T-011 installed-boundary coverage repair

Run/Session/Agent Instance: 01a15032-0b50-7872-9dff-c10464e2bdfc
Model: openai/gpt-6-astra; effort high; tier strong. Attempt 3.
Scratch: /tmp/cloud-T011-installed-01a15032

## Commands and chronology

Run from repository root; `V=specs/cloud-orchestration/verification/T-011/installed-boundary-tests`.
Source `/tmp/cloud-native-test-env.sh` before Python tests; required-native=1.
No cloud credentials or inherited host identity were used by new fixture calls.

1. `bash scripts/check-sdd-structure.sh`: exit 0, structure OK (CLAUDE.md advisory).
2. `bash plugins/sdd-implementation/scripts/validate-task-input-manifest.sh --manifest "$V/task-input-manifest.json" --snapshot-root /tmp/cloud-T011-installed-01a15032/inputs --expected-task T-011`: exit 0 before edits and final. Snapshot paths `initial/` map to canonical repository paths; `input-origins.json` maps external guidance. Snapshot retained privately.
3. `preflight-mismatches.log`: validator independently rejects wrong task, fallback and hash (three actual exit 1 results). No approval/status field changed.
4. `python3 -B "$V/sensitivity.py" --repo . --output "$V/before"`: actual exit 1; original five-test BootstrapInstalled suite passes production AND both semantic mutants. Caller assertion fails because policy mutant survives. Results show runtime-presence survives too. Committed harness, preflight and baseline at b9478c93797f9172d667248e18e780c8c136dd3a BEFORE editing tests. Initial mypy found heterogeneous-record inference; a list[dict] annotation corrected the evidence harness before this committed rerun, without suppressions or changing tests/guards.
5. Add only 133 lines to tests/cloud-orchestration-routing.tests.py. `python3 -B tests/cloud-orchestration-routing.tests.py BootstrapInstalled -v`: exit 0, eight methods. Three added methods exercise 44 provider/path negative combinations, each with a valid real installed control and a reached spy control. Healthy negatives run both imported installed helper and actual installed CLI.
6. `python3 -B "$V/sensitivity.py" --repo . --output "$V/after"`: exit 0; healthy eight-test suite PASS; each mutant causes 20 semantic no-delegation assertions, zero errors. Negative fixture results are not setup/import failures or fake CLI failures.
7. `python3 -B "$V/rollback.py" --repo . --scratch-root /tmp/cloud-T011-installed-01a15032 --output "$V/rollback"`: exit 0. Disposable committed worktree b9478c93 overlays exact current pending production bytes without modifying them. Restore baseline test bytes: healthy selected suite PASS and both mutants survive; caller exit 1. Reapply current test bytes: healthy PASS, mutants fail semantically; caller exit 0. Worktree removed; all installed fixtures restored then removed. Repository source/test bytes never temporarily reverted. This is rollback of coverage, not production behavior.
8. `python3 -B tests/verification.py --suite tests/cloud-orchestration-routing.tests.py --run --receipt "$V/routing-receipt.json"`: exit 0, 96 methods, no skips; real pinned compiler/synthesizer. Receipt explicitly says clean=false/reusable=false, not a clean release-commit proof. Existing catalog/native-cell checks execute inside this suite; no wiring file changed.
9. `/tmp/cloud-quality-python/bin/ruff check --config tests/shared-launch-python/pyproject.toml tests/cloud-orchestration-routing.tests.py "$V/sensitivity.py" "$V/rollback.py"`: exit 0.
10. `MYPYPATH=plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts /tmp/cloud-quality-python/bin/mypy --config-file tests/shared-launch-python/pyproject.toml tests/cloud-orchestration-routing.tests.py "$V/sensitivity.py" "$V/rollback.py"`: exit 0, three source files, no suppressions.
11. `git diff --check -- tests/cloud-orchestration-routing.tests.py`: exit 0. Compare 14,661 initially tracked files (excluding selected test) against private initial hash snapshot: no changes. Explicit helper, canonical/previous reports, tasks and ticket hashes remain equal. See preservation.json.
12. `bash plugins/sdd-implementation/scripts/validate-implementation-report.sh reports/implementation/cloud-orchestration/T-011-installed-boundary-tests.md`: report-validation.log. Final output-row hash verification: outputs-validation.log.

## Mutation policy and branch coverage

Physical policy disables BOTH overlapping root and runtime resolve/absolute checks,
retaining regular-file admission. Presence variant disables only runtime is_file,
retaining physical checks. Removing only root.resolve is not required to be killed
because runtime resolution independently rejects the same path. Both mutants are
applied solely to disposable installed helper bytes; no repository production edit.
Missing and non-directory roots fail via manifest I/O; no invented explicit guard.

Both providers: relative/missing/file/symlink root and root ancestor symlink;
CLI and each of four modules absent/directory/symlink; CLI scripts directory and
runtime/scripts ancestor symlink. Valid controls reach exactly the expected delegated
argv/env once. Negatives require exact exit 2 and cloud-input-error/v1,
CLOUD_ROUTE_BLOCKED, field route, unchanged request, no evidence/output/new workspace
entries, and zero delegated calls. Original real provider parity and denial tests
remain intact. Mutant failures use an AssertionError at the delegated boundary.

## Limits

Linux symlinks executed; creation failures on other platforms explicitly skip the
individual subcase. Existing Windows runtime refusal remains the real subprocess
control while the spy separately proves bootstrap delegation is reachable. No new
SKIP condition makes an existing branch newly reachable. Native Windows/macOS and
junction execution remain pending actual T008 CI; Linux does not establish them.
No UI, new dependency, architecture, CLI contract, provider behavior, cloud action,
model-host trial or guard change. Frozen native2 and previous six-suite/guard records
remain prior evidence, not rerun here. No raw reviewer/native event or stderr stream
is published in this report's Outputs. Full suite, fresh independent cycle2, ticket
closure, task status and release decisions remain root-owned. Live TEST-003/005/009
remain blocked by OQ-001. This attempt claims no Done or quality-gate verdict.
