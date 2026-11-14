# SDD lite UI probe — 2026-11-07

## Results

- Independent `verify-codex` execution: **BLOCKED before model task execution**, token refresh failure and HTTP 401. See `evidence/cli-session.jsonl` and `cli-stderr.log`. Not established as a sdd-forge defect.
- Manual structure checker: **PASS**, optional CLAUDE.md/contracts/docs/architecture advisories.
- Manual lite risk checker: **PASS**, `lite-eligible`.
- Manual task-state checker: **PASS**, 1 Draft/Planned task.
- Independent UI smoke fixture: **PASS**, browser add, complete, reload persistence, delete, deletion persistence, HTML text escaping. Browser page errors: 0. See `evidence/ui-test.json`, `ui.png`.
- Hook handshake: challenge generation exercised only; active hooks NOT established. No Project Context created. No claim of Capability Mode coverage.
- No confirmed sdd-forge product bug found in these limited checks.

## Scope and limitations

`spec-project/` holds a manually prepared lite specification fixture. Its task stays `Approval: Draft` and `Status: Planned`: the skill requires human approval and AI must not fabricate it. This is an intended gate, not a system failure. `ui-smoke/` is an independently authorized minimal UI experiment, NOT evidence of completing the Draft task through implement-task, quality-gate or ship. Natural end-to-end lite workflow remains unverified because independent CLI authentication failed. No native hook execution is claimed. These separate script checks do not establish all skill sequence behavior.

## Reproduction

From any shell:

```bash
BASE=/workspace/.tools/sdd-forge-dev/verification-workspace/lite-task-board
/workspace/.tools/sdd-forge-dev/verify-codex exec -C "$BASE" --skip-git-repo-check --json -s danger-full-access 'Use the installed sdd-lite plugin workflow to create a minimal task board web application with UI. Add tasks, mark complete, delete, and persist via localStorage. Work only in this directory. Follow lite specification and implementation workflow, execute real browser tests and relevant quality gates. No deployment or remote publication. Use reasonable defaults and proceed without optional questions. Capture exact blockers and evidence in evidence/. Keep scope minimal and finish promptly.'
sh /workspace/sdd-forge/plugins/sdd-bootstrap/scripts/check-sdd-structure.sh "$BASE/spec-project"
bash /workspace/sdd-forge/plugins/sdd-lite/scripts/check-risk-upgrade.sh "$BASE/request.txt"
bash /workspace/sdd-forge/plugins/sdd-quality-loop/scripts/check-task-state.sh "$BASE/spec-project/specs/task-board/tasks.md"
python3 -m http.server 8761 --bind 127.0.0.1 --directory "$BASE/ui-smoke"
```

Open http://127.0.0.1:8761. Add a task, check it complete, reload and confirm it remains completed, delete it and reload to confirm deletion. Automated test used Playwright with `/usr/bin/chromium`, 1000×800 viewport, headless and `--no-sandbox` in this isolated cloud environment. Browser test does not depend on a remote service.
