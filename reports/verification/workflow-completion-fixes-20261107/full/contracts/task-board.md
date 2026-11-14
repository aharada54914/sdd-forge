# Task Board API and Data Contract

Task: `{ "id": "UUID string", "title": "1..500 trimmed Unicode chars", "completed": false }`。保存形式 `{ "version": 1, "tasks": [] }`。保存先data/tasks.json。idはserver生成。GET `/api/tasks` => 200 `{tasks: Task[]}`。
POST `/api/tasks` body `{title: string}` => 201 `{tasks: Task[]}`。
PATCH `/api/tasks/{id}` body `{completed: boolean}` => 200 `{tasks: Task[]}`。
DELETE `/api/tasks/{id}` bodyなし => 200 `{tasks: Task[]}`。
エラーは `{error: 日本語文字列}`。400 invalid input、403 origin/host拒否、404 unknown id/path、413 body上限、415 content type、500 storage failure。変更bodyの未知fieldは400。UTF-8 JSON。全変更は保存完了後に成功を返す。新規タスクを末尾追加し既存順保持。titleの前後空白はPython str.strip相当で除去する。

JSON duplicate keysは400。bodyはobjectのみ、completedは厳密boolean。title長はtrim後Unicode code points。Content-Length必須のbodyは65536 bytes以下、負値/不正形式は400、未対応transfer encodingは400。DELETEはbodyなし。未知HTTP methodは405。GETも含めHostをlocalhost:<actual-port>または127.0.0.1:<actual-port>に限定。変更要求のOriginがある場合はhttp://の同一allowlist authorityのみ受入れ、null/外部は403。Originなしのlocal clientは許可しCORS公開しない。
