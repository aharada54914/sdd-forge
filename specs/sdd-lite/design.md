# sdd-lite 設計ドキュメント

- **状態**: Draft（人間レビュー待ち）
- **作成日**: 2026-06-15
- **ブランチ**: `feature/sdd-lite`（分岐元 = main `796921f`、cross-model マージ済み）
- **目的**: 社内・部署内利用に閉じたアプリ向けに、現行 SDD フローを簡略化した「中量」開発トラックを、独立した軽量プラグイン `sdd-lite` として提供する。複数人開発への移行余地を「加算的昇格」で残す。

---

## 1. 背景と監査結果

現行 SDD Forge（3プラグイン / 9スキル / 7決定論ゲート / フック2系統 / リスク4階層）は堅牢だが、社内アプリには重い。重さの集中点：

- 生成ドキュメント8種（requirements/design/acceptance/tasks/traceability/ADR/investigation/baseline）
- 2軸状態管理（`Approval` ⊕ `Status`）
- 品質ゲート多重サイクル（最大3周）
- evidence-bundle + SHA-256 / HMAC 署名 + provenance
- critical 階層（二者承認 + cross-model + クリーンツリー強制）
- traceability 5層マッピング

## 2. 確定した設計判断（ユーザー合意済み）

| # | 決定 | 内容 |
|---|---|---|
| D1 | 重さ | **中量**。要件/設計/タスク/単一承認は維持。traceability・ADR必須・evidence-bundle・cross-model・critical階層・二者承認を削減 |
| D2 | 形態 | **新規の独立プラグイン `sdd-lite`**（既存3プラグインと並列） |
| D3 | 承認 | **単一承認のみ**。AI自己承認防止の核は維持、二者承認は廃止 |
| D4 | 内部構成 | **A案（再利用最大化）**。新規/変更分だけ実装、既存スクリプト・スキルを流用 |
| D5 | `Done`の証跡 | **真の軽量化**。`check-task-state` を lite 用に fork し、`Done` を「実装レポート + lite品質レポート(VERDICT: PASS)」だけで許可（evidence.json 不要） |
| D6 | 配布 | **コンパニオン同梱**。`sdd-lite + sdd-implementation + sdd-quality-loop` を install で同時導入。quality-loop のフックが lite を自動保護 |

## 3. 実コード検証で確定した結合（ground truth）

設計の前提を推測でなく実装読解で裏取りした（file:line は `feature/sdd-lite` 時点）。

| 検証項目 | 結論 | 根拠 |
|---|---|---|
| ガードの汎用性 | hook-guard は `*tasks.md` パス + `Approval: Approved` マーカーをキーに**増加操作のみ拒否**。lite の tasks.md も**無改変で自動保護**される | `sdd-hook-guard.py:43-44,107-109,358` |
| Second Approval / WFI ガード | lite が生成しない限り**休眠するだけでエラーにならない**（反応型） | `sdd-hook-guard.py:44-45,483-516` |
| contract の legacy モード | `risk` フィールドが無ければ階層強制(Pass4)をスキップ。`cross_model`/`required_workflow` も無ければ非強制 | `check-contract.sh:152,266-293` |
| contract の baseline | 6種(lint/typecheck/build/placeholder-scan/task-state-check/unit-tests)の**存在は常に必須**（waiver可） | `check-contract.sh:34,130-147` |
| check-risk の独立性 | baseline 必須セット外の独立ゲート。**呼ばなければ Risk 不要** | `check-risk.sh:45-49`（Risk行なしで失敗するが未呼出なら無関係） |
| **Done の bundle 必須** | `check-task-state` は `Done` 遷移に `verification/<id>.evidence.json` + `.contract.json` を**必須化**。**→ この結合が「真の軽量化」の障害なので fork する（D5）** | `check-task-state.sh:87-128` |
| 二者承認の発火条件 | `risk == "critical"` の `Done` のみで強制。lite は critical を使わない→無関係 | `check-task-state.sh:140-159` |
| evidence-bundle の low/medium | legacy/低中では署名・provenance・review_verdict 不要。ただし git_commit(HEAD祖先) は必須 → **fork で bundle 自体を不要化する** | `check-evidence-bundle.sh:248-335` |
| implement-task の依存 | traceability/ADR は「読む」記述（モデル指示であってスクリプト的ハード依存ではない）。Done化はしない | `implement-task/SKILL.md:35-37,103` |
| 前提構造チェック | check-sdd-structure は**リポジトリ階層のみ**検査（AGENTS.md/specs/reports/docs/adr/docs/review-tickets）。feature成果物は不問。docs/adr は空でOK | `check-sdd-structure.sh:46-51` |

