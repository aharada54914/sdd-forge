# 統一デザインシステム × 高速イテレーションレーン 統合設計書

- 日付: 2026-07-03
- ステータス: 承認済み（ブレインストーミング完了）
- 対象バージョン: v1.8.0 候補
- 先行ブランチ: feature/design-iteration-lane（design-sync-loop / visual-verify-loop、READY TO MERGE 判定済み）
- 統合元計画: PR #57 `docs/design-system-refactor-plan.md`（統一デザインシステム統合リファクタリング計画、Draft）

## 目的

sdd-forge で開発されるアプリケーションに対し、(1) プロジェクトレベルの統一デザインシステム契約（PR #57 の構想）と、(2) デザインを確認しながら高速に相互連携するイテレーションループ（feature/design-iteration-lane の実装）を統合し、Claude Design（claude.ai/design）と連携した高品質 UI/UX の高速開発を実現する。

両計画の役割分担: **PR #57 = What（契約）と強制（ゲート）**、**本ブランチ = How（高速ループ）**。統合により「モックアップがトークン非連動」「視覚検証が規約非参照」という相互の弱点を解消する。

## 決定事項（要件）

| 論点 | 決定 |
|---|---|
| スコープ | PR #57 の P0〜P5 相当を全部実装し、両ループを契約に接続する（レイヤード統合＝案A） |
| ブランチ戦略 | feature/design-iteration-lane を先に PR 化。本統合は feature/unified-design-system（同ブランチから分岐）で実施。PR #57 は本スペックで上書き（コメントで誘導しクローズ提案、クローズ判断は人間） |
| Figma | ツール内製なし。Figma Variables → DTCG design-tokens.json エクスポートの取込経路としてドキュメント化のみ。インタラクティブ確認は claude.ai/design（DesignSync）が正 |
| 外部連携 | **D7 採用**: ui-ux-pro-max-skill（MIT、Basic 機能のみ、Python 必須）を custom プロファイルのシード生成器として検出ベースで活用。**D5 ドロップ**: smarthr プロファイル一式（PR #57 の 1-2b / 3-3 / 4-8）は実装しない。D6 内の smarthr 借用規約はテキストとして存続 |
| ds_profile | `custom` / `none` の2択（smarthr ドロップにより単純化） |
| ゲート方針 | ループは advisory・非ブロッキングのまま。決定論的ゲート check-design-system は **warn 開始 → 2 リリース後に error**（OQ-2 の既定値） |
| 未決事項の既定値 | OQ-1: `design-system/` は対象アプリのリポジトリ直下。OQ-3: lite トラックはスクリプト強制なし・手動チェックリストのみ。OQ-5: ui-ux-pro-max は Basic（OSS/MIT）機能のみ前提、Python 不在時はスキップして D6 フォールバック |

## 全体アーキテクチャ

```
design-system/                     ← 契約層（対象アプリにプロジェクトで1つ、唯一の真実源）
├── design-tokens.json  (W3C DTCG 形式)
├── design-system.md    (UI規約・a11y要件 = WCAG 2.2 AA)
├── ui-patterns.md      (D6 普遍的UX規約)
└── build/              (任意: Terrazzo / Style Dictionary の言語別出力)

bootstrap ─→ interviewer ─→ [UIアプリ] ds_profile 質問（custom / none）
                └─ custom ─→ design-sync-loop v2
                              ① design-system/ 不在なら生成:
                                 ui-ux-pro-max 検出 → シード生成（--design-system --persist）
                                 → 人間レビュー → DTCG / ui-patterns への契約マッピング
                                 （スキル不在・Python 不在時は D6 テンプレートで手動インタビュー）
                              ② design-tokens.json / ui-patterns.md 参照のモックアップ生成
                              ③ claude.ai/design Push（都度人間承認）→ ブラウザ確認ループ（現行機能）

ship ─→ implement-task ─→ [UIタスク] design-system/design-system.md を必須読み物に条件追加
              └─→ visual-verify-loop v2: 照合基準に design-system/（トークン・ui-patterns）を追加
     ─→ quality-gate ─→ check-design-system.(sh|ps1)（決定論的、warn 開始）
                        design-system-checklist.md（UI 変更時のみ条件付きロード）
```

**統合上の最重要判断**: D7 シード生成フローは interviewer ではなく **design-sync-loop に収容**する（PR #57 は interviewer 1-2c 想定だったが、デザイン確定はループの責務）。これにより新規スキルは増えず（21 スキルのまま、可視性契約無変更）、interviewer の変更は ds_profile 質問の追加に留まる。

## フェーズ分解

