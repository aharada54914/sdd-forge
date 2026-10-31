# 設計（lite）: p0-hardening

## 方針

既存の成熟パターンに追従して**最小差分**で塞ぐ。新機構は導入しない。

- 上限の型: review-loop の `round==N→BLOCKED` 明示上限（`impl-review-loop/SKILL.md:200-205`）。
- NO-CHANGE 停止の型: review precheck の sha256 未変更検出（`impl-review-precheck.sh:172-176`）。
- 並列安全性の判定: `task-reviewer-b.md:140-151` の `SCOPE-DISJOINT`（同一ファイルを同目的で同時変更しないこと）。

3タスクは互いに別ファイルを触るため独立（＝この feature 自体が REQ-003 の並列性の実例になる）。

## 変更/新規ファイル

- `plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md` — REQ-001（T-001）
- `plugins/sdd-ship/skills/run/SKILL.md` — REQ-002（T-002）
- `plugins/sdd-implementation/skills/implement-tasks/SKILL.md` — REQ-003（T-003）
- `tests/p0-hardening.tests.sh`（新規, 決定論的な doc 整合チェック） — 3タスク共通の検証

> スタック分類は `docs/spec`（実行コードでなくスキル定義の Markdown）。lite-gate が検証コマンドを再実行して PASS を確認する。compile 系チェックは理由付きで waive。

## 詳細設計

### REQ-001 — wfi-audit-cycle 収束保証

現状: Cycle1/Cycle2 の BLOCKED は `Audit-Status: Not-Started` に戻すのみ（`SKILL.md:101,160`）。再開は `Not-Started → STEP 1`（`:244`）で、試行回数も WFI 改訂の有無も見ない。

変更:
1. WFI-NNN.md に `Audit-Attempt: N`（初期 0）フィールドを導入。BLOCKED 到達時にオーケストレーターがインクリメント（承認増加ではないので hook-guard 非対象）。
2. STEP 1 の Precondition に上限判定を追加: `Audit-Attempt >= 3` かつ再び BLOCKED 相当 → `Audit-Status: Human-Blocked` を設定し、自動再試行を禁止して人間の根本対応を促して halt。
3. STEP 1 に NO-CHANGE 停止を追加: `Not-Started` から再開する際、前回 BLOCKED 時に記録した WFI 本文の content-hash（`Audit-Content-Hash:` フィールドに保存）と現在の hash が同一なら「WFI 未改訂」として halt し人間に改訂を促す。
4. `Human-Blocked` を Precondition の許可 Audit-Status 一覧・Resumption 節に追記。

### REQ-002 — sdd-ship gate 上限のディスク集計

現状: `run/SKILL.md:137` は「quality-gate has been invoked 3 times for the same task」という invocation 内カウントで、`reports/quality-gate/` を参照しない（跨ぎリセット）。

変更:
1. Step 4 Full track の項目5を書き換え: quality-gate 呼び出し前に `reports/quality-gate/` 配下で**当該 task-id を含むレポート数**を数える。3 以上なら fix-by-review-ticket を促さず `Escalate-Human` で停止し、手動調査を案内。
2. State Machine Summary（`:159-169`）に、この上限がディスク由来である旨を注記。
3. Lite track（lite-gate）は単発で上限概念がないため対象外（現状維持）。

### REQ-003 — implement-tasks 独立タスク並列実装

現状: Task Selection 手順4「最も早い eligible 1件」（`SKILL.md:74`）、Implementation Loop「For each selected task」逐次（`:80-104`）。

変更:
1. Task Selection を拡張: eligible set のうち **Blockers=None かつ Scope ファイルが互いに重複しない**独立タスク群を1パスで抽出（`independent-set`）。重複判定は SCOPE-DISJOINT と同基準。
2. Implementation Loop を並列化:
   - **Claude Code**: 1アシスタントメッセージ内で independent-set の各タスクを別々の Task（サブエージェント）として同時ディスパッチ。
   - **Codex**: 各タスクを別プロセスで並列起動し wait で合流。
   - Scope が重複するタスクは同一パスに入れず逐次フォールバック。
3. 合流後に eligible set を再評価（既存 step10 同様、完了が後続を unblock）。
4. 並列で走る各タスクは従来どおり `In Progress → Implementation Complete` と実装レポートを個別生成。`git` 競合回避のため、同時実行は Scope 非重複が前提（上記1で保証）。
5. 既定の同時実行数上限を明記（Open Question の確定値。暫定: Claude=最大4 Task、Codex=CPU-2）。

## テスト方針

決定論的な doc 整合チェック（`tests/p0-hardening.tests.sh`）で以下を検証:

- REQ-001: `wfi-audit-cycle/SKILL.md` に `Audit-Attempt`・`Human-Blocked`・`Audit-Content-Hash` の記述が存在し、`Not-Started` 一択の再開分岐が上限/NO-CHANGE 判定を含むこと（grep ベース）。
- REQ-002: `run/SKILL.md` の gate 上限節が `reports/quality-gate/` と `Escalate-Human` を参照し、`invoked 3 times` の invocation 内カウント表現が残っていないこと。
- REQ-003: `implement-tasks/SKILL.md` の Task Selection が `independent-set` / SCOPE 非重複 / 並列ディスパッチ（Claude single-message・Codex 並列）を記述し、「earliest ... 1件のみ逐次」表現が置換されていること。

lite-gate がこの検証コマンドを再実行して VERDICT: PASS を確認 → Done。
