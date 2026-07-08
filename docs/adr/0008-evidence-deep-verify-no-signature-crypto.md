# ADR-0008 evidence_deep_verify は署名鍵を読まず署名を検証せず、git 祖先検証も host-deferred とする

## Status

Proposed(人間承認待ち — セキュリティ境界に関わる決定)

## Context

Issue #68(Phase 5, firm)は sdd-forge-mcp の既存 evidence ツール群(抽出専用 5 個)に
証拠バンドルの**再検証(deep-verify)**を追加することを要求する。deep-verify は成果物ハッシュ
のディスク突合とバンドル内部不変条件の再計算突合を行うが、Issue は同時に次を硬境界とする:

- 「without external tools」「read-only」「no new exec / network / write」。
- 「このツールは署名鍵素材を NEVER 読まず、HMAC 署名を NEVER 検証する。署名検証は host 側
  スクリプト(generate/check-evidence-bundle.sh)の責務のまま」。

一方で Issue のスコープ列挙は「git_commit が 40-hex かつ **HEAD-or-ancestor**」も含む。
HEAD/祖先判定は `git merge-base --is-ancestor` 等の git サブプロセス、または path-guard
allowlist 外の `.git` 読取を要し、no-exec 境界と両立しない。既存 `parsers/evidence-bundle.ts`
も同理由で祖先検証を省略し 40-hex 形状のみ検証している(module doc の simplification #2)。
「実行機能を持たない read-only MCP」で「どこまで in-process 検証するか」の境界確定が必要。

## Decision

1. **署名鍵の非読取・署名の非検証(中心的統制)**: evidence_deep_verify は署名鍵素材
   (`SDD_EVIDENCE_KEY` / `SDD_EVIDENCE_KEY_FILE` / `~/.sdd/evidence-key`)を取得する経路を
   一切実装しない。HMAC / sigstore 署名の暗号検証を行わない。`signature` は
   `{ present, alg?, verified: false, note }` として**存在有無と alg のみ**を報告する。
   署名の有無・妥当性は verdict に寄与しない。既存 `parseEvidenceBundle` が `signature` を
   as-is で echo する挙動を変えない。
2. **path-guard denylist 再利用**: 鍵ファイルは path-guard が既に denylist 済み
   (`DENYLISTED_BASENAMES` / `evidenceKeyPath` / realpath 比較)。全ディスク読取を path-guard
   (`guardedRead` / `resolveGuarded`)経由に限定し、鍵素材への到達経路を型・実装の両面で塞ぐ。
3. **git 祖先検証の host-deferred**: in-process では `git_commit` の 40 桁小文字 16 進
   (`^[0-9a-f]{40}$`)形状のみを検証する。HEAD/祖先(ancestry)検証は git サブプロセスを
   要するため in-process では行わず、`gitCommit.ancestryVerified: false` と値の echo・理由を
   明示報告して host スクリプト(git を持つ)の責務とする。祖先の真偽で verdict を上下させない。
4. **no-exec / no-write / no-network の維持**: 新規サブプロセス・ネットワーク・fs 書込みを
   追加しない。SHA-256 は node 標準 `node:crypto` のみで行う。これらの不在を既存の静的
   read-only 検査(fs 書込み API・`child_process` / `exec` / `spawn` / `eval` 禁止)+ no-key
   テスト(canary 鍵)で強制する。

## Consequences

- 証拠の**完全性検証**は 2 系統に分かれる: (i) in-process(MCP)= 成果物ハッシュ突合・
  正準 artifacts ダイジェスト・spec_revision・git 40-hex 形状・task_id/feature クロスバインド、
  (ii) host-only = 署名 HMAC 検証・git HEAD/祖先検証。運用は両者を併用する前提となる。
- 署名検証・git 祖先を将来 MCP 側で行いたくなった場合、それは本サーバーの no-exec/no-key
  境界の変更であり、本 ADR の supersede と新たなセキュリティレビューを要する。
- 鍵漏えい・偽 verified・偽祖先主張という高影響リスクを、鍵取得経路の不在 + denylist +
  静的検査 + no-key テストで多層防御する。残余リスクは host スクリプト側の責務に帰着し、
  security-spec.md B3 に記録する。
