# 要件（SDD Core）: v2-lightweight-guardrails

- **出典**: ADR-0051（Lightweight Guardrails and SDD Core Consolidation）
- **ベースバージョン**: `v1.26.0`（`13f70819f` — Claude Code / Codex CLI / Copilot CLI / Gemini CLI 4 環境対応）
- **目的**: 厳格なローカル物理ロック（7,247 行の 4 言語フック・224 ファイル保護・外部鍵署名・SDD Full 3 連レビュー）から、開発者体験（DX）・AI エージェント自律性と仕様ガバナンスを両立する **ソフトなガードレール（3 層モデル）＋ SDD Core 単一トラック** へ移行する。

## 要件（Requirements）

- **REQ-001（軽量設定契約）**: プロジェクトは単一の人間可読設定ファイル（`sdd/guardrails.yaml` または `sdd/guardrails.json`）でソフトガードモード（`warn` / `confirm` / `strict`、既定 `confirm`）、保護対象仕様パス、レビュー方針、リスク規定値を宣言できること。設定ファイルが存在しない場合も、安全な既定値（`mode: confirm`）でエラー停止せず動作すること。
- **REQ-002（3 責務ソフトガード `sdd-soft-guard.mjs`）**: ローカル PreToolUse フックは Node.js ESM（標準ライブラリのみ、Node >= 20）単一実装とし、Claude Code / Codex CLI / Copilot CLI / Gemini CLI の 4 ホスト出力（`exit` / `copilot` / `gemini`）に対応すること。責務を ① `AGENT_STOP` 緊急停止 ② `tasks.md` の `Approval: Approved` 自己増加抑止 ③ 承認済み仕様ファイル本文への編集インターセプト の 3 点に限定し、非ファイル編集ツール（`Bash` / `shell` / `run_shell_command` / `Read` 等）はシェル解析せず即時許可すること。
- **REQ-003（承認済み仕様のソフト保護と安全な例外）**: 承認済みフィーチャーの仕様ファイル（`requirements.md` / `design.md` / `acceptance-tests.md` / `tasks.md`）において、`tasks.md` の `Status:` 遷移や `### Spec Amendments` セクションへの追記は妨げず、仕様本文（REQ / AC / Design / Scope / Done When）の書き換えのみを `warn` / `confirm` / `strict` モードに従って制御すること。`SDD_ALLOW_SPEC_EDIT=1` 指定時は明示解除として許可し、`.sdd/drift-events.jsonl` に監査イベントを記録すること。
- **REQ-004（仕様ベースライン記録 `record-spec-baseline.mjs`）**: 外部署名鍵なしで、対象フィーチャーの承認済み仕様ファイル群の正規化 SHA-256、`tasks.md` の契約部ハッシュ（`Status:` 行・`Spec Amendments` セクション除外）、Git `HEAD`、および `REQ-*` / `AC-*` インベントリを `specs/<feature>/.spec-baseline.json` に記録できること。
- **REQ-005（Spec Drift 検知 `check-spec-drift.mjs`）**: ベースラインと現在の仕様ファイルを比較し、`CLEAN` / `AMENDED` / `UNDECLARED_DRIFT` を決定論的に判定し、JSON および PR コメント／品質レポート向け Markdown で出力できること。`tasks.md` の通常進捗（`Status:` 変更）は `CLEAN` と扱い、`REQ-*` / `AC-*` の無断削除・改変（ゴールポスト移動）を検出した場合は `UNDECLARED_DRIFT` として報告すること。

## 受入条件（Acceptance Criteria）

- **AC-001**: `AGENT_STOP` ファイルが存在するとき、`sdd-soft-guard.mjs` はツール種別・`--emit` モードに関わらず必ず `deny` を返す。
- **AC-002**: `Bash` / `shell` / `run_shell_command` による通常コマンド（`rg`、`for` ループ、テスト実行等）および一般ソースコードの編集は、`sdd-soft-guard.mjs` によって一切ブロックされず `allow` を返す。
- **AC-003**: `tasks.md` に `Approval: Approved` を純増させる編集は、全モードで `deny` を返す。一方、既に承認済みの `tasks.md` に対する `Status: Planned` → `In Progress` → `Implementation Complete` → `Done` の更新は `allow` を返す。
- **AC-004**: 未承認（`Draft` かつ `.spec-baseline.json` 不在）の `specs/<feature>/requirements.md` は自由に編集でき `allow` を返す。
- **AC-005**: 承認済みフィーチャーの `requirements.md` 本文を書き換えた場合、`mode: confirm` では理由確認・`Spec Amendments` 記録を促すメッセージ付きでソフト停止、`mode: warn` ではイベント記録のうえ `allow`、`mode: strict` では人間編集のみ許可として `deny` を返す。
- **AC-006**: 承認済み仕様ファイルに対し、`### Spec Amendments` セクション内への追記のみを行う編集は `allow_amendment_section: true` のもとで `allow` を返す。また `SDD_ALLOW_SPEC_EDIT=1` 設定時は本文変更も `.sdd/drift-events.jsonl` 記録のうえ `allow` を返す。
- **AC-007**: `sdd-soft-guard.mjs` は Claude (`Edit`/`Write`/`MultiEdit`)、Codex (`apply_patch`)、Copilot (`--emit copilot` + `create`/`apply_patch`/`bash`)、Gemini (`--emit gemini` + `write_file`/`replace`/`run_shell_command`) の 4 環境ペイロードを正しく処理する。
- **AC-008**: `record-spec-baseline.mjs` → 変更なし、または `tasks.md` の `Status:` 更新のみ → `check-spec-drift.mjs` は `CLEAN`（終了コード 0）を返す。
- **AC-009**: `record-spec-baseline.mjs` 後に `requirements.md` の `AC-001` を無断で削除・変更すると、`check-spec-drift.mjs` は `UNDECLARED_DRIFT` を返し、該当 AC ID を出力する（`--fail-on-undeclared` 時は終了コード 1）。
- **AC-010**: 仕様変更とともに `### Spec Amendments` に非空の変更理由を記録すると、`check-spec-drift.mjs` は `AMENDED`（終了コード 0）を返し、Markdown 出力に変更ファイルと記録済み理由を含める。

## スコープ外（Phase 1）

- 既存の `sdd-hook-guard.{py,js,ps1,sh}`・`guard-invariants.json`・`sdd-lite`・Full レビューループの削除およびホストフック設定の切替（Phase 2〜3 で実施）。
- GitHub Actions ワークフロー追加とインストーラ刷新（Phase 4 で実施）。

## Spec Amendments

- （初期版のため変更なし）
