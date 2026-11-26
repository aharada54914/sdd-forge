---
name: design-sync-loop
description: Specification-phase UI design iteration loop for projects using a design-system/ contract. Ensures design-system/ exists, generates token-driven disposable HTML mockups under specs/<feature>/mockups/, optionally syncs via DesignSync with explicit egress consent, and falls back cleanly to manual workflow when design tools are unavailable.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `bootstrap` / `sdd-core-spec` から、UI 対象かつ `design-system/` 運用時のみ呼び出される内部スキル。成果物は `specs/<feature>/design.md` の `Design-Source` セクションへ記録する。

# Design Sync Loop

UI アプリケーションの仕様段階デザイン反復ループ。Mermaid と `design-system/` 契約を正本とし、`specs/<feature>/mockups/` 配下の HTML モックアップは使い捨ての視覚参照として扱う。

## 1. Ensure `design-system/`（ローカル契約を先に確保）

プロバイダー有無にかかわらず、プロジェクトルートに `design-system/`（`design-tokens.json`, `design-system.md`, `ui-patterns.md`）が未整備なら先に作成し人間の承認を得る（有効な `schema: design-system-contract/v1` が既にあればスキップ）:

1. **`ui-ux-pro-max` 利用可能時**: 製品種別・業種を確認してシード生成し、承認済み値を `design-tokens.json` と同梱 `templates/{design-system,ui-patterns}.template.md` へ転記。
2. **Figma DTCG JSON 提供時**: ローカルファイルから `design-tokens.json` へマッピング（Figma API 接続はしない）。
3. **フォールバック（テンプレート対話）**: 同梱 `templates/{design-tokens.template.json,design-system.template.md,ui-patterns.template.md}` を使い、ブランドカラー・タイポグラフィ・余白スケールを人間へ確認して作成。

## 2. Capability Detection & Fallback

1. `DesignSync` ツールをプローブする（遅延ロードツールも含め確認）。
2. 利用不可／認証失敗時は `specs/<feature>/design.md` の `Design-Source` に `design tools unavailable — manual workflow used` と記録し、同梱 `references/claude-design-workflow.md` に沿って手動フォールバックして戻る（仕様生成を絶対にブロックしない）。
3. ユーザーが明示的にデザイン参照生成を求め、ホストに別の画像/デザイン生成ツールがある場合は、リポジトリ機密を含まない最小合成ブリーフで参照画像を `specs/<feature>/mockups/` へ保存してよい（プロバイダー名を正確に記録し、DesignSync 接続と混同しない）。

## 3. Mockup & Egress Consent Loop（`DesignSync` 利用可能時）

外部プロバイダーを使う前に、同梱の `../../scripts/resolve-design-sync.py` に `design-sync-request/v1` を標準入力で渡す。読み込みは `operation: pull`、書き込みは `operation: upload` とし、毎回、現在の設定、機能・セッション・送信先、既存の判断記録を使う。結果が `prompt` なら同意の回答を加えて再実行する。 `skip` と `manual` は送信しない。`pull` の許可をアップロードに流用しない。

1. **Pull**: `list_projects` / `list_files` / `get_file` で対象プロジェクトのトークンと既存コンポーネント一覧を取得し、`Design-Source` へ記録。
2. **Generate Mockups**: 各画面・状態（default / empty / loading / error、レスポンシブ）について、外部アセット無し・トークン準拠（生カラーコード禁止）の HTML モックアップを `specs/<feature>/mockups/` に生成。
3. **Resolve Egress Consent**: 毎回 `AGENTS.md` の `ds_upload_consent`（`per-feature` [既定] / `standing` / `off`）を確認する:
   - `off`: アップロードせず手動フォールバック（`Egress-Consent: not-permitted`, `Ds-Upload-Consent-Setting: off`, `Egress-Consent-At: <ISO-8601>` を記録）。
   - `standing`: プロンプト不要で続行し、`(feature, destination)` 初回のみ `Egress-Consent: granted`, `Ds-Upload-Consent-Setting: standing`, `Egress-Consent-At` を記録。
   - `per-feature`: 当該 `(feature, session)` で未同意なら、送信内容・送信先（`claude.ai/design`）・外部保持リスク・適用範囲を明示説明して人間の明示同意を得てから `push` する。拒否時はアップロードせず手動フォールバック。
   判断結果に `audit` がある場合は、`specs/<feature>/design.md` の `Design-Source` に判断・適用設定・送信先・範囲と、返された `party`（`Egress-Consent-Party`）、記録時の ISO-8601 時刻（`Egress-Consent-At`）を残す。同意撤回は `withdrawn` と記録し、次回は再判定する。一度の辞退では継続的な拒否を記録しない。
   アップロード直前に対象の `specs/<feature>/mockups/` を同梱の `design-sync-scan.sh` または `design-sync-scan.ps1` で検査する。終了0なら `Egress-Scan: clean` と検査時刻を記録する。終了1なら検出内容を提示して送信を止め、その検査結果について明示的な上書き承認を得た場合だけ `Egress-Scan: overridden` と時刻を記録して続ける。終了2や異常終了ではツールを復旧して再検査するまで送信しない。
4. **Iterate & Finalize**: フィードバックを反映して再生成・再確認し、確定した視覚方針を `specs/<feature>/design.md` と `requirements.md`（UX 受入条件）へ反映する。

## Boundaries

- `design-system/` の承認は視覚規約の承認であり、タスク `Approval: Approved` や実装着工許可とは独立。
- 仕様生成をツール不在・認証失敗で停止させない。
- 実装フェーズでの実画面確認は `visual-verify-loop` と `sdd-gate` に委ねる。
