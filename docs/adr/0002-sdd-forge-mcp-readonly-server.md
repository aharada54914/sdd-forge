# ADR-0002: read-only MCP サーバー sdd-forge-mcp を repo 内 mcp/ に置き Evidence 機能を統合する

## Status

Accepted

## Context

AI クライアント（Claude Code / Codex / Cursor / VS Code）が sdd-forge の状態
（active specs、tasks.md 状態機械、review tickets、quality gate 結果、
evidence bundle）を構造化して読む手段がなく、毎回ファイルを個別に読ませる
必要があった。状態確認が手動で誤読リスクがあり、quality gate 判断の入力源と
して不安定だった（Issue #60）。

当初構想では「SDD Forge MCP」と「Evidence MCP」を別サーバーとする案、および
自作 MCP を別リポジトリで管理する案があった。

## Decision

1. SDD 状態読み取りと evidence 確認を単一の read-only MCP サーバー
   `sdd-forge-mcp` に統合する（Core tools 8 種 + Evidence tools 5 種 +
   Resources 5 種）。
2. 配置は sdd-forge リポジトリ内 `mcp/sdd-forge-mcp/` とし、installer で
   取捨選択可能（デフォルト同梱、`--skip-mcp` で除外、`--mcp <list>` で選択）に
   する。
3. サーバーは完全 read-only とする。書込み系 tool は一切持たず、SDD_SUDO・
   evidence 署名鍵・.env は denylist として読み取りも拒否する。tasks.md の
   状態判定は `check-task-state.sh` とのシェル等価をゴールデンテストで担保し、
   判定不能時は `cannot-parse` を返して推測しない。

## Alternatives considered

- **Evidence MCP を独立サーバーにする**: 対象ファイル群（specs/ 配下）と
  パスガード実装が共通で、分割はプロセス・登録・バージョン管理の重複を生む
  だけと判断し却下。
- **別リポジトリで管理**: spec・quality gate・CI と分離されると等価性ドリフト
  検出（golden test）が困難になるため却下。
- **書込み tool の同居（Approval 遷移等）**: quality gate の完全性は「人間のみが
  Approval を変更できる」ことに依存する。読み取りと書込みの権限分離を
  プロセスレベルで保証するため却下（PLUGIN-CONTRACTS.md のセキュリティ不変条件
  と整合）。

## Consequences

- AI クライアントは構造化 API で SDD 状態を取得でき、誤読・手動前処理が減る。
- パーサーとシェルスクリプトの二重管理が発生する。ゴールデンテストを CI 常設
  し、`check-task-state.sh` 変更時に MCP 側の追随を強制する。
- リポジトリに初の Node/TypeScript 基盤（package.json、CI Node ジョブ）が
  入る。配布方式は ADR-0003 で規定する。
- 仕様は specs/sdd-forge-mcp/（requirements.md ほか）が正。
