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
5. Windows の `.cmd` / `.bat` シム CLI(npm / pnpm / yarn 等)への対応:
   libuv の PATH 探索は bare name を `.exe` / `.com` にしか解決せず、Node
   >= 20.12 は `.cmd` / `.bat` の shell なし起動を拒否する(CVE-2024-27980
   対策の同期 EINVAL)。そのため win32 ではエンジン自身が read-only fs API
   のみで PATH をディレクトリ順に走査し(各ディレクトリ内は `.com` / `.exe` /
   `.bat` / `.cmd` の既定 PATHEXT 順。PATHEXT 環境変数は読まない — 改竄で起動
   対象を広げられないよう固定集合)、解決結果が `.com` / `.exe` なら従来どおり
   `execFile` 直接起動、`.bat` / `.cmd` なら
   `%ComSpec% /d /s /c ""<解決済みパス>" <固定引数>"` で起動する。cmd.exe に
   渡すコマンドラインは PATH 解決済みファイルパスとコンパイル時定数引数のみ
   から構成され、ユーザー入力は一切到達しない(shell 使用は「ユーザー入力が
   shell に届かない」前提でのみ許容)。解決済みパスに cmd.exe の引用文字列内
   で安全でない文字(`"` / `%` / 改行)が含まれる場合は起動せず spawn-error
   として報告する。探索は PATH のみ(Windows 既定のカレントディレクトリ探索は
   意図的に行わない)。

## Consequences

- 任意コマンド実行・インストール実行系の要求(見送り済み)が将来復活しても、
  本サーバーの拡張ではなく別コンポーネントとして設計し直すことになる(本 ADR の
  supersede が必要)。
- PATH 上の偽装バイナリはプローブで起動され得る(クライアント環境と同一の信頼
  境界)。出力は untrusted data として正規化・上限処理され、実行・評価されない。
  残余リスクとして security-spec.md B2 に記録。win32 の cmd.exe 経由起動も
  この同一境界内に収まる: 攻撃者が PATH に悪意ある `.cmd` を置ける状況は、
  そもそも同名バイナリを置ける状況と等価であり、cmd.exe 経路が新たな攻撃面を
  追加しない(コマンドライン組成にユーザー入力が到達しないため)。同種の
  同一境界内残余リスクとして、(a) `%ComSpec%` 環境変数(起動対象の直接指定に
  のみ使用。引用文字列への補間はしないため injection 面にはならない)、
  (b) statSync 解決と起動の間の TOCTOU 窓(PATH ディレクトリへの書込権限を
  前提とするため PATH 偽装と等価)も記録する。
- win32 でタイムアウト超過により cmd.exe を kill した場合、シムが起動した
  孫プロセスが継承した stdio パイプを保持し続けることがある。エンジンは
  タイムアウト + 猶予 500 ms のバックストップで per-entry `timeout` を確定し
  応答をブロックしないが、孫プロセス自体は自然終了まで残存し得る(残余リスク:
  リソースは probe 対象 CLI 自身の挙動に依存)。
- バージョン情報の鮮度は TTL キャッシュ 60 秒に依存する(許容: 開発セッション中
  のツールチェーン変更は稀)。
