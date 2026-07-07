# ADR-0004 local-env-mcp は実行機能を提供せず固定 allowlist プローブのみで環境情報を取得する

## Status

Proposed(人間承認待ち — セキュリティ境界に関わる決定)

## Context

Issue #64(承認済み MCP 導入計画 Phase 1)は「ローカル開発環境の read-only
情報提供 MCP。実行機能は持たない(承認済み決定)」を要求する。一方でスコープは
「ツールチェーンのバージョン」提供を含み、バージョン取得には対象 CLI の起動
(例: `node --version`)が事実上不可欠である。「実行機能を持たない」の解釈を
確定し、任意コマンド実行への昇格を構造的に不可能にする設計が必要。

## Decision

1. 「実行機能を持たない」=「呼び出し側(MCP クライアント)にコマンド実行能力を
   提供しない」と定義する。ツール入力にコマンド・引数・パスを受け取る
   フィールドは一切定義しない(入力は allowlist 名の enum フィルタのみ)。
2. 環境情報の取得経路は次の 2 つに限定する:
   - `os` / `process` 標準 API(get_os_info)
   - コンパイル時定数の probe allowlist(node / npm / pnpm / yarn / bun /
     deno / git / gh / python3 / go / rustc / cargo / java / docker)に対する
     `child_process.execFile`(shell 不使用)起動
3. プローブには per-entry タイムアウト 2 秒・出力上限 8 KiB・並列上限 4 を課し、
   超過時はプロセスを kill して per-entry 失敗として報告する。
4. `child_process.exec` / `spawn`(shell オプション)/ `eval` / fs 書込み API の
   不使用を静的検査(テスト)で強制する。allowlist の変更はコード変更 + 契約
   (enum)更新 + レビューを必要とする。

## Consequences

- 任意コマンド実行・インストール実行系の要求(見送り済み)が将来復活しても、
  本サーバーの拡張ではなく別コンポーネントとして設計し直すことになる(本 ADR の
  supersede が必要)。
- PATH 上の偽装バイナリはプローブで起動され得る(クライアント環境と同一の信頼
  境界)。出力は untrusted data として正規化・上限処理され、実行・評価されない。
  残余リスクとして security-spec.md B2 に記録。
- バージョン情報の鮮度は TTL キャッシュ 60 秒に依存する(許容: 開発セッション中
  のツールチェーン変更は稀)。
