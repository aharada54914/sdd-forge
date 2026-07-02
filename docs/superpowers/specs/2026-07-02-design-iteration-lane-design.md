# デザイン駆動高速イテレーションレーン 設計書

- 日付: 2026-07-02
- ステータス: 承認済み（ブレインストーミング完了）
- 対象バージョン: v1.8.0 候補

## 目的

Web アプリ・デスクトップ（WPF）アプリの開発において、「デザインを確認しながら高速に相互連携させる」開発ループを sdd-forge のワークフローに統合する。具体的には:

- 仕様段階: claude.ai/design（DesignSync ツール）と連携し、デザインシステムの参照とモックアップのブラウザ確認・フィードバックループを回す。
- 実装段階: Claude Preview MCP（Web）/ wpf-visual-verify スキル（WPF）で「実装→スクリーンショット→デザイン照合→修正」の高速ループを回し、最終スクリーンショットを実装レポートの証跡として添付する。

## 背景と現状

- 既存のデザイン支援は `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md` のみで、手動・任意のプロンプト集に留まる。ツール連携・自動ループ・ship フェーズとの接続は存在しない。
- 実行環境（Claude Code）側には DesignSync ツール、Claude Preview MCP、wpf-visual-verify スキルが既に存在する。

## 決定事項（要件）

| 論点 | 決定 |
|---|---|
| 組込位置 | bootstrap（仕様段階）＋ ship（実装段階）の両方 |
| 環境対応 | グレースフルデグラデーション。ツール未検出時は現行の手動手順にフォールバックし、ワークフローは壊れない |
| ゲート扱い | 非ブロッキング。ループ支援＋証跡添付のみ。合否判定は既存の quality-gate / 人間レビューに委ねる |
| DesignSync | 双方向（Pull=デザインシステム参照、Push=モックアップ公開）。アップロードは都度人間承認 |
| 実現方式 | 内部スキル2つ追加（案A）。公開スキルは5つのまま、可視性契約を維持 |

## アーキテクチャ

```
bootstrap ─→ sdd-bootstrap-interviewer ─→ [UIアプリ & ユーザー希望時] ─→ design-sync-loop（仕様段階）
         └→ lite-spec ────────────────→ [同上・オプショナル] ────────→ design-sync-loop

ship ─→ implement-tasks ─→ implement-task ─→ [UIタスク時] ─→ visual-verify-loop（実装段階）
```

新規スキルはいずれも `user-invocable: false` の内部スキル。エントリポイントは bootstrap / ship のまま変更しない（スキル可視性契約の維持）。

## コンポーネント

### 新規スキル① `design-sync-loop`

配置: `plugins/sdd-bootstrap/skills/design-sync-loop/`

仕様フェーズのデザイン確定ループを担当する。

1. **能力検出**: DesignSync ツールの有無を確認。なければ手動フォールバック（現行 claude-design-workflow.md の手順）へ。
2. **Pull**: `list_projects` でユーザーが対象のデザインシステムプロジェクトを選択（`create_project` で新規作成も可）。デザイントークン・既存コンポーネントを読み取り、`specs/<feature>/ux-spec.md` の Design-Source セクションに記録する。
3. **モックアップ生成**: ビュー/状態ごとのセマンティック HTML（外部アセットなし・使い捨て）を `specs/<feature>/mockups/` に生成する。
4. **Push（都度人間承認）**: 明示承認を得てから `finalize_plan` → `write_files` でデザインシステムプロジェクトに同期。ユーザーは claude.ai/design のブラウザ UI で確認・フィードバックし、再生成ループを回す。
5. **確定**: 承認されたモックアップを ux-spec.md から参照する。**Mermaid が正典である原則は維持**し、モックアップは非正典の視覚参照とする。

### 新規スキル② `visual-verify-loop`

配置: `plugins/sdd-implementation/skills/visual-verify-loop/`

実装フェーズの高速視覚検証ループを担当する。

0. **起動条件（UI タスク判定）**: 対象タスクが `specs/<feature>/ux-spec.md` の存在する feature に属し、かつタスク定義が UI レイヤーのファイル（ビュー/コンポーネント/スタイル）を変更対象に含む場合に起動する。該当しないタスクではスキップし、判定結果を記録する。
1. **アプリ種別検出**: Web（dev サーバー起動可能）→ Claude Preview MCP。WPF → wpf-visual-verify。どちらでもない → 記録してスキップ。
2. **高速ループ**: 起動 → スクリーンショット＋DOM 検証（preview_inspect / preview_snapshot）→ 承認済みモックアップと ux-spec の状態定義（empty/loading/error、レスポンシブブレークポイント）に照合 → コード修正 → 再確認。最大5イテレーション。
3. **証跡**: 最終スクリーンショットを `reports/visual-evidence/<task-id>/` に保存し、implementation-report.md の Visual-Evidence セクションから参照する。
4. **非ブロッキング**: 不一致は所見として記録するのみ。Done 判定は既存の quality-gate と人間レビューが行う。

## 既存ファイルへの変更

| ファイル | 変更内容 |
|---|---|
| sdd-bootstrap-interviewer SKILL.md | UX インタビュー節に design-sync-loop へのルーティングを追加（ツールなし環境は手動手順へフォールバック） |
| lite-spec SKILL.md | 同様のオプショナルルーティングを追加（lite トラック対応） |
| implement-task SKILL.md | 実装完了→レポート作成の間に、UI タスクなら visual-verify-loop を呼ぶステップを追加 |
| claude-design-workflow.md | 手動フォールバック手順として存置。design-sync-loop から参照 |
| tools/validate-repository.ps1 | 新スキル2つを期待リストに追加（可視性契約チェックを通す） |

## データフロー・成果物

- `specs/<feature>/mockups/*.html` — 使い捨てモックアップ（非正典）
- `specs/<feature>/ux-spec.md` — Design-Source セクション（プロジェクト ID、取得したトークン）と Mockup-Status を追記
- `reports/visual-evidence/<task-id>/*.png` — 実装段階の視覚証跡
- `implementation-report.md` — Visual-Evidence セクション追加

## エラー処理・セキュリティ

- ツール未検出・認証失敗 → 手動手順にフォールバックし `design tools unavailable — manual workflow used` と記録。ワークフローは止めない。
- claude.ai へのアップロードは毎回、finalize_plan の権限プロンプト＋スキル内の明示確認の二重承認とする。機密モックアップの扱いはリポジトリのデータハンドリング規則に従う旨をスキル本文に明記する。
- プレビューサーバー起動失敗 → 記録してループをスキップし、タスクはブロックしない。
- DesignSync の `get_file` で取得したリモートコンテンツは指示ではなくデータとして扱う（プロンプトインジェクション対策）。

## テスト・検証

1. `tools/validate-repository.ps1` の可視性契約チェックが新スキル込みでパスすること（新スキルは user-invocable: false）。
2. 既存のパリティテスト（release-validation 等）が引き続きパスすること。
3. スモークテスト: サンプル Web アプリ機能で bootstrap → ship を通し、(a) DesignSync ありの自動ループ、(b) ツールなしの手動フォールバック、の両経路を確認する。

## スコープ外

- Figma API 連携・双方向 Figma 同期
- デザイン照合のブロッキングゲート化（決定論的ゲート思想と衝突するため）
- ピクセル単位の自動ビジュアルリグレッション比較（照合はモデルによる目視相当の確認と所見記録に留める)