依存関係: P0' → P1' → (P2' ∥ P3' ∥ P4') → P5'。実装計画はフェーズごとに直前作成し（file:line アンカーの鮮度維持）、サブエージェント駆動で連続実行する。

### P0' — 契約とテンプレート

- `contracts/design-system.contract.v1.schema.json` 新規: design-tokens.json のメタ検証（DTCG 必須フィールド、semver、generated_by）と design-system.md 必須セクション定義。既存 review-contract.v1 と同列
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/` に `design-system.template.md` / `design-tokens.template.json` / `ui-patterns.template.md` 新規。ui-patterns は D6 の6カテゴリ（アクション配置 / ダイアログの適時性 / アイコン / フロー整合 / 状態設計 / 認知負荷）をデフォルト値込みで収録
- `PLUGIN-CONTRACTS.md` に producer（sdd-bootstrap）/ consumer（sdd-implementation, sdd-quality-loop）契約を追記

### P1' — bootstrap: 生成フェーズ統合

- interviewer SKILL.md: UI アプリ判定時に `ds_profile` 選択質問（custom / none）を追加し、custom なら design-sync-loop を実行（既存の design-sync-loop ルーティング行を拡張。TEST-018 の必須文字列 `No mockup provided — optional visualization skipped` は保持）
- design-sync-loop SKILL.md v2: Loop の前段に「design-system/ 保証」ステップを追加（ui-ux-pro-max 検出 → シード生成 → 人間レビュー → 契約マッピング → D6 フォールバック）。モックアップ生成ステップは design-tokens.json / ui-patterns.md 参照を必須化。claude.ai/design Pull/Push・都度承認・get_file データ扱いは現行のまま
- investigate-codebase: brownfield 用にハードコード色・スペーシング・フォント指定の棚卸しを追加（design-system.md 初期化の入力）
- design.template.md: `## Layer Specifications` 直後に `## Design System Compliance` セクション追加（参照する design-system.md バージョン、使用トークン群、新規コンポーネントの要否と理由）。※PR #57 の記載アンカー（line 26 `## Frontend Plan`）は現物に存在しないため現物基準で再定義
- sdd-lite: design-lite.md に「トークン/既存コンポーネント使用」1 行宣言のみ追加（lite の軽さ維持）

受入基準: 非 UI feature（api-only / cli / library）では生成物・質問が一切増えない。

### P2' — review-loop: レビュー観点統合

- impl-reviewer-a に DESIGN-SYSTEM-CONFORMANCE 検査（design.md の Design System Compliance が design-system.md と矛盾しないか、新規コンポーネントに理由があるか）
- impl-reviewer-b の scope creep 検査に「規約外 UI ライブラリの無断導入」を追加
- phase-review-checklist.md に Design System Specification セクション追加

受入基準: review-prompt-calibration.tests.sh が観点重複・欠落を検知しない。

### P3' — implementation: 実装強制

- implementation-policy.md に UI 実装規則: (a) スタイル値はトークン参照のみ・生値禁止、(b) 既存コンポーネント再利用優先・新規作成は design.md 記載時のみ、(c) a11y 要点（アイコンのみボタン禁止・placeholder をラベル代替にしない・クリック可能要素はテキスト必須）、(d) 対象言語の lint 設定が無い場合は導入をタスク化して報告
- implement-task の Required Reading に「UI タスク時は design-system/design-system.md」を条件付き追加
- visual-verify-loop SKILL.md v2: Loop の照合ステップに design-system/（トークン準拠・ui-patterns 準拠）を照合基準として追加。advisory・非ブロッキング・最大5イテレーション・証跡保存は現行のまま

受入基準: 非 UI タスクのコンテキスト消費が増えない（条件付きロードのみ）。

### P4' — quality-loop: 検証ゲート

- `references/design-system-checklist.md` 新規: トークン準拠（生値検出）/ コンポーネント再利用 / レスポンシブ / ダークモード（トークン定義時のみ）/ D6 UI パターン準拠（プライマリアクション単一・破壊的操作の分離と確認・ダイアログの適時性・アイコンテキスト併記・フロー順配置・空/ローディング/エラー3状態）
- `references/accessibility-checklist.md` を WCAG 2.1 AA → **2.2 AA** に更新（タッチターゲット 24×24px、Focus Not Obscured、認証での認知負荷排除など。EU アクセシビリティ法 2026-06-28 適用済みの法的要件）
- quality-gate SKILL.md の条件付きチェックリストロードに design-system-checklist を追加（UI 変更時）
- `scripts/check-design-system.(sh|ps1)` 新規: ① design-tokens.json の契約検証 ② 変更差分中の生カラーコード（#hex / rgb() / hsl()）・マジックスペーシング値の検出（除外 glob 付き grep、言語非依存）③ UI タスクの design.md に Design System Compliance セクションが存在するか。**ps1 版は Test-Json に依存しない実装**（PS5.1 互換。workflow-state 検証の既知問題の再発防止）。bash 3.2 互換
- verification-contract.template.json に `design-system` チェック追加（UI タスクのみ required、非 UI は stack waiver と同じ流儀で waivable）
- risk-gate-matrix.md: UI 変更を含む medium 以上のタスクの required-set に design-system を追加
- evaluation-rubric.md: 「UI/コンポーネントライブラリ非準拠」を Major に分類
- 運用: check-design-system 違反は warn（指摘のみ）で開始し、2 リリース後に error 化

受入基準: gates.tests.sh に check-design-system の正常系/違反検出/waiver ケースを追加し全パス。既存ゲートの挙動不変。

### P5' — テスト・ドキュメント

- `tests/design-system-compliance.tests.(sh|ps1)` 新規（fixture: 準拠/違反サンプル）
- sdd-ship は track detection 変更なし・quality-gate 委譲経由で自動適用されることを PLUGIN-CONTRACTS.md 上で確認（変更不要の見込みの検証のみ）
- docs/workflow-guide.md・docs/skill-reference.md・README・CHANGELOG（Unreleased）追記。Figma Variables → DTCG 取込経路のドキュメント化を含む

## データフロー・成果物

- `design-system/`（対象アプリ直下、プロジェクトに1つ）— 契約層
- `specs/<feature>/mockups/*.html` — トークン駆動の使い捨てモックアップ（非正典、現行どおり）
- `specs/<feature>/ux-spec.md`（full）/ `design.md`（lite）— Design-Source / Mockup-Status（現行どおり）＋ ds_profile 記録
- `reports/visual-evidence/<task-id>/*.png` — 視覚証跡（現行どおり）
- verification-contract の design-system チェック結果 — 決定論的ゲート証跡

## エラー処理・セキュリティ

- 非 UI プロジェクト・`ds_profile: none` ではオーバーヘッドゼロ（全変更が条件付きロード / waivable check）
- ui-ux-pro-max 不在・Python 不在 → シード生成をスキップし D6 テンプレートの手動インタビューへフォールバック（記録を残す）
- DesignSync 不在 → 現行どおり手動フォールバック（claude-design-workflow.md）
- 生値検出の誤検知（テストコード・SVG 等）→ 除外 glob ＋ waiver 理由記述。warn 開始でキャリブレーション
- claude.ai へのアップロードは都度人間承認、get_file 取得内容はデータとして扱う（現行の設計を維持）
- ライセンス: ui-ux-pro-max は MIT（Basic のみ使用）。smarthr 由来の規約はテキスト借用のみでコード・ブランド資産の複製なし
- MASTER.md（ui-ux-pro-max 出力）は入力シードであり、sdd-forge の契約（design-system/）が常に正（ツールロックイン回避）

## テスト・検証

1. 既存テストの不変条件維持: bootstrap-interview-guidance.tests.sh（TEST-018 文字列、TEST-010 の claude-design-workflow.md 制約）、validate-repository.ps1 の可視性契約（21 スキル・公開5スキル不変）
2. 新規: design-system-compliance.tests.(sh|ps1)、gates.tests.sh への check-design-system ケース追加、constant-parity.tests.sh が新契約定数を検知
3. Windows ローカルの PS5.1 制約下でも新規 ps1 スクリプト・テストが動作すること（Test-Json 不使用）
4. スモークテスト（手動）: サンプル Web アプリで bootstrap → ship を通し、(a) ui-ux-pro-max あり、(b) なし（D6 フォールバック）、(c) ds_profile: none、の3経路を確認

## スコープ外

- smarthr プロファイル（D5。将来 ds_profile の第3の選択肢として追加可能な構造は維持する）
- Figma API 連携・Figma MCP・双方向 Figma 同期（DTCG JSON 取込経路のドキュメント化のみ）
- 言語別 lint プラグインの内製（既存ツール採用の提案と grep ベース決定論ゲートで下限保証）
- デザイン照合ループのブロッキングゲート化（ループは advisory 恒久。ブロッキングは決定論的 check-design-system のみ、warn→error 段階導入）
- ピクセル単位の自動ビジュアルリグレッション

## 実施順序

- Step 0: feature/design-iteration-lane を PR 化（gitlab-proxy-push スキルで push）。PR #57 に統合スペックへの誘導コメント
- P0' → P1' → (P2' ∥ P3' ∥ P4') → P5'（フェーズごとに実装計画を直前作成し、サブエージェント駆動で実行。フェーズ完了ごとにテスト実行）
