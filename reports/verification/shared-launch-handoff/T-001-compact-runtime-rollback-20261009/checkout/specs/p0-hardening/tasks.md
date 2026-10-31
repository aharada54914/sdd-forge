# タスク（lite）: p0-hardening

> 3タスクは互いに別ファイルのみ触るため Scope 非重複・依存なし（独立）。
> これは REQ-003 が並列実装対象とすべき independent-set の実例そのもの。

## T-001 wfi-audit-cycle の収束保証（試行上限 + NO-CHANGE 停止）
Approval: Draft
Status: Planned

### Scope
- `plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md` のみ
- `Audit-Attempt:` / `Audit-Content-Hash:` フィールド導入、STEP 1 Precondition と Resumption 節、BLOCKED 分岐（STEP4/STEP7）への上限・NO-CHANGE 記述追加、許可 Audit-Status に `Human-Blocked` 追加

### Done When
- BLOCKED 到達時に `Audit-Attempt` をインクリメントする記述がある
- `Audit-Attempt >= 3` で再 BLOCKED 時に `Audit-Status: Human-Blocked` にして自動再試行を止める記述がある
- `Not-Started` 再開時に前回 content-hash と一致（未改訂）なら halt する記述がある
- `tests/p0-hardening.tests.sh` の REQ-001 チェックが PASS
- `reports/implementation/T-001.md` を作成

### Blockers
- None

## T-002 sdd-ship の quality-gate 上限をディスク集計に固定
Approval: Draft
Status: Planned

### Scope
- `plugins/sdd-ship/skills/run/SKILL.md` のみ
- Step 4 Full track 項目5の書き換え、State Machine Summary への注記

### Done When
- gate 呼び出し前に `reports/quality-gate/` の当該 task-id レポート数を数える記述がある
- 3 以上で `Escalate-Human` 停止・手動調査案内する記述がある
- `invoked 3 times`（invocation 内カウント）表現が残っていない
- `tests/p0-hardening.tests.sh` の REQ-002 チェックが PASS
- `reports/implementation/T-002.md` を作成

### Blockers
- None

## T-003 implement-tasks の独立タスク並列実装
Approval: Draft
Status: Planned

### Scope
- `plugins/sdd-implementation/skills/implement-tasks/SKILL.md` のみ
- Task Selection Algorithm と Implementation Loop の書き換え（independent-set 抽出 + 並列ディスパッチ）

### Done When
- eligible set から Blockers=None かつ Scope 非重複の independent-set を1パス抽出する記述がある（SCOPE-DISJOINT 同基準）
- Claude Code=1メッセージ内複数 Task 同時ディスパッチ、Codex=並列プロセス+wait の環境別手順がある
- Scope 重複タスクは逐次フォールバックする記述がある
- 同時実行数上限（暫定 Claude=4 / Codex=CPU-2、承認時に確定）が明記されている
- 「earliest ... 1件のみ逐次」の旧記述が置換されている
- `tests/p0-hardening.tests.sh` の REQ-003 チェックが PASS
- `reports/implementation/T-003.md` を作成

### Blockers
- None

## T-004 決定論的 doc 整合テストの追加
Approval: Draft
Status: Planned

### Scope
- `tests/p0-hardening.tests.sh`（新規）のみ
- T-001/T-002/T-003 の Done When を grep ベースで検証する bash 3.2 互換テスト

### Done When
- REQ-001/002/003 それぞれのチェック関数があり、対象 SKILL.md に対して PASS/FAIL を返す
- 既存テストランナー（`tests/`）から実行でき、緑になる
- `reports/implementation/T-004.md` を作成

### Blockers
- T-001, T-002, T-003
