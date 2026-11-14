# SQLite full workflow smoke test — 2026-11-07

## Result

Native sdd-forge full execution: **BLOCKED before model work (401 authentication)**.
Separate manually authored application smoke test: **PASS**. This does not establish bootstrap, independent reviews, approval gates, ship or native hook execution.

The full bootstrap skill was inspected. It requires a native hook-canary handshake before track selection; this Work execution is not the failed CLI session, so no hook success or full workflow completion is asserted or fabricated.

## Native CLI reproduction

```sh
/workspace/.tools/sdd-forge-dev/verify-codex exec \
  -C /workspace/.tools/sdd-forge-dev/verification-workspace/sqlite-task-board \
  --skip-git-repo-check --json \
  -o /workspace/.tools/sdd-forge-dev/verification-workspace/sqlite-task-board/cli-result.txt \
  'sdd-forge full モードで、SQLiteに永続化するUI付きタスク管理アプリを作成して。追加、一覧、完了切替、削除を持つ。ローカル利用、Python標準ライブラリと素のHTML JSを優先。通常のbootstrapから仕様、実装、ゲートまでプラグインの指示に従い進め、実際のUIテストとSQLite再起動永続化を検証して。合理的な仮定で進み、秘密は出力しない。外部公開しない。'
```

Evidence: `cli-events.jsonl`, `cli-stderr.log`. `turn.failed` reports access token refresh failure. Stderr also records models API/WebSocket 401 and MCP HTTP 451. This is environment/CLI authentication evidence, not a demonstrated SQLite or sdd-forge product defect.

## Run the independent SQLite application

```sh
cd /workspace/.tools/sdd-forge-dev/verification-workspace/sqlite-task-board/manual-app
python3 app.py
```

Open http://127.0.0.1:8133 . Standard-library Python HTTP server and SQLite; no application dependency installation. Local single-user demo, not a production deployment. Database defaults to `tasks.sqlite3`; `TASK_DB` and `PORT` can override.

## Reproduce verification

```sh
python3 /workspace/.tools/sdd-forge-dev/verification-workspace/sqlite-task-board/manual-app/verify.py
```

Uses existing Python Playwright and `/usr/bin/chromium`. The script starts/stops the server and uses a separate `test.sqlite3`, preserving interactive application data. Evidence: `manual-app/results.json`, `sqlite-desktop.png`, `sqlite-mobile.png`, `server.log`.

Verified: actual browser add/complete/delete; SQL row contents; persisted completed state after server restart and reload; 390px mobile no horizontal overflow; HTML injection rendered as text; SQL injection stored as literal text; invalid empty title rejected with 400; zero browser JS errors. Compilation also passed.

During demo implementation, browser test caught a zero-width checkbox caused by `flex:0`. It was corrected to a fixed 20px basis and the complete test passed. This was an authoring defect in the independent demo, not an existing plugin defect. Playwright default bundled browser was absent; explicitly selecting installed Chromium resolved it.
