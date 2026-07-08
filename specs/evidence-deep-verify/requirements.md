# Requirements: evidence-deep-verify

Spec-Review-Status: Pending

Source Issue: https://github.com/aharada54914/sdd-forge/issues/68

## Overview

承認済み MCP 導入計画の Phase 5(firm)。sdd-forge-mcp の既存 **evidence** ツール群
(現状は抽出専用の 5 ツール)に、証拠バンドルを**再検証(deep-verify)**する 6 番目の
read-only ツール `evidence_deep_verify` を追加する。deep-verify は次の 2 系統を
in-process・決定論的に行う:

- (a) **成果物ハッシュ再計算**: バンドルが記録する `artifacts[].sha256` を、path-guard
  経由でディスク上の実ファイルから SHA-256 を再計算して突合し、成果物単位で
  match / mismatch を返す。
- (b) **不変条件(invariant)/ チェーン整合性検証**(外部ツール不使用): 正準 `artifacts`
  ダイジェストを再計算して突合、`spec_revision`(specs/<feature>/{requirements,design,
  acceptance-tests}.md をこの順で連結した SHA-256)を再計算して突合、`git_commit` の
  40 桁 16 進フォーマットを検証、バンドルが主張する report / contract のクロスバインド
  (task_id / feature の一致)を検証する。

**最重要セキュリティ不変条件**(requirements → security-spec → ADR-0008 で一貫):
このツールは**署名鍵素材を一切読まず、HMAC 署名の暗号検証を一切行わない**。`signature`
オブジェクトは alg と存在有無のみをエコー/報告し、署名の暗号検証は host 側スクリプト
(generate/check-evidence-bundle.sh)の責務のまま残す(path-guard が鍵ファイルを既に
denylist 済み)。