## 4. アーキテクチャ

### 4.1 フロー（4ステップ）

```
1. lite-spec       要件 + 設計 + タスク を生成（traceability/ADR/受入の重い記述は任意）
   ↓
2. [人間] 単一承認  tasks.md の Approval: Draft→Approved（AIは既存ガードでブロック）
   ↓
3. implement-task  既存スキルを無改変流用。In Progress→Implementation Complete。Done化はしない
   ↓
4. lite-gate       低/中の決定論チェックを実行し lite品質レポート(VERDICT: PASS)を生成 → Done
```

前提: 対象リポジトリで `sdd-adopt` を一度実行し SDD 構造（AGENTS.md + 必須ディレクトリ）を用意しておく。

### 4.2 lite-gate が実行する検証

- `check-placeholders`（既存・無改変）: 本番コードの TODO/FIXME/stub 検出
- プロジェクトの lint / typecheck / build / test コマンドを **lite-gate 自身が実行**し結果を捕捉（実装者の自己申告でなく、ゲートが再実行する＝自己採点防止の核を低コストで維持）
- `check-task-state-lite`（新規 fork）: 状態機械を検証
- lite品質レポート（markdown, `VERDICT: PASS|FAIL` + 各チェック結果）を `reports/quality-gate/` に生成
- PASS なら `Status: Done` に遷移（fork が evidence.json なしで許可）

> **レビュー時の選択点（軽さ vs 客観性）**: 客観性を一段上げるなら、lite-gate が `contract.json` も生成して既存 `check-contract`（legacy モード, 無改変）で検証する選択肢がある（evidence.json 本体は依然不要）。本設計の既定は D5 に従い「contract.json も省略、lite品質レポートで代替」とするが、ここはレビューで反転可能。

### 4.3 check-task-state-lite の規則（fork 差分）

オリジナル `check-task-state.sh` から以下を**除去**し、それ以外は踏襲：

- 除去: `Done` の `verification/<id>.evidence.json` 必須・`.contract.json` 必須・check-evidence-bundle 呼出（L87-128）
- 除去: critical 二者承認ロジック（L140-159）
- 変更: `Done` 要件を「`Approval: Approved` + 実装レポートがタスクIDに言及 + lite品質レポートが `VERDICT: PASS` でタスクIDに言及」に置換
- 踏襲: Approval/Status の妥当値、In Progress/Impl Complete/Done は Approval: Approved 必須、Impl Complete は実装レポート必須、Blocked は Blockers 内容必須、重複タスクID検出、CRLF 正規化

### 4.4 ファイルレイアウト

```
plugins/sdd-lite/
├── .claude-plugin/plugin.json        # Claude Code 用メタ
├── .codex-plugin/plugin.json         # Codex CLI 用メタ（skills パス + interface）
├── .plugin/plugin.json               # Copilot CLI 用メタ（skills/agents パス）
├── skills/
│   ├── lite-spec/SKILL.md            # 軽量仕様生成（bootstrap-interviewer の縮約版）
│   └── lite-gate/SKILL.md            # 低/中ゲートのオーケストレータ
├── scripts/
│   ├── check-task-state-lite.sh      # fork（POSIX）
│   └── check-task-state-lite.ps1     # fork（PowerShell・クロスプラットフォーム必須）
├── templates/
│   ├── requirements-lite.md
│   ├── design-lite.md
│   ├── tasks-lite.md
│   └── quality-report-lite.md
└── references/
    └── lite-flow-policy.md           # lite フローの規約・昇格手順
```

