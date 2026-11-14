# Workflow evaluation evidence

Correction: recovered native evidence verifies HOOK_ACTIVE, exit 0. See [hook-activation-correction.md](hook-activation-correction.md). Earlier unavailable verdicts below are historical. Human task approval remains pending.

## Outcome
Installed sdd-forge 1.23.1 skills were read and applied from the codex-verify plugin cache: sdd-bootstrap:sdd-adopt and sdd-lite:lite-spec. This is specification-stage output from the installed workflow. No application fixture or implementation was created.

The initial directory contained only evidence/. Required structure was created using the installed adoption checker and AGENTS template, adapted to the explicitly requested lite track. No existing source or project constitution was overwritten. Host is local, so no CI/issue/PR templates were created. Advisory CLAUDE.md, contracts and docs/architecture were omitted because adoption requires confirmation for advisory items and they are unnecessary here. Required empty directories contain .gitkeep; specs contains the new feature documents.

## Commands and results
Commands ran from this project directory. Installed plugin root below is `/workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins`.

```sh
bash /workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins/sdd-bootstrap/1.23.1/scripts/check-sdd-structure.sh . > evidence/structure-before.txt 2>&1
# FAIL: six required items missing; host local.
bash /workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins/sdd-quality-loop/1.23.1/scripts/check-hook-activation-handshake.sh --emit-challenge > evidence/handshake-challenge.json 2>&1
# Challenge emitted; nonce recorded in JSON.
bash /workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins/sdd-quality-loop/1.23.1/scripts/check-hook-activation-handshake.sh --verify-response --nonce bac0face7312cdda14e7cf7dc5d5347d --recorded-result evidence/handshake-response.json --runtime codex-cli > evidence/handshake-verdict.json 2>&1
# CAPABILITY_RUNTIME_UNAVAILABLE: activation metadata cannot be established.
test -e sdd/project-context.yaml
# Exit 1: physically absent. Lite-spec G4/C1 permits DISABLED_LEGACY / COMPATIBILITY_FALLBACK, explicitly requested lite.
bash /workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins/sdd-lite/1.23.1/scripts/check-risk-upgrade.sh evidence/source.txt > evidence/risk-upgrade.txt 2>&1
# lite-eligible. No capability fragment: Project Context absent.
mkdir -p specs reports/implementation reports/quality-gate docs/adr docs/review-tickets
touch specs/.gitkeep reports/implementation/.gitkeep reports/quality-gate/.gitkeep docs/adr/.gitkeep docs/review-tickets/.gitkeep
bash /workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins/sdd-bootstrap/1.23.1/scripts/check-sdd-structure.sh . > evidence/structure-after.txt 2>&1
# OK: no required items missing; advisory items remain.
```

Files were authored with apply_patch. The nonce-bearing canary patch was attempted twice (first absolute path, then the exact relative-path runtime template). Both returned a real PreToolUse denial stating that agents must not modify gate scripts, hook configuration or critical test files. Neither wrote a sentinel. A subsequent shell command embedding that denial as evidence was itself rejected by the same hook, so evidence capture used a plain observation record. This does not prove HOOK_ACTIVE, and no bypass was attempted. The verifier's legacy reason name PLUGIN_HOOKS_DISABLED does not establish that hooks are disabled.

Discovery also encountered one JavaScript syntax error and one malformed rg regex; corrected discovery successfully located installed templates/scripts. No files changed in those failed calls.

## Approval blocker and exact next step
Review specs/task-board/requirements.md, design.md and tasks.md. A human must change only T-001's `Approval: Draft` to `Approval: Approved` in tasks.md. Leave `Status: Planned`. The installed lite-spec Approval Gate says only humans may set Approved; AI may not approve. User authorization explicitly excludes fabricated task approval.

After human approval, resume using sdd-ship:ship with the lite track and specs/task-board/tasks.md (skill handoff syntax: `/sdd-ship --lite specs/task-board/tasks.md`). That workflow must recheck risk, implement through implement-task, run browser tests and apply lite-gate. No browser tests, application checks or lite gate have run: there is no implementation, and the Draft task cannot be implemented yet. No Done claim, deployment, remote publication, commit or push occurred.