本ツールは sdd-forge-mcp(Issue #60、QG 11/11 PASS)で確立した基盤 — エラーエンベロープ、
path-guard チョークポイント、node:test、静的 read-only 検査、esbuild 単一バンドル配布
(ADR-0003) — を踏襲する。既存 `parseEvidenceBundle` / `parseVerificationContract` /
path-guard / envelope を再利用し、`signature` を as-is でエコーする現行挙動を変えない。

## Target Users

- SDD 品質ゲートを運用する AI コーディングエージェント。Done 遷移前後に証拠バンドルの
  整合性を、host スクリプトを起動せず MCP 経由で構造化検証したい。
- sdd-forge 保守者。バンドルの改竄・ドリフト(成果物差替え、記録ハッシュ改竄、spec
  ドリフト、外部コミット参照)を、決定論的な per-artifact / per-invariant の結果として
  受け取りたい。

## Problems

- 既存 evidence ツールは抽出専用で、「バンドルが記録する内容がディスクの実体と一致
  するか」「バンドル内部の不変条件が保たれているか」を再検証できない。整合性検証は
  host の check-evidence-bundle.sh 起動に依存し、MCP クライアントからは呼べない。
- host スクリプトは python3 / PowerShell とサブプロセス(git・check-contract.sh)を
  要し、read-only MCP の no-exec 境界と両立しない。抽出以上の検証を MCP で行う手段が
  ない。

## Goals

- 証拠バンドルの再検証を read-only・決定論的に MCP へ公開する: 成果物ハッシュの
  ディスク突合 + 内部不変条件の再計算突合。
- host スクリプトの正準式(canonical artifacts digest / spec_revision / git_commit
  40-hex ルール)と**完全一致**する in-process 実装(署名暗号検証・git 祖先検証を除く)。
- 署名鍵非読取・署名非検証の境界を中心的統制として維持し、既存 5 ツールの安全姿勢を
  1 mm も緩めない。

## Non-goals

- **署名(HMAC)の暗号検証**。鍵素材を読まないため構造的に不可能で、host 責務のまま
  据え置く(ADR-0008)。`signature` は echo/報告のみ。
- **git_commit の HEAD/祖先(ancestry)検証**。git サブプロセスを要し no-exec 境界に
  反するため in-process では行わない(OQ-001 / ADR-0008)。40-hex 形状のみ検証し、
  ancestry は host-deferred として報告する。
- バンドルの**書換え・修復・署名生成**(read-only。書込み API 不使用)。
- 契約(contract)自体の再検証(check-contract.sh の等価再実装)。deep-verify は
  バンドルが主張する task_id / feature のクロスバインドのみ検証する(evidence-bundle.ts
  の simplification #1 と同様の割り切り)。
- 新規ネットワーク通信・新規サブプロセス・ファイルシステム書込み。
- identity ledger への一切の関与。

## User Stories

- 品質ゲート運用者として、`evidence_deep_verify(feature, taskId)` を呼び、成果物単位の
  match/mismatch と全体 verdict(pass/fail)を受け取り、Done 遷移の可否判断に使いたい。
- 保守者として、成果物 1 バイトの改竄や記録ハッシュの改竄が、当該成果物の mismatch と
  正準 artifacts ダイジェストの不一致として決定論的に surface されることを確認したい。
- 保守者として、このツールが署名鍵を絶対に読まず HMAC を検証しないことを、静的検査と
  no-key テストで保証したい。

## Acceptance Criteria

正準の AC 一覧は `acceptance-tests.md` を参照。要旨:

- 整合バンドル → verdict `pass`。成果物 1 バイト改竄 → 当該 mismatch + 全体 `fail`。
  記録ハッシュ改竄 → mismatch。成果物欠落 / 2 MiB 超過 → per-artifact 報告。
- spec_revision ドリフト → 報告。git_commit 非 40-hex → 形状不正で fail。外部 40-hex
  コミット → 形状 OK・ancestry 未検証(host-deferred)として値をエコー報告。
- 署名が存在しても検証せず、署名鍵を読まないことを明示的にアサート。
- host スクリプトの判定(署名検証・git 祖先を除く)と一致(agreement-with-host-script)。

## Requirements

- **REQ-001**: sdd-forge-mcp の `tools/evidence.ts` に 6 番目の read-only ツール
  `evidence_deep_verify(root, feature, taskId)` を純関数として追加し、`server.ts` に
  MCP ツール登録する。入力は既存 5 ツールと同一の `feature` / `taskId`(zod)のみ。
  実装は `parseEvidenceBundle` / `parseVerificationContract` / path-guard / envelope を
  再利用し、決定論的・read-only とする。

- **REQ-002**: **per-artifact ハッシュ再計算**: バンドルの各 `artifacts[]` について、
  path-guard(`guardedRead`)でディスク上ファイルを読み SHA-256 を再計算し、記録された
  `sha256`(小文字正規化)と突合する。per-artifact 結果は
  `{ path, recordedSha256, computedSha256?, status, reason? }` を持ち、status は
  `match` / `mismatch` / `missing` / `too-large` / `path-denied` / `invalid-recorded-sha`
  のいずれか。例外を投げず全て status として報告する(REQ-011)。

- **REQ-003**: **全体 verdict と failures**: 全成果物が `match` かつ全 in-process
  不変条件(REQ-004/005/007)が成立する場合のみ verdict は `pass`、それ以外は `fail`。
  `failures[]` は各不成立を人間可読の文字列で列挙する。git ancestry・署名検証は
  in-process 検証対象でないため verdict に影響しない(host-deferred / echo のみ)。

- **REQ-004**: **正準 artifacts ダイジェスト不変条件**: host スクリプトの
  `evidence_canonical` と**同一式**で、記録値から `artifactsDigest.recorded`、ディスク
  再計算値から `artifactsDigest.onDisk` を算出し突合する。式は design.md「API / Contract
  Plan」に逐語引用する(要旨: 各成果物を `path + "\x00" + sha256(小文字)` としてソート、
  改行 `\n` で連結し SHA-256)。全成果物が一致すれば両ダイジェストは一致する。

- **REQ-005**: **spec_revision 不変条件**: `specs/<feature>/requirements.md`,
  `design.md`, `acceptance-tests.md` を**この順**で(存在するファイルのみ)連結した
  バイト列の SHA-256 を path-guard 経由で再計算し、`bundle.spec_revision` と突合する。
  式は host の `compute_spec_revision` と逐語一致(1 つも存在しなければ `""`)。結果は
  `specRevision { recorded?, computed, status, filesHashed[] }` を返す。

- **REQ-006**: **git_commit 不変条件**: `bundle.git_commit` が 40 桁小文字 16 進
  (`^[0-9a-f]{40}$`)であることを in-process 検証する。HEAD/祖先(ancestry)検証は
  git サブプロセスを要し no-exec 境界に反するため in-process では行わず、値を echo し
  `gitCommit { value?, shapeValid, ancestryVerified: false, reason }` として host-deferred
  を明示報告する(OQ-001 / ADR-0008)。40-hex 不成立は形状不正として `fail` に寄与する。

- **REQ-007**: **クロスバインド不変条件**: バンドルが主張する束縛を検証する —
  (i) `bundle.verification_contract` を parse し contract.task_id == bundle.task_id、
  contract.feature == bundle.feature を突合、(ii) `bundle.quality_report` の
  `Task ID:` / `Feature:` が bundle.task_id / feature と一致することを突合。結果は
  `crossBindings[] { subject, status, detail }`。不一致は `fail` に寄与する。

- **REQ-008**: **NO-KEY / NO-SIGNATURE-VERIFY 硬境界**(中心的統制): 本ツールは署名鍵
  素材(SDD_EVIDENCE_KEY / SDD_EVIDENCE_KEY_FILE / ~/.sdd/evidence-key)を**読まず**、
  HMAC / sigstore 署名の**暗号検証を行わない**。`signature` は
  `{ present, alg?, verified: false, note }` として存在有無と alg のみ報告する。署名の
  有無・妥当性は verdict に影響しない。path-guard の denylist(鍵ファイル)を再利用し、
  ディスク読取は全て path-guard 経由に限定する。

- **REQ-009**: **agreement-with-host-script**: in-process の判定(per-artifact
  match/mismatch、artifacts ダイジェスト、spec_revision、git_commit 40-hex 形状、
  task_id/feature クロスバインド)は、`generate-evidence-bundle.sh` /
  `check-evidence-bundle.sh` の対応判定と**同一結果**でなければならない(署名暗号検証と
  git 祖先検証を除く)。リポジトリにコミット済みの実バンドル群でゴールデン一致を保証する。

- **REQ-010**: **決定論**: 時刻・乱数・ネットワーク・プロセス起動に依存せず、同一入力
  (バンドル + ディスク状態)に対し同一出力(バイト等価な `data`)を返す。

- **REQ-011**: **path-guard 再利用と例外安全**: 全ディスク読取は
  `guardedRead` / `resolveGuarded` 経由とする。成果物の欠落(`not-found`)・2 MiB 超過
  (`too-large`)・denylist(`path-denied`)は throw せず per-artifact status として報告
  する。allowlist 外パスは `path-denied` として扱う。

- **REQ-012**: **契約(contract)追加**: 応答形状 `evidenceDeepVerifyData` を
  `contracts/sdd-forge-mcp-tools.v1.schema.json` の `okEnvelope.data.oneOf` に**加算的**
  (additive・後方互換)に追加する。v1 を維持し、破壊的変更でないことを design.md で明記
  する。エラーは既存エンベロープ(`invalid-input` / `not-found` / `cannot-parse` 等)を用いる。

- **REQ-013**: **テスト**: node:test(sdd-forge-mcp と同一の `tsconfig.test.json` +
  `scripts/run-tests.mjs` 方式)でユニット/統合/ゴールデン/no-key/静的検査を追加する。
  既存の静的 read-only 検査(fs 書込み・`child_process`・`exec`/`spawn`・`eval` 禁止)が
  引き続き PASS すること。

## Roles and Permissions

- 役割分離なし(単一ローカルユーザー)。MCP サーバーは呼び出し元 OS ユーザー権限で
  動作し、認証機構を持たない(OS ユーザー境界に委譲、既存 5 ツールと同一前提)。

## Main Workflows

1. エージェントが `evidence_deep_verify(feature, taskId)` を呼ぶ → `parseEvidenceBundle`
   でバンドル読取 → 各成果物を path-guard で読み SHA-256 再計算・突合 → 正準 artifacts
   ダイジェスト / spec_revision / git 40-hex 形状 / クロスバインドを再計算・突合 →
   `signature` を echo(未検証)→ verdict + per-artifact + per-invariant をエンベロープで返す。
2. 保守者が改竄検知テストを実行 → 1 バイト改竄・記録ハッシュ改竄・spec ドリフトが
   決定論的に mismatch として surface されることを確認。

## Edge Cases

- 成果物ファイルがディスクに存在しない → per-artifact `missing`、verdict `fail`(throw
  しない)。
- 成果物が 2 MiB 超過 → path-guard `too-large` → per-artifact `too-large`、verdict `fail`。
- 記録された `artifacts[].sha256` が 64-hex でない → `invalid-recorded-sha`、verdict `fail`。
- `spec_revision` が空("")かつ specs ファイルが 1 つも無い → computed も ""。両者一致なら
  status `match`(host の found_any=false 挙動と一致)。
- `git_commit` 欠落 / 非 40-hex → `shapeValid: false`、verdict `fail`。
- 外部/未来コミット(40-hex だが HEAD 祖先でない) → `shapeValid: true`,
  `ancestryVerified: false`、値を echo。in-process では pass/fail に寄与しない(host 責務)。
- `verification_contract` / `quality_report` が読めない・parse 不能 → 当該クロスバインドを
  `mismatch`(detail に理由)として報告、verdict `fail`。
- `signature` 存在 → present/alg を報告、`verified: false`。鍵は読まない。verdict 不変。
- バンドル自体が存在しない / JSON 不正 → `parseEvidenceBundle` のエラー
  (`not-found` / `cannot-parse`)をそのまま返す。
- 不正な feature / taskId → `invalid-input`。

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: MCP クライアント ↔ evidence_deep_verify(stdio) | なし(OS ユーザー境界に委譲) | internal(feature / taskId のみ) | なし |
| B2: evidence_deep_verify ↔ ファイルシステム(path-guard) | path-guard allowlist / denylist | internal(バンドル・成果物内容) | なし |
| B3: 署名鍵素材(~/.sdd/evidence-key ほか) | 読取禁止(path-guard denylist)・検証しない | restricted(扱わない) | なし |

詳細は `security-spec.md` を参照。

## Assumptions

- バンドルの正準形状・`evidence_canonical` 式・`spec_revision` 式・git_commit 40-hex ルールは
  `plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh` /
  `check-evidence-bundle.sh` を正準とする(design.md に逐語引用)。
- 成果物・spec ファイル・quality_report・contract は path-guard の allowlist
  (`specs/`, `reports/`, `docs/review-tickets/`, `docs/workflow-improvements/`, `AGENTS.md`)
  配下にある。allowlist 外は `path-denied` として扱う(現行 evidence ツールと同一前提)。
- 「without external tools」(Issue #68)は git・python 等のサブプロセス不使用を含み、
  したがって git 祖先検証は in-process のスコープ外(OQ-001)と解釈する。この解釈は
  ADR-0008 として記録し、人間の承認対象とする。

## Open Questions

### OQ-001: git_commit の HEAD/祖先(ancestry)検証を in-process で行うか

Issue #68 は「git_commit が 40-hex かつ HEAD-or-ancestor」を挙げるが、同時に「without
external tools」「no new exec」を硬境界とする。HEAD/祖先判定は `git merge-base
--is-ancestor` 等の git サブプロセス、または path-guard allowlist 外の `.git` 読取を要し、
read-only MCP の no-exec 境界と両立しない。既存 `parsers/evidence-bundle.ts` も同理由で
祖先検証を省略し 40-hex 形状のみ検証している(simplification #2)。

**Default(採用)**: in-process では **git_commit 40-hex 形状のみ**を検証し、HEAD/祖先
検証は host スクリプト(git を持つ)の責務として **deferred** とする。ツールは
`gitCommit.ancestryVerified: false` と値の echo・理由を明示報告し、祖先の真偽で verdict を
上下させない。これは署名暗号検証の host-deferred 姿勢および evidence-bundle.ts の
simplification #2 と一貫する。ADR-0008 で決定を記録。

Owner: 実装タスク担当
Blocks Implementation: no(本 spec の default で解消済み。実装は default に従う)
Resolution Path: ADR-0008 承認 → design.md「API / Contract Plan」の gitCommit 節に反映

## Risks

- 正準式(artifacts digest / spec_revision)が host スクリプトと**わずかでも**乖離すると
  MCP と host の判定が食い違い、誤った Done 判断を招く。→ 逐語引用 + ゴールデン一致テスト
  (AC-012)を必須とする。Risk: high。
- 署名鍵の読取経路が誤って混入すると鍵漏えいに直結する。→ path-guard denylist 再利用 +
  no-key テスト(AC-011)+ 静的検査(AC-014)で三重に防ぐ。Risk: high。
- 成果物読取での例外(欠落・巨大ファイル)が throw して応答を壊す。→ 全経路を per-artifact
  status に落とす例外安全テスト(AC-004/005)。