### 4.5 再利用（無改変）

- `implement-task`（sdd-implementation）
- `check-placeholders`（sdd-quality-loop）
- `sdd-hook-guard` + `kill-switch`（sdd-quality-loop のフック登録経由で自動適用）
- `sdd-adopt`（sdd-bootstrap、初期構造用）

### 4.6 マーケットプレイス / インストール更新

- `.claude-plugin/marketplace.json` に `sdd-lite` エントリ追加
- `.agents/plugins/marketplace.json` に `sdd-lite` エントリ追加
- `install.sh` / `install.ps1` に `sdd-lite` を導入対象として追加（既定で3つ同梱）

## 5. 自己承認防止の維持

lite は新規ガードを書かない。既存 hook-guard が `*tasks.md` + `Approval: Approved` をキーに反応するため、lite の `specs/<feature>/tasks.md` も**そのまま保護対象**になる（§3 検証済み）。AI は承認を増やせず、人間のみが Draft→Approved にできる。kill-switch も同様に有効。

## 6. 昇格パス（複数人 / 高ステークスへの加算的移行）

lite 成果物は完全版 SDD の部分集合。昇格は**書き直しゼロの加算**：

| 追加するもの | 有効化される機構 |
|---|---|
| tasks に `Risk:` + `Risk Rationale:` | 階層強制（check-risk / check-contract Pass4） |
| 通常の `check-task-state`（fork でなく本体）を使う | evidence-bundle 必須化・Done の機械的証明 |
| contract に `cross_model: required` | クロスモデル検証 |
| critical タスク | 二者承認 + 署名 + provenance |
| `traceability.md` 生成 | REQ→AC→TEST→証跡チェーン |

実運用上は「sdd-lite を外し sdd-bootstrap / quality-loop の本フローに切替」でフル SDD に移行できる（成果物の場所・命名が同一のため連続）。

## 7. スコープ外（lite が生成・実行しないもの）

traceability.md、ADR の必須化、evidence.json バンドル（SHA256/git_commit/署名）、cross-model 検証、critical 階層、二者承認、WFI/retrospective、品質ゲート多重サイクル（lite は単発）、リスク階層強制。

## 8. クロスプラットフォーム方針

新規スクリプトは `.sh`（POSIX）と `.ps1`（PowerShell）の**両方を必ず実装**し挙動を一致させる（既存 check-* と同じ規約：CRLF 正規化、fail-closed、BSD awk 互換）。3 CLI（Claude Code / Codex / Copilot）すべてで動作すること。

## 9. テスト戦略

- `tests/` に `check-task-state-lite` のユニットテスト（.sh / .ps1 両方）を追加：Done 遷移が evidence.json 無しで通ること、Approval 無し Done が落ちること、実装/品質レポート欠落で落ちること、重複ID検出、CRLF。
- lite フローの E2E スモーク：lite-spec→承認→implement-task→lite-gate→Done が通る最小フィクスチャ。
- 既存テストスイートが緑のままであること（lite はファイル追加が主で既存無改変のため回帰リスクは低い）。
- ガード回帰：lite の tasks.md に対し AI が `Approval: Approved` を書けないこと（既存 hook-guard テストの対象拡張）。

## 10. 実装の進め方（このセッションの役割分担）

- メインセッション（Opus）= 設計・監査・レビュー（本ドキュメント）。
- 実装は割安モデルのサブエージェント（Haiku/Sonnet）に委譲。fork スクリプトの定型実装・テンプレ作成・plugin.json/marketplace 編集は機械的なため適。
- 設計判断・レビュー・統合はメインが担当。

## 11. 未解決メモ（レビューで確定）

1. §4.2 の「contract.json を残すか（客観性 vs 軽さ）」— 既定は省略、反転可。
2. プラグイン名 `sdd-lite` の最終確認（代替: `sdd-app` / `app-flow`）。
3. lite-spec が要件/設計/タスクを**3ファイル分割**か**1ファイル統合**か（D1 は中量＝分割寄りだが統合も可）。
