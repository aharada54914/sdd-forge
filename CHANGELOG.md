# Changelog

## Unreleased

- **Capability Resolver steps 0-3 (Issue #193, epic-193-a5 T-002)**:
  Project Context の入力検証、workflow state 導出、2-pass canonicalization、
  Context Projection のメモリ内 staging、および早期 Block の 5 診断行を
  実装。`resolve-project-context-block.tests.{sh,ps1}`（共有ドライバは
  `tests/resolve-project-context-block-check.py`）で **10 invocation /
  73 アサーション** を固定した — 無効 workflow の 2 分岐を含む Block
  マトリクスの 6 invocation、step 3 Context Projection の組み立て
  2 invocation、および step 3 自身の 2 回目 canonicalizer パスの Block
  2 invocation。sh/ps1 とも 73 passed / 0 failed、TDD RED は同一ドライバで
  2 passed / 10 failed。step 3 の 35 アサーションは 14 mutation で
  非空虚性を実証済み。
  R-10 保護対象の適用候補 4 件 — `plugins/sdd-quality-loop/scripts/
  resolve-project-context.{py,sh,ps1}` と `.github/workflows/test.yml` —
  は `specs/epic-193-a5-capability-resolver/human-copy/` 配下のミラー先
  パスに staged 済み（同ディレクトリの `MANIFEST.sha256` は 4 entry で
  `shasum -a 256 -c` が 4/4 OK, exit 0）。
  **必要な人間アクション: この 4 件をレビューして適用すること。** 適用まで
  live の `plugins/**` と live の `.github/workflows/test.yml` は
  byte-unchanged で、この機能はまだ実行経路に入らない。
- **Capability Resolver steps 4-9 (Issue #193, epic-193-a5 T-003)**:
  `resolve-component-paths` 呼び出し、ADR-0025 Registry discovery +
  `validate-capability-registry`、`registry_digest`
  (`generate-registry-digest --whole`)、Capability ごと・affected
  component ごとの trigger 評価と matched Capability の
  conditional-facet 評価（いずれも `evaluate-predicate` 実呼び出し）、
  および any-branch WARN チェック（B2 の拡張スコープ）を実装。
  既存の共有スイート `tests/resolve-project-context-block.tests.{sh,ps1}`
  （共有ドライバは `tests/resolve-project-context-block-check.py`、T-002
  が新規作成・登録済みのため T-003 は新規スイート登録なし）に、この段
  自身が所有する fixture として **17 fixture directory**
（2026-08-26 ruling C(1)/C(2) 実測: 凍結文書 amendment により step 6.5
recheck を正式化して `registry-swapped-during-validation` を復帰、
absent-component fail-closed の `affected-component-absent-from-context`
を新設。同日 route-(a) cross-model panel round 2 の openai Major 是正で
`evaluate-predicate-output-malformed-nested` を追加し、step-7 の
evidence 形状検証を再帰化（`_evidence_tree_well_formed`）。round 3 の
openai Major 是正で同検証を evidenceNode contract の鏡像へ強化
（キー集合・enum・必須 path・warn→reason・children 配列限定）し、同
fixture の payload を必須フィールド欠落の子へ更新。block suite
は両ランタイム 229/0、red-baseline-recaptured-v7 は 105 passed /
117 failed）
  （`run_t003_case`: `affected-component-resolution-failed` /
  `resolve-component-paths-launch-failed` / `contract-discovery-failed` /
  `registry-discovery-unimportable` / `registry-validation-failed` /
  `validate-capability-registry-launch-failed` /
  `dependency-subprocess-failed` / `evaluate-predicate-output-malformed` /
  `dsl-warn-on-matched-capability` ×3 fixture）を追加。
  **訂正 (2026-08-23, cross-model panel remediation)**: この項目が
  以前記載していた「5 診断行・6 invocation・sh/ps1 とも 102 passed /
  0 failed」は、この共有ドライバが後続タスク（T-004 の steps 10-13、
  および本パスの panel 是正）で成長し続けた後の値とはもはや一致せず
  不正確だった（cross-model panel が T-003 自身の Critical 指摘として
  再指摘）。この共有ドライバは T-002/T-003/T-004 と本パスの是正が
  同一ファイルに同居するため、
  スイート全体の合計値をこの箇条書きに固定値として記載するのは本質的に
  すぐ陳腐化する — T-003 自身の寄与分（上記 17 fixture）
  のみをここでは確定的に記載し、スイート全体の現在合計は
  `reports/implementation/epic-193-a5-capability-resolver/T-003.md`
  「Cross-Model Panel Remediation」節、および
  `specs/epic-193-a5-capability-resolver/verification/qg/T-003/
  focused-tests-{sh,ps1}.log` を参照。
  R-10 保護対象の適用候補のうち `resolve-project-context.py` を
  steps 4-9 分だけ更新し、`.sh`/`.ps1`/`.github/workflows/test.yml` は
  byte-unchanged（新規 CI 登録なし）。`MANIFEST.sha256` は
  `resolve-project-context.py` の 1 エントリのみ更新し、
  `shasum -a 256 -c` は引き続き 4/4 OK, exit 0。
  **必要な人間アクション: T-002 と共通の staged candidate 4 件（うち
  1 件がこの更新差分）をレビューして適用すること。**
  **訂正 (2026-08-23, cycle-3 cross-model panel remediation)**: refreshed
  panel の Major 2 件を是正 — (1) `evaluate-predicate` の
  `PREDICATE_SCHEMA_ERROR` 分類がハードコードされた `returncode == 2`
  magic number に依存していた点を、`evaluate-predicate` 自身の契約が
  固定するのは exit code ではなく安定した stderr トークン
  `PREDICATE_SCHEMA_ERROR` のみである（investigation.md）ことを確認した
  上で、step 6 の `canonicalizer-failed` トークン判定と同じ方式に修正。
  (2) steps 7-8 の abort 経路（`registry-validation-failed` /
  `dependency-subprocess-failed` / `dependency-output-malformed`）が
  abort 直前まで収集済みの `severity: "warn"` diagnostics を破棄していた
  点を、AC-056 の frozen sentence（「no other id ever carries
  severity: "warn"」）と衝突しないことを確認した上で転送するよう修正。
  この段自身の寄与は **13 fixture directory・65 assertion** に増加
  （新規 2 fixture: `evaluate-predicate-schema-error` /
  `evaluate-predicate-failure-after-warn`）。スイート全体の現在合計は
  引き続き `reports/implementation/epic-193-a5-capability-resolver/
  T-003.md` および `verification/qg/T-003/focused-tests-{sh,ps1}.log`
  を参照（本箇条書きには固定値を記載しない — 直上の訂正と同じ理由）。
- **Capability Resolver steps 10-13 (Issue #193, epic-193-a5 T-004)**:
  track branch（`full` は Facet Manifest、`lite` は Capability Summary、
  同一 invocation で両方 staging されることはない — B4）、Resolver
  Evidence 組み立て（`context_binding.dependency_pointers[]` の RFC 6901
  正準導出、`resolver.version`/`resolver.rule_set_revision` の単一
  ソース化 — B9）、staged 済み全アーティファクトの出力スキーマ自己検証
  （Resolver Evidence 自身が失敗した場合は一切書き込まない唯一の例外を
  含む — B3）、および pre-publication snapshot recheck（`ownership_digest`
  だけでなく `affected_components` 集合も再導出して比較する — B8）を実装。
  既存の共有スイート `tests/resolve-project-context-block.tests.{sh,ps1}`
  （共有ドライバは `tests/resolve-project-context-block-check.py`）に、
  この段の診断行 3 種・4 invocation（`lite-check-source-undefined` /
  `output-schema-validation-failed` ×2 fixture[AC-055 の Evidence 自身
  失敗 / 非 Evidence アーティファクト失敗] / `snapshot-generation-mismatch`
  [digest-mismatch 側の最初の 1 fixture]）を追加し、sh/ps1 とも
  **121 passed / 0 failed**（T-002/T-003 由来の既存 102 assertion を
  含む）。TDD RED は同一ドライバ・同一フィクスチャ集合を T-003 時点の
  実装（steps 0-9 のみ）に対して実行し、sh/ps1 とも 107 passed / 14 failed
  で新規 4 fixture のみが一貫して失敗することを確認済み。Epic A4 の
  `capability-summary.schema.json`/`context-projection.schema.json` は
  このブランチにまだ着地していないため、この suite 自身の
  test-harness-only スタンドインを新規フィクスチャとして追加(本番コード
  側は ADR-0025 discovery 経由で実 contracts/ を読むので、Epic A4 着地後
  はそのまま実スキーマを解決する)。
  R-10 保護対象の適用候補のうち `resolve-project-context.py` を
  steps 10-13 分だけ更新し、`.sh`/`.ps1`/`.github/workflows/test.yml` は
  byte-unchanged（新規 CI 登録なし）。`MANIFEST.sha256` は
  `resolve-project-context.py` の 1 エントリのみ更新し、
  `shasum -a 256 -c` は引き続き 4/4 OK, exit 0。
  **必要な人間アクション: T-002/T-003 と共通の staged candidate 4 件
  （うち 1 件がこの更新差分）をレビューして適用すること。**
  **訂正 (2026-08-23, cycle-3 cross-model panel remediation)**: refreshed
  panel の Major 3 件を是正 — (1) 出力スキーマ自己検証の discovery に
  `$schema`/`$id` の per-artifact version check を追加（従来はファイルの
  存在とパース可否のみ確認していた）。(2) スキーマ読込/パース失敗時に
  生の例外テキストを診断へ埋め込んでいた箇所を、例外クラス名のみを含む
  安全な文言に修正（絶対パス漏洩防止）。(3)
  `_pre_publication_recheck` 自身の内部依存 subprocess 失敗が
  `snapshot-generation-mismatch` に誤ラベルされない、という Fourth Pass の
  既存修正に対して「テストが存在しない」という指摘を、実際に到達可能な
  fixture（`recheck-dependency-failed`）を追加して解消。この段自身の
  寄与は新規 3 fixture（`contract-discovery-failed-governing-schema-
  wrong-version` / `contract-discovery-failed-governing-schema-malformed`
  / `recheck-dependency-failed`）および draft-07 governing-schema
  keyword-coverage のメタアサーション（`draft7-keyword-coverage`、
  4 assertion）を追加。スイート全体の現在合計は `reports/implementation/
  epic-193-a5-capability-resolver/T-004.md`「Fifth Pass」節、および
  `verification/qg/T-004/focused-tests-{sh,ps1}.log` を参照。

- **Capability Resolver full-pipeline match suite (Issue #193, epic-193-a5
  T-005)**: T-002/T-003/T-004 が実装済みの評価パイプライン（steps 0-13）を
  実サブプロセス経由で end-to-end に検証する新規スイート
  `tests/resolve-project-context-match.tests.{sh,ps1}`（共有ドライバ
  `tests/resolve-project-context-match-check.py`）を追加し、`tests/run-all.
  {sh,ps1}` に登録。sh/ps1 とも **125 passed / 0 failed**（2026-08-26
gate cycle-1 実測更新; 初回記載の 59 は登録時点の値）。union-match
  (AC-006)、cross-Capability / 同一 Capability 内の同名 facet 二重宣言の
  facet-name 集約 (AC-043/AC-052)、Context Projection のバイト一致
  (AC-003)、`resolve-component-paths`/`generate-registry-digest --whole`
  の引数パススルー・バインディング (AC-004/AC-005)、advisory/required 間の
  Resolver Evidence バイト一致 (AC-016) を、いずれも実 fixture 経由で検証。
  **この branch では public writes が T-007 の step 14（未着地）に一元化
  されているため**、Facet Manifest 自身の内容（AC-007 field-assembly /
  AC-008 schema-conformance）は、この suite 自身のドライバが同一の
  staged `.py` を `importlib` 経由でロードし、実サブプロセス実行で
  既に検証済みの `capability_evaluations[]` を渡して
  `_assemble_facet_manifest` 等の本番関数をそのまま呼び出す形で再構成し、
  実の `validate-facet-manifest` に対して検証する手法（本タスクの実装
  レポート「Specification Differences」で開示）を採用。**AC-056
  （`diagnostics[]` の warn/block cardinality）は同日中の第2パスで実装
  完了**——`_write_evidence`/`_block` を、`outcome: "warn"` ノード1件に
  つき `severity: "warn"` エントリ1件を追加し、既存の要約
  `severity: "block"` エントリ1件がそれに続く形へ拡張(この production
  側の修正は T-004 自身の宣言済みスコープ内での完了作業として T-004 が
  実施、T-005 は REQ-006 item (d) の既存 any-branch-WARN fixture 再利用
  1件＋新規 multi-node fixture 1件を TDD RED→GREEN で追加し、2方向の
  mutation kill も確認済み)。詳細は両タスクの実装レポート「Second Pass —
  AC-056 Remediation」節を参照。
### Added

- **Facet Manifest schema と validator (Issue #192,
  epic-192-a4-facet-manifest T-001)**: `contracts/facet-manifest.schema.json`
  (draft-07、vendored copy を `plugins/sdd-quality-loop/contracts/` に同梱)
  と手書き draft-07 部分エンジンの `validate-facet-manifest.{py,sh,ps1}`
  を追加。schema conformance と semantic checks の 2 スイート
  (`tests/facet-manifest-{schema,semantics}.tests.{sh,ps1}`、fixture 60 件)
  を `tests/run-all.{sh,ps1}` に登録し、公式 draft-07 メタスキーマ検証と
  jsonschema 4.26.0 クロス検証で相違なしを記録。CI ステップ候補は
  `specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml`
  として staged 済みで `MANIFEST.sha256` に hash 束縛されている。
- **Capability Summary schema と validator (Issue #192,
  epic-192-a4-facet-manifest T-002)**: `contracts/capability-summary.
  schema.json` (draft-07、Lite トラック専用の 6 フィールドのみ、vendored
  copy を `plugins/sdd-quality-loop/contracts/` に同梱) と、T-001 の
  手書き draft-07 部分エンジンを踏襲した
  `validate-capability-summary.{py,sh,ps1}`（schema conformance のみ、
  semantic check なし）を追加。1 スイート
  (`tests/capability-summary-schema.tests.{sh,ps1}`、fixture 13 件、
  22/22 assertion 両ランタイム一致)を `tests/run-all.{sh,ps1}` に登録し、
  公式 draft-07 メタスキーマ検証と jsonschema 4.26.0 クロス検証を記録。CI
  ステップ候補は T-001 の staged candidate に追記し、
  `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256` を新しい
  hash に更新した。
- **Context Projection schema と validator (Issue #192,
  epic-192-a4-facet-manifest T-003)**: `contracts/context-projection.
  schema.json` (draft-07、`components` の再キー化形状 (`propertyNames`+
  schema-typed `additionalProperties`)・`shared_paths[]` の bounded/
  unbounded `oneOf` 分岐を固定、vendored copy を
  `plugins/sdd-quality-loop/contracts/` に同梱) と、T-001/T-002 の
  手書き draft-07 部分エンジンを踏襲した
  `validate-context-projection.{py,sh,ps1}`（schema conformance のみ、
  YAML/canonicalizer subprocess なし — 対象は既に JSON の
  `project-context.resolved.json`）を追加。1 スイート
  (`tests/context-projection-schema.tests.{sh,ps1}`、fixture 24 件、
  35/35 assertion 両ランタイム一致)を `tests/run-all.{sh,ps1}` に登録し、
  公式 draft-07 メタスキーマ検証と jsonschema 4.26.0 クロス検証を記録。CI
  ステップ候補は T-002 の staged candidate に追記し、
  `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256` を新しい
  hash に更新した。
- **Facet Manifest staleness comparator (Issue #192,
  epic-192-a4-facet-manifest T-004)**:
  `compare-facet-manifest-staleness.{py,sh,ps1}` を追加 — REQ-004 の
  Policy-Weakening fail-closed 契約（`--projection-weakening`/
  `--registry-weakening`/`--ownership-weakening` の 3 フラグは省略不可の
  必須三値入力、省略は `indeterminate` の代替表現ではなく引数エラー
  exit 3）と REQ-005 の 3 段階 `resolver.version` ポリシー（patch/minor/
  major、同一バージョンでの `rule_set_revision` 変更用に独立した
  `minor-rule-set` 入力）を design.md の 5 分岐優先順位表通りに実装。
  `<status>:<reason>` を stdout に一行、exit 0/1/2 は fresh/stale/blocked
  に固定マップ、引数・schema-invalid・resolver-version-bump 不整合は
  stderr のみへの exit 3 診断で分離。`validate-facet-manifest.py` の
  schema-conformance チェックを同ディレクトリ import で再利用し、両
  `--old-manifest`/`--new-manifest` を比較前に検証。この import は遅延・
  例外包囲されており、sibling validator が欠落・破損している場合は
  `validator-import-failed` を stderr へ 1 行出して exit 3 で閉じる
  （exit 1 = `stale` 判定として偽装しない）。1 スイート
  (`tests/facet-manifest-staleness.tests.{sh,ps1}`、fixture 24 件、
  48/48 assertion 両ランタイム完全一致)を `tests/run-all.{sh,ps1}` に
  登録。CI ステップ候補は T-003 の staged candidate に追記し、
  `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256` を新しい
  hash に更新した。
- **Vendored-copy drift ゲート拡張 + cross-script parity suite (Issue #192,
  epic-192-a4-facet-manifest T-005、FINAL)**: Epic A2 の
  `vendor-capability-registry.py --check`（実在確認済みの既存 `--check`
  機構）を `facet-manifest.schema.json`/`capability-summary.schema.json`/
  `context-projection.schema.json` の 3 ファイルへ追加のみで拡張（新規
  スクリプトは作成せず）。`tests/facet-manifest-parity.tests.{sh,ps1}`
  を新設し、T-001〜T-004 の 4 スクリプト全ての `.py`/`.sh`/`.ps1` 呼び出し
  を suites 1-5 の全 fixture（Windows 形式のバックスラッシュパス引数と
  `compare-facet-manifest-staleness` 自身の exit-3 stderr チャンネルを
  含む）に対して実行し、stdout/stderr/exit code の byte-identical parity
  を検証。4 スクリプト×3 ランタイムのインストール済みレイアウト discovery
  fixture（vendored copy のみ・monorepo `contracts/` なし・到達可能な
  `.git` なし）、Epic A2 の provider-neutrality allowlist に対する 3
  schema + 12 スクリプトファイル（4 スクリプト×`.py`/`.sh`/`.ps1`）の
  スキャン（clean/dirty/lambda-dirty fixture 付き）も実装。1 スイート
  (329/329 assertion 両ランタイム完全一致) を `tests/run-all.{sh,ps1}` に
  登録し、この feature の 6 スイート全てを網羅する FINAL な CI ステップ
  候補を
  `specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml`
  として staged し、`MANIFEST.sha256`/`APPLY-INSTRUCTIONS.md` を更新した。
  併せて、T-001〜T-004 の quality-gate 教訓として
  `validate-facet-manifest.py`/`validate-capability-summary.py` の
  非 UTF-8 入力時の未捕捉トレースバック（`except (OSError,
  json.JSONDecodeError)` を `except (OSError, ValueError)` へ）と、
  `compare-facet-manifest-staleness.py` の sibling-import ガードが
  `SystemExit` を捕捉していなかった欠陥（`except Exception` を
  `except (Exception, SystemExit)` へ）を修正し、各修正に回帰テストを
  追加した。**seq0763 quality-gate 是正（同日）**: `.ps1` twin の
  `Start-Process -RedirectStandardOutput/-RedirectStandardError` が CRLF を
  LF へ無音正規化する欠陥（Critical）を発見し、`System.Diagnostics.Process`
  + `BaseStream.CopyToAsync` によるバイト捕捉へ全面書き換え、明示的な
  「CR バイト非含有」アサーションを新設。provider-neutrality スキャンの
  `lambda` 語まるごと除外が実際の汚染を見逃す欠陥（Major）を発見し、
  `key=lambda` イディオムのみをマスクする方式へ修正。fixture 件数の
  非空虚性ガード・RED 証跡 3 分岐化も追加し、329/329 へ拡大した。

### Fixed

- **Release-state coupling in two CI gates**: the `version-gates` lane went
  red on `main` immediately after the v1.15.0 release because two suites
  asserted against the `## Unreleased` CHANGELOG heading that
  `scripts/bump-version.sh` had just legitimately renamed.
  `bump-version-gate.tests.{sh,ps1}` now inserts the fixture's version
  heading when the copied CHANGELOG carries no `## Unreleased` section, and
  asserts that postcondition instead of letting a no-op rename fail every
  case on the CHANGELOG precondition; `ownership-digest.tests.{sh,ps1}`
  TEST-048 now locates the T-003 entry in whichever release-notes section
  holds it, still requiring both citations together in one section, the same
  later-release exemption TEST-049 already documents.

### Corrections

- **v1.15.0 の Node runtime baseline エントリの訂正**: v1.15.0 の
  「Node runtime baseline migration」エントリは「CI updated to run the MCP
  lanes on Node 22 and a limited Ubuntu Node 24 forward-compat check」と
  記載しているが、この CI 側の変更は着地していない。実測では
  `.github/workflows/test.yml` の MCP レーン 3 箇所 (843 / 899 / 951 行目)
  はいずれも `node-version: "20"` のままであり、`.github/workflows/` 配下に
  Node 24 のレーンは存在しない。当該変更は
  `docs/ci-staging/node22-runtime-baseline.md` に staged された状態で
  留まっており、同ファイル 3 行目は `Status: Pending human application`
  (保護対象は `.github/workflows/test.yml`) と記載している。一方で
  `mcp/ci-mcp`・`mcp/local-env-mcp`・`mcp/sdd-forge-mcp` の各
  `package.json` は `engines.node: ">=22.19.0"` を宣言済みであるため、
  出荷パッケージが要求する Node バージョンを CI が一度も実行していない
  状態にある。v1.15.0 の記述自体はリリース済みの履歴として書き換えない。

## v1.15.0 (2026-08-16)

### Added

- **Node runtime baseline migration**: MCP package engines and installer
  gating now require Node.js >= 22.19.0, with CI updated to run the MCP
  lanes on Node 22 and a limited Ubuntu Node 24 forward-compat check.

- **Component path ownership dual-runtime parity (Issue #191,
  epic-191-a3-path-ownership T-006)**: added direct Bash/PowerShell product-
  wrapper parity coverage for canonical JSON, exit status, diagnostics, and
  unknown-argument pass-through across the resolver and reverse-coverage
  pairs. The resolver PowerShell twin now rejects unknown arguments with the
  Python master's exit-2 contract; the protected coverage twin fix and the
  parity suite's CI steps are hash-bound under the feature's `human-copy/`
  staging tree for human application.

- **Full-input ownership digest (Issue #191,
  epic-191-a3-path-ownership T-003)**: `resolve-component-paths` now hashes
  every declared component include/exclude rule, every bounded or
  cross-cutting shared-path rule, and the matcher-semantics version through
  the repository canonicalizer. Both resolver runtimes emit the identical
  digest in ADR-0021's `context_binding` together with resolver provenance;
  dedicated Bash/PowerShell acceptance suites pin full-input behavior,
  selective-staleness semantics, the six-row freshness matrix, and staged
  CI/run-all wiring.

- **component path ownership resolver の A1 契約追従完了 (Issue #191,
  epic-191-a3-path-ownership T-001)**: `resolve-component-paths.{py,sh,ps1}`
  を landed 済みの `contracts/project-context.schema.json` /
  `project-context.template.yaml` に適合させ、`components[].id`、空の
  `components: []`、bounded/cross-cutting `shared_paths` の排他的形状を
  fail-closed で検証する。グロブ、raw-byte sort、分類、exclude 証跡、
  大文字小文字を区別する契約検査を Bash/PowerShell twin で固定し、ADR は
  drafting-time の番号再検証により `0027` とした。CI ステップ候補は
  `specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml`
  として staged 済みで `MANIFEST.sha256` に hash 束縛されている
  (2026-08-11 訂正: 旧文「保護領域への書込みを避けるため CI ステップ候補は
  実装レポート配下の hash 検証済みドラフトに記録した」は HEAD の実態と
  矛盾していた — human-copy 候補はこのタスク自身の初回書込み `41881071`
  以来実在し、ガードの staging 免除により書込み可能。旧ドラフト経由の
  記録は superseded)。この 2026-08-08 エントリは v1.11.0 の T-001 記録に残る
  「A1 未着地」「human-copy staging 未作成」という当時の状態を現在状態に
  ついてのみ訂正し、リリース履歴自体は変更しない。

- **Reverse Coverage Gate と --diagnose (Issue #191,
  epic-191-a3-path-ownership T-004)**: `plugins/sdd-quality-loop/scripts/
  check-component-coverage.{py,ps1,sh}` を新規追加(Python master + 独立
  PowerShell twin + 薄い bash dispatcher、INV-008)。常に完走し常に
  `check-component-coverage-verdict/v1` エビデンスレコード(`producer.sha256`
  同梱)を出力する。`workflow.capability_enforcement` の値(ADR-0016)から
  `disabled-legacy`/`advisory`/`required` の三状態を導出し(Facet Manifest
  の有無からは導出しない)、`disabled-legacy` は評価ゼロで実 N/A・exit 0、
  `advisory`/`required` は Facet Manifest 構造的必須(欠落は exit 2、
  Fail 発火時の exit 1 と明確に区別)で六つの Fail 条件(UNOWNED /
  EXCLUSIVE owner 欠落 / OVERLAP / bounded shared_paths owner 欠落 /
  resolver の `EXCLUDED_MATCH` エビデンス到達 / Provider Adapter/Binding
  drift)を全評価し、`required` のみ Fail 発火時 exit 1。非 Gate の
  `resolve-component-paths --diagnose`/`-Diagnose` サブコマンドを両
  resolver twin に追加(独自 schema、Gate の schema とは別、
  `quality-gate/SKILL.md` からは呼ばれない)。`risk-gate-matrix.md`
  (`high`/`critical` 必須チェックセットへ追加)・`quality-gate/SKILL.md`
  (`## Process` への記載)を直接編集(いずれも非保護ファイル、defense-in-depth
  として文書化するのみで実際の到達保証は required-check-set 登録そのもの)。
  新スイート `tests/check-component-coverage.tests.sh` / `.ps1`
  (TEST-026〜036、TEST-046、TEST-052〜055)を、Epic A4/A1 の実スキーマに
  一切依存しない自己完結フィクスチャ Facet Manifest / Provider Bindings
  で駆動し、両ランタイムで29/29 green(このタスクの Scope 内では外部依存
  ブロックなし)。`tests/run-all.sh` / `.ps1` へ自己登録。R-10 保護ファイル
  である Bundle A(`guard-invariants.json`・`generate-guard-invariants.py`・
  `generated/*` 4件)・Bundle B(`check-contract.{sh,ps1,py}`)への
  human-copy staging、および `.github/workflows/test.yml` への本タスク
  分 CI ステップ追加は、T-001/T-002 と同一の Claude Code PreToolUse フック
  (`sdd-hook-guard.sh`)によりブロックされ本コミットには含まれていない。
  Bundle A の候補内容は実際の `generate-guard-invariants.py` をスクラッチ
  作業コピーへ適用して生成・`--check` で内部整合性検証済み、Bundle B は
  必要な変更内容を仕様として正確に記述(いずれも
  `reports/implementation/epic-191-a3-path-ownership/T-004.md` の
  Unresolved Items 参照)。

- **git-diff basis collector (Issue #191, epic-191-a3-path-ownership
  T-002)**: `plugins/sdd-quality-loop/scripts/resolve-component-paths.{py,ps1}`
  に `--source-rev`/`--target-rev`/`--include-untracked`/`--repo-root` を
  追加し、実 git 差分から変更パス集合を収集する経路を新設(T-001 の
  `--changed-paths-file`/stdin 経路は `--target-rev` 省略時の代替として
  存続)。`git rev-parse --verify <rev>^{commit}` で source/target を
  commit OID に解決してから `git merge-base` を計算し、解決不能な rev や
  共通祖先のない履歴は fail-closed。`baseline..worktree`(staged +
  unstaged)+ `git ls-files --others --exclude-standard -z`(untracked)を
  それぞれ一度だけ収集し、全ての path 列挙コマンドを NUL 区切りの生バイト
  として解析(改行分割は一切行わない、不正 UTF-8 バイト列は fail-closed)。
  リネームは固定閾値(類似度 50%)・固定 `diff.renameLimit`(1000)・
  `--no-ext-diff` で追跡し、rename 前後のパスを独立に分類、component
  境界を跨ぐリネームは `diff_basis.renames[].cross_component: true` として
  明示。submodule/symlink は `--ignore-submodules=dirty` により
  「dirty だが pointer 未変更」は完全に無視、gitlink OID 変更・symlink
  自身の target-text 変更は報告、symlink が指す先の内容のみの変更は
  symlink 自身のパスには一切現れない(実ディスポーザブル fixture リポジトリ
  で四ケース全て検証)。単一書き手/TOCTOU スナップショット(HEAD OID +
  ポーセリン status のハッシュ)を収集開始前後で比較し、不一致は1回だけ
  リトライしてから fail-closed。新スイート
  `tests/component-path-diff-basis.tests.sh` / `.ps1`(TEST-019〜025、
  test 実行時に mktemp 配下へ使い捨て git リポジトリを作成、本リポジトリ
  自身の履歴は一切使わない)を追加し、両ランタイムで17/17 green
  (Epic A1/A4 への外部依存なし、T-001/T-005と異なりこのタスク自体は
  完全 green)。`tests/run-all.sh` / `.ps1` へ自己登録。R-10 保護ファイル
  である `.github/workflows/test.yml` への human-copy staging は
  T-001 と同一の Claude Code PreToolUse フック(`sdd-hook-guard.sh`)に
  よりブロックされ本コミットには含まれていない
  (`reports/implementation/epic-191-a3-path-ownership/T-002.md` の
  Unresolved Items 参照、既報告のブロッカーの再現であり新規事象ではない)。

- **cross-epic cross-cutting seed inventory 検証 (Issue #191,
  epic-191-a3-path-ownership T-005)**: `tests/component-path-resolver.tests.sh`
  / `.ps1`(T-001既登録のスイート、新規スイート・新規 `tests/run-all.sh`
  / `.ps1` 登録・`.github/workflows/test.yml` 追加ステップは一切なし)に
  TEST-042/TEST-042-negative/TEST-043/TEST-044 を追加。Epic A1 の
  `contracts/project-context.template.yaml` の `shared_paths` cross-cutting
  セクションが `specs/**`・`reports/**`・`docs/**`・`.github/**`・
  `tests/fixtures/**`・`CHANGELOG.md` の六項目に厳密一致し `contracts/**`
  が含まれないことを検証する唯一の正典ソースとして扱い、A3 側は競合する
  seed-list ドキュメントを一切持たない(REQ-006)。TEST-043 は
  `tests/fixtures/component-path-ownership/test-043-cross-cutting-no-op/`
  という自己完結フィクスチャで、六項目に触れる diff がゼロ declared
  owners でも Fail-1(UNOWNED)を絶対に誘発しないことを実証(今日時点で
  green)。TEST-042/TEST-044 は Epic A1 の実アーティファクトを直接読む
  ため、それが着地するまで恒久的に red(T-001 の TEST-011.3 と同一の
  意図された外部依存性ブロック、バグではない、再確認済み:
  `contracts/project-context.template.yaml` は本コミット時点でも不在)。
  TEST-042-negative は inventory-conformance チェック関数
  (`check_inventory_conformance` / `Test-InventoryConformance`)を
  意図的に誤った seed set に対して実行し、チェックが恒常的に true を
  返す vacuous な実装でないことを証明(acceptance-first の RED エビデンス)。

### Fixed

- **human-copy publisher のファイルモード保持 (epic-189-a1-project-context,
  staged candidate)**: `apply-human-copy.sh`/`.ps1` が publish 時に staged
  ファイルのモードを保持せず、全ターゲットが 0600 で着地するバグを修正
  (sh 側は `mktemp`(0600) + `cat` + `mv` のため。実行可能な保護ターゲットが
  exec bit を失い、publisher 自身を publish すると次バッチが
  `Permission denied` で死ぬ)。契約は design.md の transactional bundle
  contract に基づき「**STAGED candidate のモードを適用する**」を採用 —
  live の既存モードは参照しない (live は publish が上書きすべき
  drift/改竄面そのもの)。対称性として `pre/` バックアップが live の
  PRE モードを捕捉し、rollback がそれを復元する。ps1 側は
  `[System.IO.File]::Copy` の暗黙のモード複製に依存していた挙動を
  `Get/SetUnixFileMode` で明示化 (Windows では no-op)。R-10 保護のため
  修正は staged candidate
  (`specs/epic-189-a1-project-context/human-copy/`) として作成し、
  `MANIFEST.sha256` と `RUNBOOK-pr229.md` を更新 (Step 2 の一括 chmod
  ワークアラウンドは、旧 publisher が実行する batch 1 の自己置換 1 件を
  残して撤去)。`tests/apply-human-copy.tests.sh`/`.ps1` に
  `TEST-MODE-PRESERVE` ブロックを追加 (実行可能/非実行可能ターゲットの
  publish、既存 live モードに対する staged モード優先、mid-batch crash
  後の rollback のモード忠実性。sh 247 passed / ps1 168 passed)。
  副産物: BSD/macOS の `chmod` は `--` を end-of-options として扱わない
  (bogus operand 扱いで nonzero exit) ことを実測で確認し、該当呼び出しに
  インライン文書化。
### 修正

- **`tests/run-all.sh` / `.ps1` が最初の失敗スイートで全体を中断していた問題**:
  両ランナーはスイートを直列実行し、最初の非ゼロ終了で `set -e` / `throw` に
  より打ち切っていたため、下流スイートが「通っている」のか「そもそも実行され
  ていない」のか区別できなかった。スイート同士は相互独立なので、これは無関係な
  不具合の集合を「1 CI ラウンドトリップにつき 1 件」の直列発見キューへ変える。
  実測例: POSIX レーンで 21 番目の `turn-first-workflow.tests.sh` が落ちると、
  以降の約 40 スイートは一度も実行されない。全スイートを最後まで実行し、失敗を
  `FAILED: <suite>` 行で即時に示したうえで末尾に一覧を出力し、1 件でも失敗が
  あれば終了コード 1 を返すよう変更。`==>` 進捗行・`tests` 配列・全 green 時の
  最終行 (`All POSIX regression tests passed.` /
  `All PowerShell regression tests passed.`) と終了コード 0 は不変なので、
  スイート名を grep する自己登録チェック群には影響しない。POSIX レーンでは
  pwsh 版 `guard-r10-port.tests.ps1` も同様に集約対象となり、従来は先行スイート
  が落ちると一度も実行されなかったものが実行される。なお同じ欠陥クラスを
  `check-workflow-state.{sh,ps1}` について扱う WFI-021 は Draft 段階であり、
  その Proposed Change にこの 2 ランナーは含まれない。
### Corrections

- **v1.12.0 の Issue #125 エントリの訂正 (epic-136-phase3, Stream C)**:
  v1.12.0 の #125 エントリは「`.github/workflows/test.yml` への CI ステップ
  登録は requirements.md Non-goals により後続フィーチャーへ意図的に
  deferred」と記載しているが、これは現在の設計と実物の両方に対して誤り。
  requirements.md Non-goals が禁じているのは「Stream B と C が自前の
  **2 個目の**別 human-copy バッチを作ること」であって、共有された 1 個の
  バッチに乗ること自体ではない。ADR-0010 が `Status: Accepted`
  (commit `67015a5`) になって Stream C の Blocker が解消され、その
  スイートが本フィーチャーで着地した時点で、
  `tests/workflow-scenarios/workflow-scenarios.tests.sh` の CI ステップは
  T-003 の唯一の共有バッチに含まれるようになった
  (`specs/epic-136-phase3/verification/T-003/staged-workflow-candidate.draft.yml`
  で実測確認)。deferred のままにすると、着地済みのスイートが INV-006 の
  no-wildcard ルールにより CI で一度も実行されない — REQ-005 が塞ぐために
  存在する当のギャップを再生産することになる。v1.12.0 の記述自体は
  リリース済みの履歴として書き換えない。

## v1.14.0 (2026-08-05)


- **project-context / provider-bindings スキーマ + 単一ソース seed テンプレート
  (Issue #189, epic-189-a1-project-context T-001)**:
  `contracts/project-context.schema.json`(schema id
  `sdd-project-context/v1`)と `contracts/provider-bindings.schema.json`
  (schema id `sdd-provider-bindings/v1`)を新規追加。`workflow.spec_profile`/
  `artifact_layout`/`capability_enforcement` の3値と `components[].id`・
  `platform_targets[].{os,architecture}` のみを REQUIRED とし、他の
  `components[]` フィールド(`artifact_kinds`/`runtime_classes`/
  `characteristics.*`/`distribution_channels`/`data_classification`/
  `provider_binding_ids`/`paths`)は任意。ADR-0020 の条件述語 DSL が参照する
  8つのallowlistパス全てがスキーマフィールドとして解決することを検証。
  `provider-bindings` 側は `provider`/`product`/`purpose` を固定enumなしの
  自由文字列とし(provider-neutrality)、`state_authority`/`credentials`は
  任意の任意形オブジェクト、`adapter_paths`(Epic A3 Reverse Coverage Gate
  消費予定)は任意のglob文字列配列。`components[].id`/`bindings[].id` の
  重複拒否はJSON Schema自体ではなく意味検証層の責務であることを、重複
  フィクスチャがスキーマ単体は通過しつつ意味チェックでは
  `DUPLICATE_COMPONENT_ID`/`DUPLICATE_BINDING_ID` として拒否されることで
  証明。`contracts/project-context.template.yaml` は Epic A1/A3 共通の
  単一ソース cross-cutting seed 一覧(`specs/**`/`reports/**`/`docs/**`/
  `.github/**`/`tests/fixtures/**`/`CHANGELOG.md`、各
  `classification: cross-cutting`)を含む汎用スキャフォールドとして追加。
  `tests/project-context-schema.tests.sh`/`.ps1` が44アサーションで
  受け入れ先行検証(acceptance-first)を実施、両ランタイムで実行し
  PASS(`specs/epic-189-a1-project-context/verification/T-001/`)。
  `tests/run-all.sh`/`.ps1` へ自スイートを直接登録。R-10 保護ファイルで
  ある CI ワークフロー定義ファイルへの新規CIステップの反映は、staging
  メカニズム自体が現状のガード実装(パス末尾一致)によりブロックされる
  ため未完了 — 詳細と意図した挿入内容は
  `reports/implementation/epic-189-a1-project-context/T-001.md` と
  `tasks.md` の T-001 Blockers を参照。詳細実装は
  `reports/implementation/epic-189-a1-project-context/T-001.md`。
- **approver-registry スキーマ (Issue #189, epic-189-a1-project-context
  T-004)**: `contracts/approver-registry.schema.json`(schema id
  `sdd-approver-registry/v1`)を新規追加。`approvers[]` の `id`(不変の
  identity key)・`name`(可変の表示ラベル、identity比較には一切使用しない)
  を REQUIRED、`registered_at` は任意。`approvers: []` の空配列は
  スキーマとして正当(T-005/T-006が構築する2名承認/フェイルクローズド
  判定の前提条件)。`components[].id`/`bindings[].id`(T-001)と同型の
  意味検証層による重複`id`拒否(`DUPLICATE_APPROVER_REGISTRY_ID`)を、
  重複フィクスチャがスキーマ単体は通過することの証明とあわせて実装。
  TDD Red(スキーマ未実装で8件中7件fail)→ Green(実装後8件全PASS)を
  `bash`/`pwsh` 双方で実行・記録
  (`specs/epic-189-a1-project-context/verification/T-004/`)。
  `tests/approver-registry-schema.tests.sh`/`.ps1` を
  `tests/run-all.sh`/`.ps1` へ登録。CI ワークフロー登録はT-001と同じ
  guard 制約により未完了。詳細実装は
  `reports/implementation/epic-189-a1-project-context/T-004.md`。
- **canonicalizer `canonicalize-sdd-yaml` (Issue #189, epic-189-a1-project-context
  T-002)**: `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py` を
  新規追加 — HAND-WRITTEN・stdlib-only の制限付きYAMLサブセットパーサー
  (PyYAML/ruamel.yaml 等サードパーティ依存なし、`requirements.txt` 新設なし。
  人間判断3 = B、`reports/notes/epic-189-a1-decision-3-yaml-parser.md`)。
  YAML 1.2 core schema によるプレーンスカラー解決(`yes`/`no`/`on`/`off` は
  1.1 専用トークンとして文字列のまま維持)、anchor/alias/カスタムタグ/
  重複キー/非文字列キーを各専用診断カテゴリで拒否、Unicode NFC 正規化後の
  post-NFC 重複キー衝突検出、非有限(`.inf`/`.nan`)・IEEE-754 倍精度範囲外
  数値の拒否を実装。RFC 8785 (JCS) 準拠の正準 JSON バイト列出力
  (`--hash-only` で SHA-256 のみ出力)と、ECMAScript Number::toString
  相当の数値フォーマット(固定/指数表記の境界を含む)を実装。JSON 入力
  モードも受理(T-003 の HMAC preimage 経路向け)。`.sh`/`.ps1`/`.js` は
  `python3`/`python` 解決のみを行う薄いディスパッチャで、いずれもネイティブ
  再実装を持たない(`.ps1` も `sdd-hook-guard.sh` の PowerShell ネイティブ
  フォールバック形は踏襲しない) — 4ランタイム全てが同一 SHA-256 を生成する
  ことと、各ラッパーが `canonicalize-sdd-yaml.py` へ実際にディスパッチして
  いる(単体では動作しない)ことを`tests/canonicalize-sdd-yaml.tests.sh`/
  `.ps1` で証明。カテゴリ別に安定した終了コード(2/3/10/11/20-28)を割当て、
  診断は stderr のみ・正常時は stdout をバイト完全出力。TDD Red(未実装で
  bash 19件/29件・pwsh クラッシュ)→ Green(実装後 bash 29/29・pwsh 26/26 全
  PASS)を`bash`/`pwsh` 双方で実行・記録
  (`specs/epic-189-a1-project-context/verification/T-002/`)。
  `tests/canonicalize-sdd-yaml.tests.sh`/`.ps1` を`tests/run-all.sh`/`.ps1`
  へT-001の直後・T-004の直前(数値順)に登録。CI ワークフロー登録は、
  T-001/T-004 と同じ human-copy staging 領域に別セッションの未コミット
  ステージング内容が存在するため、それらと競合しないよう本タスクでは延期
  (詳細実装は`reports/implementation/epic-189-a1-project-context/T-002.md`)。
- **承認サイドカー・スキーマ + staging-only 署名ツール `generate-approval-sidecar`
  (Issue #189, epic-189-a1-project-context T-003)**:
  `contracts/approval-sidecar.schema.json`(schema id
  `sdd-project-context-approval/v1`/`sdd-provider-bindings-approval/v1`)と
  `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py` を新規追加。
  `--content` の内容ファイルを T-002 の canonicalizer(`--hash-only`)へ
  サブプロセスとして dispatch して `context_sha256` を算出、`--approver`/
  `--second-approver`/`--status`/`--effective-at` を受理し、
  `primary_approval.approver == second_approval.approver` の場合は
  ハッシュ計算前に `DUPLICATE_APPROVER_IDENTITY` で拒否。HMAC preimage は
  `hmac` フィールドを除いた承認オブジェクト全体を canonicalizer の JSON
  入力モードへ dispatch して得た正準バイト列(TEST-036: ゴールデンベクタ
  1件 + 全8フィールド由来の15種の単一フィールド変異、各変異で HMAC が
  変化することを証明)。`SDD_CONTEXT_KEY` は `_resolve_sudo_key`/
  `resolve_evidence_key` と同一の4段解決順序(env var → env-file →
  home-path → キーなしは fail-closed)をバイト単位で再実装せずミラー
  (TEST-013 で `sdd-hook-guard.py` に対するバイトパリティを証明)。
  provenance フィールド(`predecessor_context_sha256`/`weakening_verdict`/
  `approval_epoch`)は現存する live サイドカー(`--live-sidecar`)の
  有無で分岐: 不在なら bootstrap として null/null/1 を即座に確定・署名
  完了。存在する場合は `predecessor_context_sha256`/`approval_epoch+1` を
  読み取った上で、T-005 の `detect-policy-weakening.py` を in-process で
  呼び出す唯一の呼び出し口(seam)を通す — T-005 未着手の現時点では
  当該モジュールが存在しないため、この seam は常に
  `WEAKENING_DETECTOR_UNAVAILABLE` で fail-closed し、署名も staging も
  一切行わない(呼び出し元から検証済み verdict を受理することは決してない
  設計)。出力は live サイドカー/anchor パスを一切書き込まず、
  `sdd/.staging/<schema-id>/<nonce>/` 配下へ署名済み候補・
  approved-context バイト完全スナップショット・`MANIFEST.sha256`
  (nonce 埋め込み)の3点のみを一時ディレクトリ経由の単一アトミック
  rename で staging(TEST-034: シミュレートした書き込み途中失敗が
  最終 staging パスに部分的な成果物を一切残さないこと、失敗後の再実行が
  新しい nonce で成功することを証明)。`--dump-preimage`(AC-012 専用の
  非本番コードパス)は `hmac` の自己参照除外を証明する内部テストフック。
  `.sh`/`.ps1` は `python3`/`python` 解決のみを行う薄いディスパッチャ
  (T-002 と同型)。TDD Red(未実装で bash 29/50・pwsh クラッシュ)→
  Green(実装後 bash 50/50・pwsh 48/48 全 PASS)を`bash`/`pwsh` 双方で
  実行・記録(`specs/epic-189-a1-project-context/verification/T-003/`、
  seam の bootstrap/fail-closed 実行ログを含む)。
  `tests/generate-approval-sidecar.tests.sh`/`.ps1` を`tests/run-all.sh`/
  `.ps1` へ T-002 の直後・T-004 の直前(数値順)に登録。CI ワークフロー
  登録は、T-001/T-002/T-004 と同じ human-copy staging 領域に別セッションの
  未コミットステージング内容(T-001/T-004 分)が存在するため、それらと
  競合しないよう本タスクでは延期(詳細実装は
  `reports/implementation/epic-189-a1-project-context/T-003.md`)。
- **ポリシー弱体化検出ツール `detect-policy-weakening` + 配線完了
  (Issue #189, epic-189-a1-project-context T-005)**:
  `plugins/sdd-quality-loop/scripts/detect-policy-weakening.py` を新規追加 —
  decision doc §9 の正準9カテゴリのうち実装済み3カテゴリ
  (`capability_enforcement` の `required`→`advisory` 弱体化、
  scope-prefix 集合演算によるコンポーネントパス縮小アルゴリズム(パターン
  削除・同数置換・exclude追加・exclude広域化・純粋拡大の5境界ケース全証明)、
  `spec_profile` の `full`→`lite` 移行)を直接フィールド比較で判定し、
  残り6カテゴリ(Capability削除・公開配布縮小・重要度低下・Provider
  allowlist拡大・本番書き込みパス変更・必須Gate削除)は全実行で明示的に
  `n/a` と報告(プロキシ分類なし、決して黙殺しない)。信頼アンカーは
  `git HEAD` ではなく `sdd/.approved-context/<schema>.approved.yaml` を
  ツール内部で解決(本番呼び出し経路は `--approved-context` を一切
  渡さない — 通常のコミットではアンカーを一切動かせないことをgit-commit
  不変性テストで証明)。アンカー未存在(初回bootstrap)は
  `NO_APPROVED_CONTEXT_ANCHOR` として全カテゴリ `not_weakened`/`n/a` を
  返す文書化された非エラー条件。ポリシー弱体化と判定された場合のみ
  `sdd/approver-registry.yaml`(T-004のスキーマ)の DISTINCT `id` 数を
  数え、2以上で `two_person_required: true`、それ未満(0または1、
  レジストリ不在含む)で `two_person_required: false, cooldown_hours: 24`
  を出力。`sdd/.staging/*/TRANSACTION.json` が読み取り対象パスを含む
  場合は `HUMAN_COPY_PUBLISH_IN_PROGRESS` でフェイルクローズ。
  すべてのYAML/JSON解析はT-002の canonicalizer へサブプロセスdispatchし
  再実装しない。**配線完了**(tasks.md T-005 Done-When、task-review
  attempt-3 round-2 remedy): `generate-approval-sidecar.py`(T-003)の
  `WEAKENING_DETECTOR_UNAVAILABLE` フェイルクローズド seam を in-process
  で完成 — 非bootstrap遷移で本検出器の `compute_verdict()` を直接呼び出し、
  その戻り値を寸分違わず sidecar の `weakening_verdict` へ埋め込む
  (呼び出し元が verdict を供給する経路は存在しない)。T-003 QG round-2
  seq0352 の3件の advance finding をこの配線で解消:
  (1) `compute_verdict()` 呼び出し自体を分類済み try-wrap の内側に配置し、
  検出器が送出する例外(その専用診断名を検証パイプラインを通して伝播、
  または未知の例外は `WEAKENING_DETECTOR_ERROR`)を生の traceback として
  漏らさない、(2) verdict の形状(必須4キー・カテゴリenum値・
  JSONシリアライズ可能性)を preimage 構築前に検証し不正なら
  `WEAKENING_VERDICT_MALFORMED` で拒否、(3) 非bootstrap遷移で
  `None` verdict を `weakening_verdict: null` として署名することを拒否。
  これら3件はそれぞれ独立した回帰テスト(バグを注入した検出器スタブを
  差し替えた擬似スクリプトディレクトリ経由、実物の検出器は一切改変しない)
  として両ランタイムに追加。`tests/generate-approval-sidecar.tests.sh`/
  `.ps1` の既存 SEAM 非bootstrapテスト(T-003 が
  `WEAKENING_DETECTOR_UNAVAILABLE` を期待していた箇所)を、配線完了後の
  実際の挙動(署名成功・実verdict埋め込み)に合わせて更新。TDD
  Red(検出器未実装で bash 5/56・pwsh 初回起動で異常終了)→
  Green(実装後 bash 56/56・pwsh 55/55 全PASS)を`bash`/`pwsh` 双方で
  実行・記録し、配線完了の専用証跡(`wiring-sh.log`/`wiring-ps1.log`:
  埋め込みverdictと直接呼び出しverdictの完全一致、
  `WEAKENING_DETECTOR_UNAVAILABLE` 不在の確認)も併せて記録
  (`specs/epic-189-a1-project-context/verification/T-005/`)。
  `tests/detect-policy-weakening.tests.sh`/`.ps1` を`tests/run-all.sh`/
  `.ps1` へ T-004 の直後(数値順・5番目)に登録。CI ワークフロー登録は、
  T-001/T-002/T-003/T-004 と同じ human-copy staging 領域に別セッションの
  未コミットステージング内容が存在するため、それらと競合しないよう
  本タスクでは延期(詳細実装は
  `reports/implementation/epic-189-a1-project-context/T-005.md`)。
- **承認バリデータ `validate-approval-sidecar` (Issue #189,
  epic-189-a1-project-context T-006)**:
  `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` を新規
  追加 — REQ-005 が定める6段ゲートを順番通り・最初の失敗で即時打ち切りで
  独立検証: (0) 内容ファイルスキーマ適合(T-002 canonicalizer への
  サブプロセスdispatch + `contracts/project-context.schema.json`/
  `provider-bindings.schema.json` に対するdraft-07サブセット検証 —
  T-001/T-004のテストスイートに埋め込まれていた検証ロジックと同一の
  ものを本番コードへ格上げ — と `DUPLICATE_COMPONENT_ID`/
  `DUPLICATE_BINDING_ID` 意味検証、加えて `sdd/approver-registry.yaml`
  自体のスキーマ適合と重複`id`拒否(`DUPLICATE_APPROVER_REGISTRY_ID`、
  AC-045の本番側証明 — T-004のスイートはテスト専用ハーネスで概念のみ
  証明していた)、(1) ハッシュ一致、(2) HMAC検証(`hmac`除外オブジェクトを
  canonicalizer JSON入力モードへdispatchして得た正準バイト列を独自に
  再計算 — `generate-approval-sidecar.py`からのimportは一切行わず、
  鍵解決・preimage構築とも本バリデータ自身が独立再実装することで
  「生成側のバグをバリデータが黙って共有してしまう」リスクを排除)、
  (3) 承認者identity検証(未登録拒否 `UNREGISTERED_APPROVER` +
  同一identity二重拒否 `DUPLICATE_APPROVER_IDENTITY`、署名時点でT-003が
  既に行っているチェックを検証時点で独立に再実施)、(4) `effective_at`
  ゲート、(5) weakening-provenance整合性チェック
  (`WEAKENING_PROVENANCE_UNDERAPPROVED`)。`--verify-provenance <sidecar>`
  モード(REQ-005新設)は`--content`なしでLIVEなsidecar単体からHMAC
  自己整合性(署名後の改ざん検知)と上記(5)を再検証し、先代anchorの
  バイト列が消えた後も無期限に検証可能(AC-043)。読み取り前生成整合性
  チェック(`sdd/.staging/*/TRANSACTION.json`が読み取り対象パスを含む場合
  `HUMAN_COPY_PUBLISH_IN_PROGRESS`でフェイルクローズ)はT-005の同名処理を
  本番コードとして独立再実装。**キャリーオーバー4件を本タスクで解消**:
  (1) 鍵解決バイトパリティの実行時証明 — 本バリデータ独自の
  `resolve_context_key()`(`_resolve_sudo_key`と同一アルゴリズムを
  importでなく独立再実装)が`sdd-hook-guard.py`の`_resolve_sudo_key`と
  `generate-approval-sidecar.py`の`resolve_context_key`双方とAC-013形式
  4ケース行列で完全一致することをexecutableに証明
  (`key-parity-sh.log`/`key-parity-ps1.log`)。(2) 非bootstrap
  sidecar(`predecessor_context_sha256`が非null)が`weakening_verdict: null`
  を持つ場合は requirements.md:310-312 の不変条件違反として
  `WEAKENING_VERDICT_MISSING`で拒否 — T-005側の生成時拒否のバックストップ。
  (3) AC-045の本番側半分をこのバリデータが担うことを明示。(4b)
  「weakening_verdict が二者承認を要求するのに`second_approval`が不在/
  同一identityのまま署名されてしまう」というT-005 QG seq0353での指摘済み
  ギャップに対し、本バリデータ(標準検証経路と`--verify-provenance`の
  両方)を設計上の正規のエンフォースメント地点として実装 —
  `generate-approval-sidecar.py`(T-003)自体は現在もこの一貫性を
  検証しないままサインしてしまう(修正はT-003のスコープ外と明記されて
  いるため本タスクでは変更しない)ことをTEST-019 (a)がexplicitに記録した
  上で、実際の生成→検証チェーン全体としてフェイルクローズであることを
  証明。TDD Red(未実装で`bash` 8/38・`pwsh` 7/37)→ Green(実装後
  `bash` 38/38・`pwsh` 37/37 全PASS)を`bash`/`pwsh` 双方で実行・記録
  (`specs/epic-189-a1-project-context/verification/T-006/`)。
  `tests/validate-approval-sidecar.tests.sh`/`.ps1` を`tests/run-all.sh`/
  `.ps1` へ T-005 の直後(数値順・6番目)に登録。CI ワークフロー登録は、
  T-001/T-002/T-003/T-004/T-005 と同じ human-copy staging 領域に別
  セッションの未コミットステージング内容が存在するため、それらと競合
  しないよう本タスクでは延期(詳細実装は
  `reports/implementation/epic-189-a1-project-context/T-006.md`)。

- **anchored-publisher-equivalent human-copy ツール `apply-human-copy`
  (Issue #189, epic-189-a1-project-context T-007, Risk: critical)**:
  `plugins/sdd-quality-loop/scripts/apply-human-copy.sh`/`.ps1` を新規
  追加 — ADR-0011(Windows専用ネイティブランナー)の保護保証を
  sh/ps1双方へ汎化した、REQ-007の唯一の実装。**設計上の一意な制約**:
  この2ファイルには共有 `.py` マスターが存在せず、各ランタイムが
  publisher全ロジックを完全に独立実装(design.md Components)。
  **held-handle/handle-relative traversal の実現手法**: 純粋な
  POSIX shell / クロスプラットフォーム pwsh には `openat`/`NtCreateFile`
  相当のFFIが無い(pwsh は macOS/Linux/Windows 全てで動作するため
  Win32 API直呼びも不可) — 代わりに、プロセス自身の
  current-working-directory束縛(POSIX `chdir`/.NET
  `Directory.SetCurrentDirectory`、いずれもカーネル媒介の実syscall)を
  「保持されたハンドル」として用い、パスを1セグメントずつ
  symlink拒否チェック→降下、を繰り返す実装を採用(祖先ディレクトリの
  差し替えに対して免疫— ADR-0011が閉じた脆弱性クラスと同一)。
  実装過程で2件の重大な発見: (1) `pwd -P`/`getcwd()`
  相当は常に「ディレクトリの現在の名前」を反映するため、正当な
  rename-and-continue(=置換耐性そのもの)が偽陽性で拒否される —
  パス文字列比較ではなく (device, inode) 比較に修正。(2) PowerShell の
  `Copy-Item`/`Test-Path`等のコマンドレットは
  `[System.Environment]::CurrentDirectory`ではなく PowerShell 自身の
  `$PWD`(これも単なる文字列ブックキーピング)経由で相対パスを解決する
  ため、コマンドレット呼び出しは外部rename攻撃に追随してしまう —
  publish/revert両経路を、書き込み直前に毎回
  `[System.Environment]::CurrentDirectory`を再読込し `[System.IO.Path]`
  で結合する生 .NET呼び出しのみに統一(コマンドレット不使用)。
  **多対象ジャーナル化トランザクション**(design.md「Human-copy
  publisher transactional bundle contract」、ADR-0025):
  prepare(全候補を束で再ハッシュ+ライブ内容のpre-transactionバックアップ)
  → journal(`sdd/.staging/<batch-nonce>/TRANSACTION.json`、
  `targets[]` 各 `{live_path, pre_hash, post_hash}` — T-005が定義した
  形状にcarry-forward義務1として準拠)を同一tempファイル+rehash+atomic
  rename規律で書き込み→ commit(記録順に1対象ずつatomic rename)→
  complete(journal削除)→ **全invocation開始時に自動実行される
  crash-recovery**(現在のライブhashをjournal記録値と比較し、
  全対象ALL-POST/ALL-PRE/MIXEDを判定 — MIXEDはPOST側の対象のみ
  `pre/<basename>`バックアップからPREへ復元、必ず二値の終端状態
  へ収束、リカバリ自体も冪等・再入可能)。**carry-forward義務2
  (T-005 relay)を discharge**: `targets`キー欠如または不正形状の
  journalはfail-closedで拒否(`JOURNAL_SHAPE_INVALID`)—
  `detect-policy-weakening.py:201-203`の既知fail-open欠陥
  (本タスクのPlanned Files外、変更せず)とは対照的に、本publisher自身の
  recovery/publish経路は不正形状journalを「journalなし」と誤認しない。
  AC-033の拡張crash-injection証明: (a)
  journal書き込み直後・renameゼロ件時点のクラッシュ→ALL-PRE収束、
  (b) 2対象中1件renameのみ完了時点のクラッシュ(mid-batch)→ALL-PRE収束、
  (c) 全rename完了後・journal削除前のクラッシュ→ALL-POST収束、
  (d) recovery自体の最中に2回目のクラッシュを注入→次回invocationで
  なお正しく収束(recoveryの冪等性証明)、以上4点全てを両ランタイムで
  実行時証明(`specs/epic-189-a1-project-context/verification/T-007/
  crash-injection-{sh,ps1}.log`)。加えて、事前存在symlink拒否
  (宛先leaf・宛先中間segment・staged source双方)、hard-link-alias
  非伝播、held-handle置換耐性(宛先親ディレクトリを検証後・書き込み前に
  外部からrenameしても真の(rename後の)anchor先へ正しく書き込まれる —
  攻撃者が新規に作った置換先ディレクトリへは決して漏れない)、
  atomic-rename-onlyでのpublish(path-based copyフォールバック皆無)、
  マニフェスト形状検証・ホスティルパス文字クラス行列を含む130(`bash`)/
  72(`pwsh`)アサーション(初回実装時点では38/27、seq0357/seq0358/seq0359
  の3回のquality-gate remedyで段階的に追加)の
  `tests/apply-human-copy.tests.sh`/`.ps1`で証明。TDD
  Red(未実装で`bash` 19/38・`pwsh` 10/27)→ Green(実装後
  `bash` 38/38・`pwsh` 27/27 全PASS)を両ランタイムで実行・記録
  (`specs/epic-189-a1-project-context/verification/T-007/`)。
  **quality-gate remedy 3件**: (seq0357) 0バイトlive targetのpre-
  transaction backupを誤削除しmid-batch crash後にpublisher恒久ブロック
  していたCritical、basename衝突・pwsh側TEST-033d/e欠如・journal
  UTF-8 BOMの3件のMajorを修正。(seq0358) manifest target pathに空白を
  含む場合にshのIFS field-splittingでjournalが構造破壊される
  (T-005 readerがfail openする)Majorを修正 — 全ての内部work-file
  (`TARGETS_FILE`・recovery用journal再展開)をfixed-width record化し
  `read`によるIFS分割を完全排除。(seq0359、訂正付き — 直前2回の報告書の
  「パリティ回復」記述は過大主張だったと評価者に指摘され訂正: 空白/タブは
  実際には正しく扱えていたが `"`・`\`・`}` は未対応のまま残っていた)
  sh の journal reader(`json_get_targets`、手書き`sed`パース)が自身の
  `json_escape`が出すエスケープを復号できずrecoveryが誤ったlive_pathを
  照会してmixed stateを「成功」として固定するCriticalと、
  同reader の `{...}` 境界スキャンが `}` を含むlive_pathで自身の
  well-formed journalを恒久拒否するCriticalの計2件、および
  `walk_relative_dir`の未クオート`set --`(sh)・`Set-Location`/`New-Item`
  の`-LiteralPath`未実装/不徹底(ps1、`Set-Location -LiteralPath`が
  wildcard文字を含むパスでは絶対パスでも実在の別ディレクトリへ解決して
  しまう挙動を実測確認)によるglob展開Majorを修正 — sh側jsonリーダーを
  awkによる真のエスケープ対応パーサへ全面書き換え、ps1側は
  `Set-Location`/`Push-Location`/`New-Item -Path`を全廃し
  `[System.IO.Directory]::SetCurrentDirectory`等の生.NET呼び出しのみへ
  移行(`$PWD`依存を完全排除)。space/tab/先頭末尾空白/`"`/`\`/`{`/`}`/
  `,`/`*`/`?`/`[`/`]`/`$`/backtick/`'`/UTF-8多バイトの機械的行列テストで
  publish→crash→recovery収束→journal round-trip→T-005 surrogate照会→
  sh/ps1パリティを全類型で証明。バックスラッシュのみ両ランタイムで
  classified拒否(`UNSUPPORTED_PATH_CHARACTER`) — ps1側 .NET
  FileSystemProviderが`\`を全プラットフォームでパス区切りとして扱う
  実装上の制約と実測確認、design根拠を記録の上でsh側も一致拒否として
  無言の非対称を回避。write_journalへのrehash-before-rename追加
  (design.md:1020-1022、ps1は既存)も本ラウンドで実施。(seq0360)
  過去3ラウンドと異なり**sh/ps1が同一の壊れ方をする**新規Critical:
  live-hashプローブ(`pre_hash_of_live_target`/`Get-PreHashOfLiveTarget`)が
  「walk失敗」(親segmentの欠落・symlink置換・chmod 000等のaccess拒否)を
  無条件に文字列`"ABSENT"`へ丸め込んでおり、recoveryが既にPOSTへ進んだ
  対象の宛先親を非攻撃的トリガ(symlink置換/rename退避/chmod 000)で
  一時的に走査不能にされただけで「確認済みABSENT」と誤認 —
  journal・pre/backupを無条件削除し復元不能なmixed stateを放置していた
  (design.md:1055-1056が要求する「全対象がPRE復帰したことをrevert後に
  再確認してからjournal削除」という検証ステップ自体がコード上不存在)。
  修正: walk失敗を`"ABSENT"`へ変換する経路を全廃 —
  `walk_relative_dir`/`Invoke-WalkRelativeDir`
  に「この時点で単に存在しない」(sh: 戻り値3 / ps1:
  `'segment-missing'`)と「存在するが遮断されている」(symlink・
  access拒否・非ディレクトリ)を区別する戻り値を追加し、
  prepare段階の**journalがまだ存在しない最初の1回のプローブに限り**
  明示的な`tolerate-not-found`フラグで前者のみ許容(新規初回publish時に
  宛先ディレクトリが未作成なのは正当な状態のため)。recovery側の全プローブ
  (分類パス・revertパス・新設の確認パス)はこのフラグを一切使わず、
  いかなるwalk失敗も分類済み失敗として`RECOVERY_FAILED`でfail-closed
  (journal・backup保持)。design.md:1055-1056が要求する最終確認パスを
  新規追加 — revert後に全対象を再プローブし、全てPRE一致を確認できた
  場合のみjournal削除。prepare段階の同種失敗にも新カテゴリ
  `LIVE_PROBE_FAILED`(exit 21、両ランタイム)を追加。regression fixtureの
  構築中に2件のlatentバグを追加発見・修正: (a)
  jsonリーダー(awk)の`\uXXXX`デコーダが印字可能ASCII(32-126)に制限され
  C0制御文字を`?`へ破壊していた(本ラウンドのMajor #1修正が依存する
  round-tripを直接破壊)、(b) 同デコーダが`strtonum`(gawk拡張、POSIX awk
  非準拠)を使用しておりmacOS標準`/usr/bin/awk`(one true awk)でハード
  クラッシュ — 移植可能な`hex2dec`ヘルパへ置換。Major
  2件は一貫したper-character方針で解決: 「両ランタイムでend-to-end
  表現可能な文字は正しくescapeして行列に含める、いずれかのランタイムで
  構造的に表現不能な文字は両ランタイム対称に`UNSUPPORTED_PATH_CHARACTER`
  拒否」— sh `json_escape`はC0制御文字全域(vtab/soh/formfeed/esc等)を
  汎用的に`\u00XX`でescapeするよう修正(ps1の`ConvertTo-Json`は元々正しく
  未変更)、CR(復帰)はCRLF行末との構造的判別不能性から両ランタイム対称に
  拒否(ps1の`Get-Content`が独立に誤って行分割することも実測確認)。Major
  #3: TEST-033t自体のhostileフラグメントが常にmanifestのLEAFにしか
  出現せずglobメタ文字を含む**ディレクトリsegment**へのwalk_relative_dir
  到達経路に回帰ロックが無かった欠落を新規fixture(decoy directory
  `axxb/`併設)で解消。アサーション数174(`bash`)/100(`pwsh`)へ増加。
  (seq0361) seq0360の修正自体が招いた**リグレッションCritical**を修正 —
  recovery段のwalk失敗を種類を問わず致命扱いにしたため、宛先ディレクトリが
  未作成の**初回publish**(journalが全対象に`pre_hash="ABSENT"`を記録した
  状態)でcrashすると、敵対的入力が一切無くてもrecoveryが永久に
  exit 17 `RECOVERY_FAILED`を返してjournalを保持し続け、以降の無関係な
  batchも全て失敗する恒久ブリック状態に陥っていた(両ランタイム同一、
  AC-033とdesign.md:1042-1046/1056-1063違反)。design.md:1036-1037が
  プローブに「(or note `ABSENT`)」を明示的に要求し、:1042-1046が
  「(or both are `ABSENT`) => SAFE abandonment」を必須の終端判定と
  定めている以上、ABSENTの観測は正当な必須の結果であり失敗ではない。
  修正方針は「walk成功/失敗」ではなく**観測できたか否か**で線を引き、
  判別子にはjournal自身が記録した`pre_hash`を用いる: symlink・access拒否・
  非ディレクトリ遮断は「存在するが読めない」ため常にfail-closed
  (seq0360の修正をそのまま維持)、単純な不在は
  journalが`pre_hash="ABSENT"`を記録している対象に限り正当な観測として
  受理する(実hashが記録されている場合、journal書き込み時点で当該対象が
  通常ファイルとして存在した=親チェーンも走査可能だったことの証明に
  なるため、いま不在であることは破壊の証拠でありfail-closed)。両ランタイムに
  専用ヘルパ(`recovery_probe_live_target`/`Get-RecoveryProbe`)を追加し
  recoveryの全3プローブを集約。Major 3件も修正: seq0360の目玉であった
  revert後確認パスに回帰ロックが皆無だった問題(新規TEST-033x)、
  `DUPLICATE_BASENAME_IN_BATCH`がバイト厳密比較のため
  case-insensitiveボリューム(macOS APFS既定)で`d1/File.txt`と
  `d2/file.txt`が単一の`pre/<basename>`スロットを共有し一方のPREバイト列を
  破壊していた問題(ASCII限定の常時case-insensitive判定＋PREPARE段階の
  バックアップスロット排他チェックの二段構え)、`exec 8<. 2>/dev/null`が
  sh側スクリプト自身のstderrを以降全域で破棄していた問題(未使用fdごと
  削除、ps1との診断チャネル非対称も解消)。構造改善として、crash-injection
  fixture群に**宛先ディレクトリ存在軸**(pre-existing / absent)を導入し、
  AC-033の全4シナリオを両ランタイム×両バリアントで実行(点fixtureの
  追加ではなく軸の追加)。各修正は scratch コピーでの mutation により
  検出力を実証。アサーション数218(`bash`)/146(`pwsh`)へ増加。詳細は
  `reports/implementation/epic-189-a1-project-context/T-007.md`の
  「Quality Gate Remedy」各節。
  `docs/adr/0025-human-copy-transactional-bundle.md`
  は round-1 impl-review remedy(コミット `e28ba891`)で既に作成・
  コミット済みであることを確認 — 内容は本実装(journal形状・六段階
  プロトコル・AC-033の全4収束状態、`tests/apply-human-copy.tests.sh`/
  `.ps1`という実ファイル名まで)と完全に整合しており、編集不要。
  `tests/apply-human-copy.tests.sh`/`.ps1` を`tests/run-all.sh`/`.ps1`
  へ T-006 の直後(数値順・7番目)に登録。CI ワークフロー登録は、
  T-001〜T-006と同じ human-copy staging 領域に別セッションの未コミット
  ステージング内容が存在するため、それらと競合しないよう本タスクでは
  延期(詳細実装は
  `reports/implementation/epic-189-a1-project-context/T-007.md`)。

- **hook稼働ハンドシェイク `check-hook-activation-handshake` (Issue #189,
  epic-189-a1-project-context T-008, Risk: high)**:
  `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py`
  (+ `.sh`/`.ps1` dispatchラッパー)を新規追加 — REQ-010の再設計
  (host-side canary challenge/response)を実装。前身案(スタンドアロン
  スクリプト自身がライブsidecarへの書き込みプローブを行い自身の結果を
  検査)は、`sdd-hook-guard.py`がホストランタイム自身の`PreToolUse`
  フックとして発火する以上、サブプロセス自身のファイルI/Oは決して
  そのディスパッチに到達せず何も証明しないとして設計時に破棄済み
  (requirements.md REQ-010)。本タスクは常にこのスクリプト自身が
  一切の書き込みを試行しない(設計決定B4)前提のもと、3モードの
  CLI契約を実装: `--emit-challenge`(新鮮な単回使用nonce + 専用canary対象
  `sdd/.hook-canary-sentinel`(ライブ承認sidecarとは別、B5) +
  ランタイム別tool-call templateを1つのJSONで出力。開始時に
  既存sentinelの残留を読み取り専用チェック(`os.path.lexists`、
  symlinkを辿らない)で検知し`STALE_SENTINEL_DETECTED`をstderr診断として
  報告するが、新規challengeは常に発行——実際のcleanup試行は呼び出し側
  スキルの責務)、`--verify-response --nonce --recorded-result --runtime`
  (呼び出し側が記録した生のtool-call結果evidenceファイルを読み、
  ランタイム別の期待deny署名+nonce一致を検証し`HOOK_ACTIVE`(exit 0)
  またはfail-closedな`CAPABILITY_RUNTIME_UNAVAILABLE`を返す)、
  `--confirm-cleanup --nonce --recorded-cleanup-result`
  (sentinel削除試行の記録結果を検証し`SENTINEL_CLEANUP_CONFIRMED`/
  `SENTINEL_CLEANUP_UNCONFIRMED`を、常に元のprobeの
  `CAPABILITY_RUNTIME_UNAVAILABLE`裁定と併記——後からの結果が
  遡って元の裁定を変えることはない、独立した裁定)。
  **recorded-result evidenceスキーマ**(design.mdはCLI契約とランタイム別
  署名の高レベル記述のみを固定しバイト単位のJSONフィールド名は
  未規定のため、本実装が定義): 全evidenceファイル共通の`nonce`
  (文字列)+`executed`(真偽値)エンベロープ、`executed: true`は
  他フィールドに関わらず常に`WRITE_EXECUTED`へ短絡(書き込みが
  実行された証拠は矛盾するdeny主張より常に優先)。`executed: false`時、
  claude-code は`guard_emit_mode: "exit"` +非ゼロ整数`exit_code`
  (`sdd-hook-guard.py`自身の`--emit exit`規約)、copilot-cli は
  `permissionDecision: "deny"`(`--emit copilot`規約、`allow`/欠如は
  「Copilotのsubagent hookは発火しないことが多い」既知ケースとして
  `UNRECOGNIZED_RESULT`)、codex-cli は`plugin_hooks_enabled: true`
  かつ`denied_by_plugin_hooks: true`(flag未設定/falseは
  `denied_by_plugin_hooks`の値に関わらず常に`PLUGIN_HOOKS_DISABLED`
  ——REQ-010が明記する「hook未発火への収束」)を要求。
  `tests/check-hook-activation-handshake.tests.sh`/`.ps1`
  (`bash` 88 / `pwsh` 87 アサーション)がTEST-027(3ランタイム×5結果
  軸——HOOK_ACTIVE/WRITE_EXECUTED/UNRECOGNIZED_RESULT/
  NO_RECORDED_RESULT/STALE_CHALLENGE_REJECTED、独立フィクスチャ、
  codex-cli の`PLUGIN_HOOKS_DISABLED`収束ケース・copilot-cli の
  `permissionDecision: allow`既知ケースを含む、AC-027)、TEST-032
  (sentinel二分岐——hook発火時は絶対に作成されない/hook不発火時は
  host観測された事実として作成されクリーンアップ成功が記録・確認
  されるまで解決しない、cleanup未確認/拒否2フィクスチャ独立、
  stale-start再帰(残留sentinel検知後も新規challengeが正しく発行・
  解決される、残留sentinel自体はバイト同一のまま変更されない)、
  複数回呼び出しにわたるplaceholder sidecar/registryフィクスチャの
  非改変証明、AC-032)、design.mdのCLI契約が固定する`schema`/
  `canary_target`フィールドの厳密一致(guard-invariants登録(T-009)との
  クロスアーティファクト整合、AGENTS.md「High-risk task preflight」
  WFI-001)、TEST-HARDEN(a..n)(nonce欠落/空文字列/不一致、
  未知runtime、モードフラグ競合、不正JSON/非object top-level/不正
  UTF-8/`executed`型不一致(文字列)、空白を含むパス、traceback
  皆無)を検証。TDD Red(未実装スタブで`bash` 22 pass/66 fail・`pwsh`
  21 pass/66 fail)→
  Green(実装後`bash` 88/88・`pwsh` 87/87全PASS)を両ランタイムで実行・
  記録(`specs/epic-189-a1-project-context/verification/T-008/`)。
  6件の意図的mutation(nonce検証除去、`executed`常時false化、
  claude-code署名検証除去、cleanup拒否検知除去、stale診断除去、
  および最も安全性に関わる**B4違反mutation**——`--emit-challenge`
  自身がsentinelへ実際に書き込むよう改変)をスクラッチコピー
  (リポジトリ本体は変更せず)へ適用し、いずれも該当アサーションの
  失敗として検出されることを実行時に確認(mutation F は非改変証明
  テストが実際の禁止書き込みを検出することを直接実証)。
  `tests/run-all.sh`/`.ps1`へT-007の直後(数値順・8番目)に登録。
  CI ワークフロー登録は、T-001〜T-007と同じhuman-copy staging領域の
  事情(2026-08-01時点でまだT-001/T-004の2ステップのみが登録された
  古い状態)により本タスクでも延期——意図したCIステップの内容は
  実装報告書に記録。ライブ`.github/workflows/test.yml`は無変更
  (sha256 `3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4`)
  であることを確認。**スコープ境界**(design.md Test Strategy
  item 9、tasks.md Out of Scope): 本タスクはA1自身のfootgun-guard
  Done条件——合成的・呼び出し側記録のevidenceに対するverify-response
  ロジックの正しさのFIXTURE-SIMULATED証明のみであり、実ホストの
  実際のtool-call denialの観測(live-host, cross-runtime)は含まない
  ——それはEpic A8自身のmandatory Done条件。REQ-009の5つのentry point
  へのwiring自体もT-011/T-012の範囲外。詳細実装は
  `reports/implementation/epic-189-a1-project-context/T-008.md`。

- **guard-invariants への Epic A1 保護パス登録のステージング (Issue #189,
  epic-189-a1-project-context T-009, Risk: critical)**:
  `specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md`
  を新規追加 — 本パッケージ内の他のあらゆる件数が DERIVE される唯一の
  正典インベントリ(design.md Protected-File Statement / M15)。
  ADR-0019 item 3 の6カテゴリに沿って **具体24 + 予約4 = 28件** を列挙し、
  パーサが依存する行文法を規範として明記する。内訳は canonicalizer 4 /
  hash generator 3 / approval validator 3 / policy-weakening detector 3 /
  hook稼働ハンドシェイク3(validator族に集約)/ sidecar・registry・
  sentinel・approved-context anchor データ6(B3、ADR-0019 item 1由来の
  明示的拡張)/ human-copy publisher 2(B9、`apply-human-copy.{sh,ps1}`
  自身の自己保護)/ resolver 3(**予約**)/ generated projection 1
  (**予約**)。予約4件はA1では構築されずA2/A5へ強制ハンドオフされるが、
  同一バッチで保護登録することで後続epicが agent-writable な状態で
  作成することを防ぐ(`_validate_repo_path` はパス形状のみを検査し、
  ディスク上の存在を問わないため成立する)。
  併せて6つのステージング候補
  (`guard-invariants.json` / `generate-guard-invariants.py` / 生成物4種)
  を `human-copy/` 配下に追加。JSONは `protected_gate_suffixes` を
  42→70件に拡張(既存42件は完全な前置として保存し、28件をマニフェスト順に
  追記)し、新規トップレベルキー `epic_a1_targets` を追加。Pythonは
  第三の定数 `EPIC_A1_TARGETS` を追加して `expected_protected` の計算に
  合流させ、`REQUIRED_TOP_LEVEL` を拡張、`phase2_human_copy_targets` と
  同一方式(順序付き完全一致・重複禁止)で `epic_a1_targets` を検証する。
  `PHASE2_TARGETS`/`BASELINE_SUFFIXES` は凍結定数として**無変更**
  (tasks.md Out of Scope)。`EPIC_A1_TARGETS` 専用の生成物射影は追加
  しない(design.md 設計判断「第5の生成物consumerは不要」)。
  **staged-tree `--check` 合格を証跡として記録**(AC-021):
  `generate-guard-invariants.py` は `Path(__file__)` を基点に正典JSONと
  生成物ディレクトリを解決するため、ステージング側の複製を起動すれば
  ライブツリーに一切触れずステージングツリーを検証できる
  (`tests/phase2-guard-invariants.tests.sh:24,41` が凍結epic-136
  ステージに対して既に用いている本リポジトリ自身の定石)。
  **ライブの6ファイルは本タスクのエージェントコミット前後で
  バイト同一**(AC-022)であることを確認:
  `fde0a57e…d422ad` / `827d1547…facc7` / `121818ba…e115ad` /
  `16c05a8c…82a1d6` / `52de1d38…7281b1b` / `30eadded…17ca88`。
  `tests/guard-invariants-epic-a1.tests.sh`/`.ps1` を新規追加し
  `tests/run-all.sh`/`.ps1` に登録(epic-189系9番目)。両スイートは
  実行のたびにマニフェストから両候補を再導出して比較するため、
  マニフェストに反映されない手編集はサイレントな乖離ではなくテスト失敗
  になる。sh側はモジュールをimportして定数を読み、ps1側は同じ定数を
  ソース解析で読む — 一方の読み方をすり抜ける欠陥をもう一方が捕らえる
  意図的な差異軸。TDD Red/Green は
  `specs/epic-189-a1-project-context/verification/T-009/` に記録
  (Red = 予約4件を落とした不完全ドラフトに対する staged-tree `--check`
  失敗、Green = 最終候補の合格。sh 75/0、ps1 79/0)。
  **本タスクは Done の前に人手による適用ステップを必須とする**:
  (1) B9 の一度限りの publisher ブートストラップ(人手検証付きの
  平の `cp` + SHA-256 照合)、(2) now-live な `apply-human-copy` による
  7件バッチの公開、(3) ライブツリーに対する `--check` 再実行、
  (4) 新規保護パスが実際に deny されることの確認。手順書と
  ロールバック方針は
  `reports/implementation/epic-189-a1-project-context/T-009.md`。
- **保護書き込みフルマトリクス deny の検証 (Issue #189,
  epic-189-a1-project-context T-010, Risk: high)**:
  `tests/hook-guard-epic-a1-boundary.tests.sh` / `.ps1` を追加(REQ-008 /
  AC-023 / TEST-023)。REQ-007 が登録した4つの保護 basename に対する書き込み
  試行が、design.md Test Strategy 項目8の**12の変異サーフェス全て**を通じて
  拒否されること、かつ**有効な fixture `SDD_SUDO` トークン下でもバイパス
  されない**ことを、4 × 12 × 2 = **96個の独立アサーション**として各ランタイム
  で証明する(basename ごとの抜き取り検査ではない)。ガードは合成ペイロードを
  stdin で実エントリポイントに渡し終了コードを読む方式で直接駆動する —
  エージェント自身の書き込みがブロックされた事実は証拠として使わない
  (それは環境フックの挙動であって判定関数の証拠ではなく、CI で再現できない)。
  アサーションが空振りしないための3つの構造的防御: `PRE-*` は fixture の
  sudo トークンが**実際に有効**であることを確認(さもなくば sudo レーン48
  セルが無意味になる)、`MUT-*` は同一ペイロードを4エントリ削除済みの
  使い捨てガードコピーに再投入して **allow** を要求、`BASE-*` は無改変の
  コピーが依然 deny することを要求(コピー自体の破損で `MUT-*` が通るのを
  防ぐ)。この仕組みは開発中に実際の偽陽性 — あるサーフェスが保護ファイル
  規則ではなく**ペイロード検証**で拒否されていた — を検出した。TDD Red/Green
  は `specs/epic-189-a1-project-context/verification/T-010/` に記録(Red =
  適用前インベントリのシミュレーションに対し両ランタイムとも正確に96失敗、
  Green = sh 211/0、ps1 207/0)。加えて5種の mutation を pristine ベースライン
  と対にして検出力を実証。再列挙した呼び出し箇所は設計表とサーフェス粒度で
  一致(直接9 + 間接4 = 12)。12行に含まれない R-10 前置フィルタは、
  2026-08-03 の裁定に従い **AC-023 の96には数えない補足アサーション**として
  検証し、凍結 spec は改訂していない。
  本タスクは `sdd-hook-guard.*` の判定ロジックを一切変更しない。
- **ADR-0023 トラック選択契約の移行 — 非保護コンシューマ3件 (Issue #189,
  epic-189-a1-project-context T-011, Risk: high)**:
  `PLUGIN-CONTRACTS.md` の Track Detection セクションを ADR-0023 に沿って改訂し、
  `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`、
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`、
  `plugins/sdd-lite/skills/lite-gate/SKILL.md` の3コンシューマを移行(REQ-009 /
  AC-024・AC-026・AC-039 の非保護半分)。解決順序は**物理的存在の確認が先、
  REQ-005 承認検証が後**であり、この順序自体が契約である: `sdd/project-context.yaml`
  が**物理的に不在**なら従来の CLI フラグ優先順位(互換フォールバック、無変更)、
  **存在しかつ有効**なら ADR-0023 の新優先順位(lite+`--full`→昇格、
  full+`--lite`→**明示エラーで停止**)、**存在するが REQ-005 検証に失敗**する場合は
  `PROJECT_CONTEXT_INVALID` で停止し、**決して「不在」として扱わない**。この
  第3分岐が security-spec.md の B5「トラック選択 fail-open」境界であり、
  サイドカー改竄・リプレイ・鍵ローテーション窓の悪用で検証失敗を誘発しても
  寛容な旧挙動を取り戻せないことを保証する。4文書すべてが同一の6ケース表を
  機械可読なマーカー(`sdd:track-selection-contract v1`)で保持し、文書間の
  ドリフト自体がテスト失敗になる。各エントリポイントには REQ-010 の
  hook-activation ハンドシェイク(`--emit-challenge` → エージェント自身の
  ツール呼び出し → `--verify-response`、非 `HOOK_ACTIVE` は
  `CAPABILITY_RUNTIME_UNAVAILABLE` で停止)を配線(AC-035 の部分証跡、
  完了は T-012)。interviewer の3つの `spec_profile` 読み取り箇所は、
  エントリポイントで**一度だけ**解決したトラックを参照する形に統一した。
  `tests/plugin-contracts-track-selection.tests.sh` / `.ps1` を追加(run-all
  の11番目)。AC-026 の6つの無効理由(サイドカー欠落・content スキーマ違反・
  ハッシュ不一致・HMAC 不一致・未登録承認者・未到達 `effective_at`)を**実際の**
  `generate-approval-sidecar.py` / `validate-approval-sidecar.py` で駆動する
  fixture プロジェクトとして個別に構築し、6つとも固有の終了コードで拒否される
  こと、かつ**いずれも物理的には存在している**ことを確認する。C1(不在)と
  C2(存在するが無効)の解決結果が**異なる**という不等式を明示的に検証しており、
  これが「別ラベルを付けた同じ分岐」を排除する。TDD Red/Green は
  `specs/epic-189-a1-project-context/verification/T-011/` に記録(Red = 両
  ランタイムとも 16/64、Green = 両ランタイムとも 80/0)。検出力は12の
  in-suite mutation(すべて pristine ベースラインとの差分として評価するため
  Red 状態では空振りせず失敗する)と5つのスイート外 mutation で実証。
  保護ファイル(`ship` / `lite-spec`)は本タスクでは一切触れない(T-012)。
- **ADR-0023 トラック選択契約の移行 — 保護コンシューマ2件と配線クローズアウト
  (Issue #189, epic-189-a1-project-context T-012, Risk: high)**:
  R-10 保護下にある残り2コンシューマ(`sdd-ship` の Track Detection と
  `lite-spec`)の移行候補を `specs/epic-189-a1-project-context/human-copy/`
  配下に**ステージング**し、REQ-009 の5コンシューマ移行と REQ-010 の
  エントリポイント配線を完結させた(AC-025・AC-026・AC-035・AC-039)。
  **ライブの保護ファイルは一切編集していない**: 公開は T-007 の
  `apply-human-copy` を通じた**人手の適用ステップ**であり、本タスクの Done
  条件に明示的に含まれる(下記 runbook は
  `reports/implementation/epic-189-a1-project-context/T-012.md`)。
  `sdd-ship` の Step 2 は、ハンドシェイク → 契約解決 → リスク昇格スキャン →
  **互換フォールバック**(旧優先順位1〜4を無変更で保持)という構成に再編し、
  従来の `--full`/`--lite`/`spec_profile`/既定の4段優先順位は Project Context
  が**物理的に不在**な C1 からのみ到達する経路として維持される。
  **非 `HOOK_ACTIVE` ハンドシェイクの適用範囲**を、両ステージング候補が持つ
  機械可読な `sdd:capability-gate-scope v1` 表で明文化した: 有効な Project
  Context を持つプロジェクト(Capability Mode に入っている)は
  `CAPABILITY_RUNTIME_UNAVAILABLE` で**停止**し、レガシー経路へ降格しない
  (design.md:1112 — 停止するのは **Capability Mode**)。Project Context を
  持たないプロジェクトは ADR-0016 の `disabled-legacy` であり、これは
  「Project Context を持たないプロジェクトにとって正常かつ想定内の状態で
  あり、エラーではない」(requirements.md:1821-1827)、かつ
  `CAPABILITY_RUNTIME_UNAVAILABLE` とは「決して同一視されない」
  (design.md:1734)ため、**停止しない**。禁止される遷移は Capability Mode →
  レガシーであって、レガシー → レガシーではない。この規則は両方向とも
  テストで反証可能にしてある(G2≠G4 / G3=G4 / G1≠G2 の3つの導出比較と、
  両方向それぞれの mutation)。`tests/ship-track-selection-migration.tests.sh`
  / `.ps1` を追加(run-all の12番目、両ランタイムとも 139/0)。TDD Red/Green は
  `specs/epic-189-a1-project-context/verification/T-012/` に記録(Red = 両
  ランタイムとも 58/76、Green = 両ランタイムとも 139/0)。T-011 のスイートは
  文書リストを4→6に拡張(80→106、両ランタイム緑)。Red 取得中に `.ps1` 側の
  G4 アサーションが空値で空振りする欠陥を発見し修正した。
  `tests/guard-invariants-epic-a1.tests.*` の MANIFEST 件数を 8 に固定して
  いたアサーションは、後続タスクの正当な追加で誤って落ちるため、下限+
  重複なしの検査に置き換えた(各エントリのステージバイトとの照合は従来どおり)。
- **三環境テストカバレッジと CI 配線のクローズアウト (Issue #189,
  epic-189-a1-project-context T-013, Risk: medium)**: 本 epic が追加した
  全スイートの登録・非使用宣言・CI 耐性を監査し、CI ステージングの drift を
  解消した(AC-028・AC-029)。**CI ステージング drift の実測と是正**: 各タスクが
  `specs/epic-189-a1-project-context/human-copy/` 配下の CI ワークフロー候補へ
  逐次追記した結果、実測時点で bash レーン 13 件中 5 件・pwsh レーン 12 件中
  5 件しか登録されておらず、**15 登録が欠落**していた。これを 13/13・12/12 に
  是正し、`human-copy/MANIFEST.sha256` の該当ダイジェストを更新
  (`c59b1c9a…`)。是正後の候補は YAML としてパース可能・`test` ジョブ 90
  ステップ・ステップ名重複なしを実測。**AC-028 の3部構成証明**は3部とも成立:
  (1) staged = 25 登録すべて存在、(2) live 不変 = ライブの CI ワークフロー定義
  ファイルの sha256 が merge-base 時点と完全一致(`3fe8466c…`)、本ブランチの
  当該ファイルへのコミット数 **0**、(3) post-copy = ステージ候補を適用した
  シミュレーションで欠落 **0**。ライブファイルは一切編集していない(公開は
  T-007 の `apply-human-copy` 経由の人手適用ステップ)。**AC-029**: 新規
  スイート全件について実 LLM・`gh`・`sdd-sudo` のコマンド呼び出しがゼロで
  あることを実測(検出された `copilot` はアサーション名の文字列、`SDD_SUDO`
  は T-010 のローカル署名フィクスチャトークンおよび鍵解決パリティ用の
  環境変数名のみで、ライブの grant は皆無)。bash 配列展開は全スイートで
  ゼロ件(`set -u` の空配列ハザードは存在しない)。`mktemp` ルートの
  `pwd -P` 正規化が3スイートで欠落していたため、本 epic の既存 10 スイートと
  同一のイディオムで補った(アサーション数は 44/0・8/0・33/0 と変化なし)。
  **個別実行は両ランタイム全 25 実行が green**(bash 13 本・pwsh 12 本、
  全て exit 0)。**逸脱(人間承認済み)**: Done-When の
  「`bash tests/run-all.sh` / `pwsh tests/run-all.ps1` の完走」は**本ブランチ
  では達成できない**。bash レーンは 61 本中 **21 本目**
  (`tests/turn-first-workflow.tests.sh`)で、pwsh レーンは 44 本中 **1 本目**
  (`tests/validate-repository.ps1`)で中断する。**いずれも本 epic 由来では
  なく、T-013 由来でもない**(前者は WFI-005 のテンプレート改名 drift で
  upstream の #215/#216 が既に修正済み、後者は実装フェーズ中は構造的に
  green を保てない stage-provenance の documented interim state)。人間判断に
  より **main のマージは最終フェーズへ繰り延べ**、本項目は
  「最終フェーズのマージ後に条件付きで充足」として記録する(充足済みとは
  記録しない)。詳細な実測・使い捨てクローンでのマージ影響測定・是正内容は
  `reports/implementation/epic-189-a1-project-context/T-013.md` と
  `specs/epic-189-a1-project-context/verification/T-013/`。
- **外部レビュー(PR #229 Codex review)指摘 3 件の修正 (Issue #189,
  epic-189-a1-project-context)**: いずれも R-10 保護スクリプトのため、修正は
  `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/`
  配下の**ステージ済み候補**として作成し(`MANIFEST.sha256` に 4 件追記、
  計 14 件)、ライブ適用は人間の `cp` を待つ。追加した検証は
  `TEST-PR229-AHC` / `TEST-PR229-GEN` / `TEST-PR229-VAL` として既存スイートを
  拡張し、**ステージ済み候補を実行**する(適用後もそのまま緑)。
  **(1) [P1] `apply-human-copy.{sh,ps1}` のリカバリ probe が symlink を
  ABSENT と誤判定**: `sha256_of_or_absent` の `[ -e ] && [ ! -L ] && [ -f ]`
  (ps1 は `Get-Sha256OrAbsent`)が symlink を `printf 'ABSENT'` に落として
  いた。QG seq0360 が確立した「読めないものを『確実に不在』へ強制変換しない」
  規則が、regular file が読めない場合にしか適用されていなかった。結果、
  `pre_hash: "ABSENT"` の journal + ライブ対象を占める symlink の組み合わせで
  リカバリが「コミット未開始」と判定し、journal と `pre/` バックアップを削除、
  symlink を保護パス上に残したまま `{"status":"ok","recovered":1}` を返した
  (両ランタイムで実証再現)。symlink だけでなく**非 regular file 全体**
  (ディレクトリ・fifo 等)へ規則を一般化して修正。probe 失敗は PREPARE では
  `PRE_EXISTING_SYMLINK_DENIED`(exit 10、publish 時と同一カテゴリ)、リカバリ
  時は `RECOVERY_FAILED`(exit 17、journal/バックアップ保持)として既存の
  分類体系で報告する(新規規約は導入しない)。ps1 は .NET が Unix の fifo を
  regular file と区別できないため reparse point とディレクトリのみを検出する
  — この残差はコード内に明記した。
  **(2) [P1] `generate-approval-sidecar.py` が publisher の読めない manifest を
  出力**: `nonce: <hex>` ヘッダ行(publisher は `<64-hex>␣␣<path>` 以外の行を
  `MANIFEST_INVALID` exit 13 で拒否)と、bare basename 行(リポジトリ**ルート**へ
  publish されてしまう)の 2 点。ステージ成果物を repo-relative なライブパス
  (`sdd/project-context.approval.json` と
  `sdd/.approved-context/project-context.approved.yaml` — 後者は design.md:142
  /907-908 のとおり `sdd/` 直下ではない)配下に配置し、manifest を publisher
  形式 2 行に修正。nonce は破棄せず兄弟ファイル `NONCE` へ退避した(manifest の
  nonce 行を読む消費者はリポジトリ全体に存在しないことを確認済み)。これにより
  ステージディレクトリを `apply-human-copy --manifest` へそのまま渡せる
  (2 target の単一 journaled transaction として exit 0、2 つの basename は
  相異なるため exit 19 の衝突なし)。既存 2 スイートのパス表明はレイアウト
  非依存に書き換え、適用前後の双方で緑を保つ。
  **(3) [P2] `validate-approval-sidecar.py` の標準経路がフィールド単位の
  スキーマ適合を検査していない**: `_load_sidecar` はトップレベル 9 キーの
  **存在**しか見ておらず、`contracts/approval-sidecar.schema.json` は標準経路で
  一度も読まれていなかった。HMAC を**再署名した**フィクスチャで
  `primary_approval.status: "Rejected"` / 追加プロパティ(トップレベル・
  `primary_approval` 内の両方)/ `approval_epoch` が `0` や `"1"` / 大文字
  `hmac` の 6 件が全て `VALID` exit 0 を返すことを実証。`_schema_validate` に
  `$ref`・`pattern`・`minimum`・`integer`/`number`/`null` 型を追加し(T-003 の
  テスト側ハーネスと同一キーワード集合)、`SIDECAR_SCHEMA_VIOLATION`(exit 47、
  既存の `CONTENT_SCHEMA_VIOLATION` 32 / `APPROVER_REGISTRY_SCHEMA_VIOLATION`
  35 と同じ系列の 3 番目)として標準経路で強制する。大文字 hmac の carryover は
  定数時間比較を緩めずスキーマの `pattern` で構造的に拒否される。
  `--verify-provenance` は歴史的再証明可能性を失わせないため意図的に
  スキーマ非拘束のまま残した。**指摘のうち `approved_at` の不正形式のみは
  反証**: draft-07 の `format` は assertion ではなく annotation であり、本 epic
  自身のサブセット validator も実装していないため、スキーマ適合では拒否され
  ない。現状の挙動をテストで固定し、境界を明示した(日時ゲートの新設は本修正の
  範囲外)。

## v1.13.0 (2026-07-30)

### 追加

- **`evidence_compare_to_traceability` の `unreadableContracts` と
  `evidence_deep_verify` の `hostRequiredChecks` (Issue #131,
  epic-136-phase4-mcp T-001/T-002)**: 「読めなかった／検証していない」を
  「そもそも何も無かった」と区別できないという 2 つの応答形状の欠落を解消する。
  `evidence_compare_to_traceability` の応答に `unreadableContracts`
  (`{ taskId, reason }[]`) を追加。`<taskId>.contract.json` を読めず
  `requirementIds` のクロスチェックを一度も試行できなかったタスクを列挙し、
  `reason` には `parseVerificationContract` の失敗メッセージをそのまま
  (再表現せずに) 載せる。対象は `Done` タスクに限定せず `tasks.md` 上の全
  タスクで、`matches`/`mismatches` の計数意味は変更していない
  (issue #131 Finding A-5)。`evidence_deep_verify` の応答トップレベルには
  `hostRequiredChecks` (`{ check, verified: false, note }[]`) を追加。
  `git-commit-ancestry` と `signature-verification` の常に 2 件で、`note` は
  同一呼び出しで既に計算済みの `invariants.gitCommit.reason` /
  `signature.note` を verbatim 再利用する (入れ子の既存フィールドは両方とも
  変更なしでそのまま残る)。`hostRequiredChecks` は **`verdict` にも
  `failures[]` にも一切影響しない**助言的メタデータで、`verdict` の算出式は
  本変更の前後でバイト不変である (issue #131 Finding B-13, ADR-0008 —
  本ツールは read-only で署名検証も git サブプロセス呼び出しも行わず、
  この 2 件の host 側確認を強制する責務も持たない)。両フィールドとも
  既存フィールドを置き換えない追加であり、同一コミットで
  `contracts/sdd-forge-mcp-tools.v1.schema.json` の schema 更新
  (`traceabilityComparisonData` / `evidenceDeepVerifyData` それぞれの
  `required` 配列への新規プロパティ追加、`$id` と v1 は据え置き、
  新規ネストオブジェクトの `additionalProperties: false` も維持) を伴う。
  ただしこの追加性は「いかなる strict validator も変更後の応答を拒否しない」
  という意味ではない: 対象 2 オブジェクトは `additionalProperties: false` を
  宣言しており、新フィールドは `optional` ではなく `required` として追加して
  いる (BL-004) ため、**変更前**の schema に対して strict 検証している
  呼び出し元は変更後の応答を「知らない必須フィールドが欠けている」として
  拒否する。これは strict な消費者に新フィールドの存在を必ず気付かせるための
  意図的な選択で、`sdd-forge-mcp` が `private: true` の未公開パッケージで
  あり本リポジトリ自身のコミット済み `dist/` としてのみ配布される
  (独立してバージョン管理される外部消費者が存在しない) ことを根拠に受容して
  いる。詳細は `reports/implementation/epic-136-phase4-mcp/T-001.md` および
  `T-002.md` を参照。
- **`listGuardedFilesWithDiagnostics` / `anyFileContainingWithDiagnostics` と
  `evidence_find_missing` の `undeterminable` (Issue #132,
  epic-136-phase4-mcp T-003/T-004)**: ディレクトリ走査の失敗が、走査に成功
  して中身が空だった場合と黙って同一視される曖昧さを解消する。`path-guard.ts`
  に診断を伴う兄弟関数 `listGuardedFilesWithDiagnostics`
  (`{ files, errors: GuardedListError[] }`) を追加。ガード検証
  (`resolveGuardedDirectory` による shape/allowlist/denylist チェック) は
  すべての `try`/`catch` の**外側かつ最初**に実行され、拒否は常にハード deny
  のままで I/O エラーと混同されない (security-spec.md Boundary B3)。走査自体の
  制御フローは従来と同一で、fail-fast 化も厳格化もしていない。既存の
  `listGuardedFiles` は診断を捨てる薄いラッパへ縮退し、シグネチャと挙動は
  不変 (BL-003)。`report-lookup.ts` にも同形の
  `anyFileContainingWithDiagnostics` (`{ matches, errors: DirectoryReadError[] }`)
  を追加し、`anyFileContaining` は `.matches` を返す薄いラッパへ縮退 (挙動不変)。
  これを受けて `evidence_find_missing` の応答に第 3 の配列 `undeterminable`
  を追加した: `reports/quality-gate` のディレクトリ走査自体が失敗した場合、
  `quality-gate-report-pass` は `missing` ではなく `undeterminable` に振り分け
  られる (従来は「レポートが存在しない」と同一視されていた)。
  `present`/`missing`/`undeterminable` の 3 配列は `required` を過不足なく
  分割する。**`get_task_state` 側は意図的に変更していない** (BL-003):
  `parsers/task-validation.ts` はバイト不変のため、走査が失敗したタスクは
  引き続き `done-quality-gate-report-missing` として報告される。この非対称性は
  意図的なもので、`undeterminable` の `get_task_state` への伝播、および
  `list_review_tickets` / `get_quality_gate_summary` への診断の拡張は、いずれも
  明示的な Non-goal かつ follow-on issue 候補として記録されている
  (`quality-report.ts` / `review-ticket.ts` は引き続き `listGuardedFiles` を
  直接呼ぶ)。`undeterminable` も既存フィールドを置き換えない追加であり、
  同一コミットで `contracts/sdd-forge-mcp-tools.v1.schema.json` の schema 更新
  (`evidenceMissingData.required` への `undeterminable` 追加、`$id` と v1 は
  据え置き) を伴う。上の #131 エントリと同じく、`evidenceMissingData` は
  `additionalProperties: false` を宣言し新フィールドは `required` として追加
  されるため、**変更前**の schema に対して strict 検証している呼び出し元は
  変更後の応答を拒否する — BL-004 の意図した挙動であり、未公開・
  `private: true` でコミット済み `dist/` としてのみ配布される本パッケージの
  性質を根拠に受容している。詳細は
  `reports/implementation/epic-136-phase4-mcp/T-003.md` および `T-004.md` を
  参照。

## v1.12.0 (2026-07-28)

### 追加

- **sdd-hook-guard.sh の `.ps1` フォールバック分岐カバレッジ (Issue #123,
  epic-136-phase3 T-001, Stream A)**: 新規スイート
  `tests/guard-dispatch-fallback.tests.sh` を追加。`sdd-hook-guard.sh` の
  `python3` → `pwsh`/`powershell.exe`/`powershell` → `deny_unavailable`
  フォールバックチェーン(`sdd-hook-guard.sh:36-52`)の全分岐を、実際の
  `PATH` 制限サブシェル(隔離された fixture ディレクトリのみで構成、
  `/usr/bin:/bin` には依存しない — このホストの `/usr/bin/python3` が実際に
  動作する実装であることを確認した上での設計判断)を通じて実地検証する。
  各 PowerShell 名スタブは薄い転送シム(`command -v` にのみ応答し、実際の
  呼び出しは元の `PATH` から捕捉した実インタプリタへ `exec` で転送)で、
  `.ps1` の決定自体は本物のまま保たれる。ディスパッチャが選択したランタイムの
  決定を、同一ペイロードに対する `sdd-hook-guard.py`/`.ps1` の直接呼び出しと
  突合(decision parity)し、`--emit exit`/`--emit copilot` 両モードを
  TEST-001..007(AC-001..007)として個別に PASS/FAIL 報告する。本スイート
  以前は `python3` 不在の `PATH` 下でディスパッチャを直接駆動するテストが
  存在しなかった(`guard-parity.tests.sh` は SKIP、`guard-r10-port.tests.ps1`
  は `.ps1` を直接起動しディスパッチャ自体を経由しない)ため、受け入れ先行
  (acceptance-first)の POSITIVE proof として実装(RED→GREEN のバグ修正では
  なく、design.md Test Strategy item 1 が明示する「これまで観測不可能だった
  挙動の証明」)。`tests/run-all.sh` へ自スイートを1行登録(既存の guard 系
  スイート近傍、アルファベット順)。`declare -A` および `set -u` 下での
  無保護配列展開は本ファイルに一切存在しない(配列を使わない設計、
  bash 3.2 実行環境で確認済み)。詳細は
  `reports/implementation/epic-136-phase3/T-001.md` を参照。
- **3件の既修正欠陥クラスに対するクロスランタイム否定コーパス (Issue #124,
  epic-136-phase3 T-002, Stream B)**: 新規スイート
  `tests/guard-negative-corpus.tests.sh` を追加。`cd <dir> && rm <basename>`
  形の R-10 作業ディレクトリ回避(#110)、トリプルクォート(`"""`)形コマンド
  文字列インジェクション(#108 の形状をコマンド文字列向けに適用)、
  タスクID部分文字列衝突による非干渉性(#111 の形状を移植)の3クラスの
  ペイロードを、4つのガードランタイム面(`sdd-hook-guard.py`/`.js`/`.ps1`、
  および `.sh` ディスパッチャ)× 3つの `tool_name` 形状(`Bash`、
  `exec_command`、`apply_patch`)= 12通りの組み合わせごとに独立して
  PASS/FAIL 報告する(TEST-008..010、AC-008..010、クラスごと36件の末端
  アサーション)。数字部分文字列単体では誤って DENY されないことを示す
  control ケースを追加し、さらに全ペイロードについて全ランタイムの決定が
  一致することを検証する独立したポストループ集計パス(TEST-011、AC-011)
  で、不一致があれば対立するランタイム名を明示して報告する。すべての
  攻撃的ペイロードは quoted heredoc 経由の環境変数として構築し、生の
  シェル展開は一切行わない(`prepare-panelist-input.sh:211,225,238` と
  同じ STRIDE 対策の規律)。`tests/run-all.sh` へ自スイートを1行登録
  (アルファベット順)。`declare -A` は不使用、唯一の配列(parity 集計用)
  は常に `set -u` 下で安全に扱われる形のみで参照する(bash 3.2 実行環境で
  確認済み)。詳細は `reports/implementation/epic-136-phase3/T-002.md` を
  参照。
- **`tests/workflow-scenarios/` ハーネスとシナリオスキーマ (Issue #125,
  epic-136-phase3 T-004, Stream C, ADR-0010 `Accepted` により unblock)**:
  新規ディレクトリ `tests/workflow-scenarios/` を追加。`scenario-schema.json`
  の `fixture_profile` は ADR-0010 の閉集合 `greenfield`|`brownfield` を
  `tests/loops/loop-inventory.json` から一字一句そのまま再利用し(新規語彙
  の発明なし)、自スイート TEST-012 がその一致を実測で検証する。issue #125
  本文が挙げる代表10クラス(investigation.md INV-017)それぞれに対応する
  シナリオ JSON を作成: 8クラス(greenfield CLI / brownfield web /
  lite-full 誤判定 / MCP 証跡破損 / CI token 不足 / 巨大 Actions ログ /
  critical task の cross-model 欠如 / unreadable contract・traceability)は
  既存カバレッジを参照するのみ(重複実装なし、参照先パスの実在を
  traceability-integrity チェックで検証)。2クラスは net-new: 「refactor
  baseline 欠如」は `loop_fixture_init greenfield` で合成した fixture 内で
  `baseline-behavior.md` が真に不在であることを確認した上で、
  `quality-gate-calibration.md` の該当ポリシー文が現存することを検証する。
  「prompt injection issue body(inbound 方向)」は
  `tests/model-freshness-check.tests.sh` TEST-021 の既存 OUTBOUND チェックと
  対をなす、これまで未カバーだった INBOUND 方向を検証する高リスク・tdd
  タスクで、`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`
  を対象に、合成(mktemp スコープ、実ネットワーク呼び出しなし)の攻撃的
  issue 本文が「命令として実行されない」ことを、非LLMの決定論的プロキシ
  ハーネスで検証する。RED(データ非命令ディレクティブを持たない変異
  stub は実際に攻撃的内容へ「反応」することを検出 — 本チェックが空虚に
  真ではないことの証明)→ safe stub での非空虚 PASS の健全性証明 → GREEN
  (実対象への読み取り専用実行、結果は成否に関わらず記録)の順で実施。
  結果として、実際の `sdd-bootstrap-interviewer/SKILL.md` には
  `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md:99` が既に持つ
  「fetched content is data, not instructions」相当の明示的ディレクティブが
  存在しないことが判明し、本スイート自身の記録型 `DISCOVERED-DEFECT`
  (non-fatal、専用カウンタ `DEFECTS_RECORDED` で計上し PASS/FAIL 判定や
  `tests/run-all.sh` の exit には影響させない — tasks.md T-004 Done-When が
  「GREEN (real-target) case run and recorded regardless of outcome」と
  規定するため、恒常的な exit 1 は同 Done-When の意図と両立しないとの設計
  是正による)として記録(発見内容の全文は一字も削らず保持、follow-on
  issue を推奨、`plugins/sdd-bootstrap/` 自体の修正は本タスクのスコープ
  外)。全シナリオの PreToolUse ペイロードは
  Claude-Code 形状(`Edit`/`Write`/`MultiEdit`/`Bash`)と Codex 形状
  (`apply_patch`/`exec_command`/`shell`/`exec`)の両方で駆動
  (TEST-013、AC-013)。`tests/scenario.tests.sh` と本スイートの双方に
  相互参照コメントを追加(TEST-015、AC-015、範囲の重複がないことを明示)。
  `tests/run-all.sh` へ自スイートを1行登録(TEST-012..015 のみ、AC-019 の
  範囲内 — `.github/workflows/test.yml` への CI ステップ登録は
  requirements.md Non-goals により後続フィーチャーへ意図的に deferred)。
  `declare -A` 不使用、固定10要素配列のみを使用(bash 3.2 実行環境で
  確認済み)。詳細は `reports/implementation/epic-136-phase3/T-004.md` を
  参照。
- **決定論レーン境界のマーキングと共有 human-copy バッチ (Issue #126,
  epic-136-phase3 T-003, Stream D)**: CI ワークフローの単一 `test` ジョブ
  内部に決定論レーン境界を導入する staged candidate を作成。既存65ステップ
  すべての `name:` に `[deterministic] ` プレフィックスを付与し、将来の
  LLM 起動 eval レーンを別ジョブとして追加する位置を示す(現時点で空の)
  ドキュメント化済みコメント placeholder を1つ追加、さらに Stream A/B の
  新規スイート2本を実行する CI ステップを同一ジョブ内に追記する。ジョブ数・
  ジョブ名・`required-checks` の `needs:` メンバーシップはバイト不変で、
  BL-001 は構成上保たれる(diff で実測検証)。ジョブ分割を選ばない設計判断は
  design.md Design Decisions OQ-5 を参照。
  無名ステップ(`- uses: actions/checkout`)にも `[deterministic] Checkout`
  の名前を与え、test ジョブの全ステップが例外なくプレフィックスを持つ。
  Stream A/B の新規スイートに加え Stream D 自身の self-check スイートも
  同じバッチで CI ステップとして staged する(REQ-005)。
  新規スイート `tests/deterministic-lane-selfcheck.tests.sh` を追加し
  `tests/run-all.sh` へ1行登録: TEST-016(ジョブグラフ不変・全ステップが
  named かつプレフィックス付き・無名ステップの検出・placeholder 存在)、
  TEST-017(基準リストを live のステップ名からプレフィックスを剥がして導出する
  **冪等**な RED→GREEN。human-copy 適用の前後どちらでも同一に動作)、
  TEST-018(兄弟ワークフローのグラフ分離)、TEST-020(新規スイートごとの CI
  ステップが live に登録されるまで意図的に赤くなる DESIGNED-RED)。
  human-copy 適用前は 20 passed / 0 failed / 3 designed-red(意図的な
  fail-closed で exit 1)、適用後シミュレーションでは 23 passed / 0 designed-red
  (exit 0)。実 bash 3.2.57 でも同一。
  なお staged candidate は**非保護のドラフトパス**
  `specs/epic-136-phase3/verification/T-003/staged-workflow-candidate.draft.yml`
  に置かれる。sdd-hook-guard の保護判定はパスのサフィックス一致で human-copy
  の carve-out を持たないため、human-copy のステージングパスも live と同様に
  エージェント書込みが拒否されるためである。ドラフトをステージングパスへ配置
  する作業は、その後の live 適用と同じく**人間のアクション**であり、
  `specs/epic-136-phase3/human-copy/MANIFEST.sha256` がその検証用ダイジェスト
  を記録する。詳細は `reports/implementation/epic-136-phase3/T-003.md` を参照。

## v1.11.1 (2026-07-22)

### 修正

- **impl-review verdict の CWD 相対解決による誤 deny を修正 (WFI-016, Issue
  #207)**: `sdd-hook-guard.py` / `.js` / `.ps1` の 3 twin が
  `reports/impl-review/<feature>/attempt-*/round-*/integrated-verdict.json`
  をプロセス CWD 相対でのみ探索していたため、セッションの作業ディレクトリが
  リポジトリ外にあると真正な PASS verdict が存在しても
  `Impl-Review-Status: Passed` の書き込みを誤って拒否していた
  (2026-07-22 epic-191 impl-review で顕在化)。探索起点を既存の
  `_resolve_project_root` と同順の多段解決
  (`CLAUDE_PROJECT_DIR` → 編集対象 design.md のパスから上方探索した
  git root → CWD) に変更。判定基準 (PASS / PASS-with-warnings の存在) は
  不変で、FAIL・verdict 不在はいかなる CWD からも従来どおり拒否される
  (non-decreasing)。変更は Phase 2 human-copy レーン経由で人間承認・適用済み
  (`docs/workflow-improvements/WFI-016.md`、適用は手動コピー経路)。
- **stale staging の巻き戻り事故を修正・恒久検知を追加 (WFI-016 followup)**:
  適用前監査で human-copy ステージの 3 target (`check-contract.ps1`、
  ship スキル文書、CI ワークフロー定義) が `2b8a52f` 時点の古い断面のまま
  残っており、そのまま適用すると後続の live 修正 (CI 定義は 10 コミット分)
  が巻き戻る状態だったため live バイトへ再同期。再発防止として
  `tests/phase2-guard-invariants.tests.sh` / `.ps1` に「staged 全 target が
  live とバイト同一であること」の恒常チェックを追加した。

### 追加

- **guard-parity に outside-CWD シナリオ 3 件 (37-39)**: CWD がリポジトリ外
  + `CLAUDE_PROJECT_DIR` 指定 + PASS verdict → allow (37、修正前ガードでは
  exit 2 で失敗する RED 再現)、環境変数なしで file_path からの git-root
  上方探索 + PASS → allow (38)、同条件で FAIL verdict → 依然 deny (39、
  ゲートが緩まないことの固定)。スイートは 36 → 39 シナリオ。
- **human-copy inventory を 18 → 19 target へ拡張**: `tests/guard-parity.tests.sh`
  を `phase2_human_copy_targets` / `PHASE2_TARGETS` / `$BootstrapTargets` に
  追加し、ガードを検証するパリティスイート自体が検証対象のガードと同じ
  レビュー済み適用レーンを通るようにした。generated 4 ファイル再生成、
  `MANIFEST.sha256` 再生成 (19 行)。inventory 変更を含む適用は設計上
  update モードでは通らないため、ランナーは `-Bootstrap` で実行する。

## v1.11.0 (2026-07-21)

### 追加

- **Resolver Evidence 契約とスキーマ適合スイート (Issue #193, epic-193-a5
  T-001)**: `contracts/resolver-evidence.schema.json`(schema
  `sdd-resolver-evidence/v1`、draft-07)を新規追加。Capability Resolver
  (`resolve-project-context`、T-002〜T-004 で実装予定)が毎回の呼び出しで
  出力する、この機能唯一の新規アーティファクト
  `specs/<feature>/resolver-evidence.yaml` の構造契約を固定する。
  `capability_evaluations[]` は Registry の `capabilities[]` と exact-set
  対応し、`matched: false` の場合は `conditional_facet_evaluations` キー
  自体を持てない (`if`/`then`)。`diagnostics[].id` は REQ-002 の16値
  closed enum。新スイート `tests/resolver-evidence-schema.tests.sh` /
  `.ps1` が、スタンドアロンの stdlib-only Python 検証器
  (`tests/resolver-evidence-schema-check.py`、draft-07 のこの契約が使う
  キーワードのみを実装した hand-rolled サブセット検証器。第三者ライブラリ
  なし)を介して、hand-crafted な有効/無効フィクスチャ12件
  (`tests/fixtures/capability-resolver/resolver-evidence-schema/`)を
  この契約に対して直接検証する — ライブの Registry/Resolver 呼び出しは
  一切行わない(それは T-002〜T-004 の範囲)。`tests/run-all.sh` /
  `tests/run-all.ps1` へ自スイートを直接登録。受け入れ先行
  (acceptance-first、medium tier)で RED
  (`specs/epic-193-a5-capability-resolver/verification/T-001-red-sh.log`,
  `T-001-red-ps1.log`: スキーマ不在によりスイートが fail)→ GREEN
  (`T-001-green-sh.log`, `T-001-green-ps1.log`)の順で実装。

  **人手適用待ち(HUMAN APPLY STEP)**: R-10 保護ファイルである
  `.github/workflows/test.yml` は、その human-copy ステージング先
  (`specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml`)自体も同一の保護 suffix 判定に一致し、エージェントによる
  書き込みが hook-guard により deny された(迂回は行っていない)。意図した
  完全な補正版(既存ライブ内容+本スイートの新規CIステップ2件)は
  `reports/implementation/epic-193-a5-capability-resolver/T-001.md` の
  Human Apply Step セクションに sha256
  (`aadf23b77f53bb5ce057295f8880f9815f3d591e2e97afedb910241d6892209b`)
  とともに記載済み。`MANIFEST.sha256` はこのハッシュ値を記録済みだが、
  対応する `test.yml` 自体は human-copy 配下にまだ存在しない — 人間が
  報告書の内容を直接適用し、ハッシュ一致を確認する必要がある。
  詳細は `reports/implementation/epic-193-a5-capability-resolver/T-001.md`
  を参照。
- **Registry validator + provider-terms allowlist (Issue #190,
  epic-190-a2-capability-registry T-004)**:
  `plugins/sdd-quality-loop/scripts/validate-capability-registry.{py,sh,ps1}`
  を新規追加。REQ-003(a-i) の9独立チェック
  (gate-id-duplicate/implementation-ref-missing/unregistered-script/
  pack-owns-gate-definition/stage-missing/dangling-gate-reference/
  provider-name-detected/unknown-upgrade-reason/capability-id-duplicate)
  を実装。Gate implementation identity схема(`.py` canonical参照のみ、
  唯一の scan root、`check-` prefix 規則、`.sh`/`.ps1`/`.js` wrapper
  grouping、symlink 解決)を含む。テスト分離のため `--repo-root` を
  追加(デフォルトは registry_discovery 経由の git-root 解決、
  checks (b)/(c)/(d) のファイルシステム依存をテスト用の隔離済み
  fake repo で検証可能に)。併せて `plugins/sdd-quality-loop/
  references/provider-terms.json`(cloud-provider/distribution-channel/
  workflow-runtime-product-name の3カテゴリ)を新規追加。新スイート
  `tests/validate-capability-registry.tests.sh` / `.ps1`(各23
  checks)は TDD Red→Green で実装(RED: 常に成功を返す stub に対し
  12/23 失敗確認 → GREEN: 23/23 合格)、9チェック各1つの
  minimally-mutated fixture、check(c) の bidirectional
  fixture set、check(i) の combined-duplicate fixture、
  fully-clean fixture(全チェック合格を証明)を含む。REQ-005
  share の AC-028 構造配置チェック(`plugins/sdd-capability/` 不在、
  REQ-002..005 の全ファイルが `plugins/sdd-quality-loop/` 配下)も
  スイート自身の setup assertion として実装。証跡は
  `specs/epic-190-a2-capability-registry/verification/T-004/`
  配下の `{red,green}-{sh,ps1}.log`。`tests/run-all.sh`/`.ps1` へ
  自スイート登録、`.github/workflows/test.yml` は直接書き込まず
  human-copy 経由でステージ(T-003 の候補に追記)。詳細は
  `reports/implementation/epic-190-a2-capability-registry/T-004.md` を参照。
- **Registry discovery contract + vendored-copy packaging (Issue #190,
  epic-190-a2-capability-registry T-003)**: ADR-0029(2026-08-11 の
  番号衝突解消まで ADR-0025)の三段階
  script-relative 探索(`plugins/sdd-quality-loop/scripts/registry_discovery.py`、
  T-004/T-005 が import する共有 helper)を実装。①自スクリプトの
  symlink 解決済み実パスから `../contracts/<filename>` のパッケージ済み
  コピーを最優先(ランタイム環境変数は一切参照しない)、②`git rev-parse
  --show-toplevel`(`git` 不在時は `.git` 上方探索)フォールバック、
  ③アーティファクトごとの独立バージョンチェック(Registry:
  `schema=="capability-registry/v1"`、schema ファイル: `$schema` 存在+
  `$id` 一致、catalog: `schema=="lite-upgrade-reason-catalog/v1"`)失敗時は
  両方の試行パスを名指しした fail-closed 診断で非ゼロ終了(Security
  Boundary B4)。併せて `vendor-capability-registry.{py,sh,ps1}`
  (`generate-guard-invariants.py --check` と同型の no-write/sha256 比較
  `--check` モード)を新規追加し、`contracts/*` の canonical 3ファイルを
  `plugins/sdd-quality-loop/contracts/` へ実際にベンダリング。新スイート
  `tests/registry-discovery.tests.sh` / `.ps1`(各21 checks)は TDD
  Red→Green で実装(RED: 意図的に壊れた stub に対し 15/21 失敗確認 →
  GREEN: 21/21 合格)、3ランタイム分の installed-layout fixture(うち1件は
  symlink 経由起動で symlink 解決も検証)・3件のバージョン不一致
  fixture・neither-location-resolves fixture・vendored-copy-drift
  fixture を含む。証跡は
  `specs/epic-190-a2-capability-registry/verification/T-003/`
  配下の `{red,green}-{sh,ps1}.log`。`tests/run-all.sh`/`.ps1` へ
  自スイート登録、`.github/workflows/test.yml` は直接書き込まず
  human-copy 経由でステージ(T-002 の候補に追記)。詳細は
  `reports/implementation/epic-190-a2-capability-registry/T-003.md` を参照。
- **Predicate DSL evaluator (Issue #190, epic-190-a2-capability-registry
  T-002)**: `plugins/sdd-quality-loop/scripts/evaluate-predicate.{py,sh,ps1}`
  を新規追加(ADR-0020 完全実装、Python master + thin sh/ps1 wrapper、
  INV-014)。closed 8演算子文法(`all`/`any`/`not`/`equals`/`not_equals`/
  `contains`/`in`/`exists`)、`equals`/`not_equals`/`contains`/`in` の
  fail-closed 一般則(missing path/null/type-mismatch → `false`+`WARN`、
  例外を投げない)、`exists` の例外(存在すれば値に関わらず `true`、
  不在なら `false`+`WARN`、型検査なし)、`all`(空→`true`)/`any`
  (空→`false`)の non-short-circuit 評価、`not` の厳密単項アリティ+
  真理値表(child=`warn` のときは素朴な否定ではなく `not` 結果も
  `false` に倒す特別則)、`trigger`/`conditional_facets[].when` が
  共有する単一評価器+単一フィールド許可リスト(第二の条件言語なし)を実装。
  フィールド許可リストは Epic A1 の Project Context schema
  未着地(investigation.md INV-004a)のため `--check-field-allowlist`
  drift-check モード+fixture スタンドインで機構の正しさのみ先行証明。
  新スイート `tests/evaluate-predicate.tests.sh` / `.ps1`(63 checks
  each)は TDD Red→Green で実装(RED: 意図的に許容的な stub 実装に対し
  50/63 失敗を確認 → GREEN: 全63 checks 合格)、証跡は
  `specs/epic-190-a2-capability-registry/verification/T-002/`
  配下の `{red,green}-{sh,ps1}.log`。`tests/run-all.sh`/`.ps1` へ
  自スイート登録、`.github/workflows/test.yml` は直接書き込まず
  human-copy 経由でステージ(T-001 の候補に追記)。詳細は
  `reports/implementation/epic-190-a2-capability-registry/T-002.md` を参照。
- **Capability Registry スキーマ・インスタンス・lite-upgrade-reason カタログ
  (Issue #190, epic-190-a2-capability-registry T-001)**:
  `contracts/capability-registry.schema.json`(draft-07、`contracts/
  workflow-state-registry.schema.json` の `$id`/スタイル規約踏襲)を新規追加。
  `gates[]`(`id`/`stage`/`blocking`必須、`stage: implementation` のときのみ
  `implementation_ref` を条件必須の `if`/`then`)、`capabilities[]`
  (`id`/`trigger`/`required_facets`/`conditional_facets`/`review_check_ids`/
  `gate_ids`/`delivery_strategy` を `required` 明記、`lite_policy`/
  `minimum_enforcement` のみ真に任意)、`trigger`/`conditional_facets[].when`
  が共有する `#/definitions/predicate`(8演算子閉集合の `oneOf`、`not` は
  単一子でアリティ1を構造的に強制)を全て `additionalProperties: false` で
  実装。`contracts/capability-registry.json`(illustrative fixture、
  INV-002)と `contracts/lite-upgrade-reason-catalog.json`
  (ADR-0022 の5トークン初期セット)も新規追加。新スイート
  `tests/capability-registry-schema.tests.sh` / `.ps1` は、schema
  ファイルを汎用エンジンで解釈するのではなく jq/PowerShell で独立に
  再実装した厳密predicate(`workflow-state-registry.tests.sh` と同じ
  規約)で、6件の accept fixture と16件の reject fixture (TEST-001..006,
  TEST-037, TEST-038 相当)を検証。受け入れ先行(acceptance-first)で RED
  (各 reject fixture が意図的に緩い permissive スタンドイン schema には
  誤って受理されることを証明)→ GREEN (正しい厳密predicateで全fixtureが
  期待どおりの結果になることを確認)の順で実装、証跡は
  `specs/epic-190-a2-capability-registry/verification/T-001/` 配下の
  `{red,green}-{sh,ps1}.log`。`tests/run-all.sh` / `tests/run-all.ps1`
  へ自スイートを直接登録(grep 自己検査つき)。R-10 保護ファイルである
  `.github/workflows/test.yml` は直接書き込まず、本スイートの新規CIステップ
  (bash/pwsh 両レーン)を反映した完全な補正版を
  `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
  + `MANIFEST.sha256` としてステージし、人間の `cp` 適用を待つ(適用前後で
  ライブファイルの SHA-256 は不変)。詳細は
  `reports/implementation/epic-190-a2-capability-registry/T-001.md` を参照。

- **component path ownership resolver — グロブ意味論と分類 (Issue #191,
  epic-191-a3-path-ownership T-001)**: `plugins/sdd-quality-loop/scripts/
  resolve-component-paths.{py,sh,ps1}` を新規追加。`project-context.yaml`
  の `components[].paths.{include,exclude}` / `shared_paths[]` を読み、
  変更パス群を `EXCLUSIVE` / `SHARED_BOUNDED` / `SHARED_CROSS_CUTTING` /
  `OVERLAP` / `UNOWNED` に分類する。`**` はゼロ以上の完全セグメント(ゼロ
  セグメントの `a/**/b` が `a/b` に一致するケースを含む)、裸の `*` は
  単一セグメント内のみ、`?`/`[...]` 等の未対応メタ文字は load 時に
  fail-closed で拒否。パターン/パスは比較専用に Unicode NFC 正規化し、
  raw path のバイト列自体は出力の identity として保持(NFC 衝突は
  fail-closed のコリジョンエラー)。マッチングは常にバイト単位で
  大文字小文字を区別。component 自身の `exclude` は同一 component の
  `include` に絶対に優先し(Fail-5 不変条件)、その結果 UNOWNED になった
  パスには `EXCLUDED_MATCH` エビデンスタグを付与。`shared_paths` は
  bounded(`components:` 明示リスト)/cross-cutting(`classification:
  cross-cutting`)の二者択一で、両方または どちらも無い設定は
  fail-closed。YAML パーサーは本リポジトリの CI が PyYAML 等の外部
  依存を一切インストールしないため独自実装の制限付きサブセット
  (ADR-0020 の restricted-DSL 方針を踏襲、ADR-0025 に記録)。
  Epic A1 の正式スキーマ(`contracts/project-context.template.yaml`)
  との適合性チェック(`--check-schema-conformance`)は AC-011 により
  当該アーティファクトが存在しない間 fail-closed で恒常的に赤のまま
  (Epic A1 未着地の間の意図された挙動、バグではない)。
  新スイート `tests/component-path-resolver.tests.sh` / `.ps1`
  (TEST-001〜018 + TEST-045、`tests/fixtures/component-path-ownership/`
  配下の静的フィクスチャで駆動)を追加し `tests/run-all.sh` /
  `tests/run-all.ps1` へ自己登録。R-10 保護ファイルである
  `.github/workflows/test.yml` は直接書き込まず、本スイートの新規CI
  ステップ(bash/pwsh 両レーン)を反映した補正版の human-copy staging を
  試みたが、インストール済み Claude Code の PreToolUse フック
  (`sdd-hook-guard.sh`)が human-copy/ 配下でも `test.yml` という
  basename を無条件にブロックしたため本コミットには含まれていない
  (`specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256` に
  詳細と再現手順を記録、`reports/implementation/
  epic-191-a3-path-ownership/T-001.md` のBlockersも参照)。
  ADR-0025 でグロブ意味論・優先順位・六つのFail条件定義を記録。

- **effort routing v2 レジストリとパリティロック (Issue #149, epic-159-pillar-c
  T-001)**: `contracts/agent-model-capabilities.v2.json`(schema
  `agent-model-capabilities/v2`)を新規追加。v1 の tier↔effort 1:1溶接
  (`haiku`→`low`、`sonnet`→`medium`、`opus`→`high`)を解消し、モデルごとに
  `supported_efforts`(非空配列)・`default_effort`(`supported_efforts` の
  要素)・`effort_control`(`claude-code`/`codex-cli` それぞれ
  `flag`/`frontmatter`/`none`)を表現可能にした。トップレベルの
  `risk_effort_matrix` は `low`→`low`・`medium`→`medium`・`high`→`high`・
  `critical`→`high` を厳密にマップし `escalation_bump: true` を持つ
  (`xhigh` は直接値として一切出力されない)。`role_defaults` は
  `spec-reviewer`/`impl-reviewer`/`task-reviewer`/`sdd-evaluator`/
  `sdd-investigator` の5ロール全てに `minimum_tier` + `default_effort` を
  定義。v1 (`contracts/agent-model-capabilities.json`) はバイト単位で凍結
  (SHA-256 不変、本タスクでは一切書き込まない)。新スイート
  `tests/agent-capabilities-v2.tests.sh` / `.ps1` が、v1⇔v2
  双方向パリティ(v1 の全モデル名が同一 `canonical_tier` で v2 に存在し、
  v1 の `efforts` 配列が v2 `supported_efforts` の部分集合であること)を
  ロックし、v2 コピーからv1必須effortを剥奪した mutation-based negative
  self-check でロックが恒常的に有効であることを自己証明する。
  `tests/run-all.sh` / `tests/run-all.ps1` へ自スイートを直接登録
  (grep 自己検査つき)。R-10 保護ファイルである
  `.github/workflows/test.yml` は直接書き込まず、本スイートの新規CIステップ
  (bash/pwsh 両レーン)を反映した完全な補正版を
  `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` +
  `MANIFEST.sha256` としてステージし、人間の `cp` 適用を待つ
  (適用前後でライブファイルの SHA-256 は不変)。`PLUGIN-CONTRACTS.md` に
  `agent-model-capabilities/v2` スキーマの新セクションを追加(AC-005)。
  受け入れ先行(acceptance-first)で RED
  (`specs/epic-159-pillar-c/verification/T-001/red-sh.log`: v2 ファイル
  不在によりスイートが fail)→ GREEN
  (`specs/epic-159-pillar-c/verification/T-001/green-sh.log`)の順で実装、
  詳細は `reports/implementation/epic-159-pillar-c/T-001.md` を参照。
- **selector v2 対応・effort-resolution 優先順位・ADR-0012 (Issue #150,
  epic-159-pillar-c T-002)**: `select-agent-model.sh` / `.ps1` が
  `--registry` の `schema` フィールドから v1/v2 を自動判別するように
  なった。v1 レジストリ(レガシー位置引数 `--candidate name:tier:cost` 含む)
  の経路は完全にバイト不変(AC-006、差分ファズ 32/32・29/29 件一致で検証)。
  新規4フラグ: `--effort-policy welded|matrix`(既定 `welded`、Phase 1 全体
  でこの既定を維持)・`--requested-effort <e>`(明示オーバーライド、両
  policy で勝つ・`supported_efforts` へクランプ・`xhigh` は
  `--xhigh-reason` 必須)・`--role <role>`(常に `--minimum-tier` を
  シード、`matrix` かつ `risk_effort_matrix` に該当 risk が無い場合のみ
  役割既定 effort もシード、`welded` 下では effort 成分は完全に不活性)・
  `--host claude-code|codex-cli`(既定 `claude-code`、勝者モデルの
  `effort_control` を JSON へ解決)。JSON 出力へ加法的キー
  `effort_source`(`requested`/`risk-matrix`/`role-default`/
  `model-default`/`welded` の5値)・`effort_control` を追加、既存7キーは
  名前・型とも不変。`welded` は v2 でも v1 相当のバイト同一出力を再現し
  (AC-007、意図的にゴールデン対象から外した候補ファイルの可用性を
  ミューテートする negative self-check で比較が生きていることを証明)、
  `--requested-effort` が `welded` 下でも常に勝つ carve-out(AC-053)は
  この golden 比較対象外であることを構造的に保証。`matrix` は
  `risk_effort_matrix[risk]` → escalation bump →
  `supported_efforts` への最近傍クランプの順で解決し、bump 後に
  `xhigh` へ着地した場合も `--xhigh-reason` ゲートを再適用(AC-008/
  AC-009)。v2 `--candidates-file` の各エントリは `effort` を省略可能
  (省略時は policy が補完)だが v1 は従来どおり必須のまま拒否
  (AC-013)。v2 レジストリの `supported_efforts`(空/非配列)・
  `effort_control`(列挙外値)・`risk_effort_matrix`(非文字列値)の
  各カテゴリを fail-closed で `MODEL_SELECTION_ERROR` 診断とともに
  拒否(AC-054、カテゴリごとに1フィクスチャで検証)。
  `docs/adr/0012-effort-tier-decoupling.md` を新規起草(`ls docs/adr/` で
  `0012` の空きを再検証済み、ADR-0003 の tier↔effort 溶接部分のみを
  narrow し、tier 選択アルゴリズム自体は変更しない)。
  `tests/agent-model-routing.tests.sh` を拡張し TEST-006..013/053/054 の
  Phase-1-scoped smoke を追加(bash 側フル + pwsh 側スポットチェック、
  完全な twin 網羅は T-005 の所掌)。受け入れ先行(acceptance-first)で
  RED(`specs/epic-159-pillar-c/verification/T-002/red-sh.log`: 新規
  フラグが未知引数として拒否される)→ GREEN
  (`specs/epic-159-pillar-c/verification/T-002/green-sh.log`)の順で実装、
  詳細は `reports/implementation/epic-159-pillar-c/T-002.md` を参照。
- **render-agent-frontmatter・--check・R-10 保護ファイル human-copy 手順
  (Issue #151, epic-159-pillar-c T-003)**: 新規 `render-agent-frontmatter.sh` /
  `.ps1` を追加。v2 レジストリの `role_defaults` を単一の真実源として、
  ロール→ファイルの固定 `TARGETS` マップ(`sdd-evaluator`/`sdd-investigator`/
  `spec-reviewer`/`impl-reviewer`/`task-reviewer` の5ロール、Claude `.md` と
  Codex `.toml` の双方)に沿って描画する。Claude 側は保護対象外の `.md`
  エージェントファイルの `model:` frontmatter 行のみを書き換え(既に
  `role_defaults` と一致していれば無変更)、frontmatter の閉じ `---` 直後に
  `<!-- x-sdd-effort: <e> -->` コメント行を挿入/更新する(YAML
  frontmatter キーではなく単なるコメントなので、エージェントローダーの
  frontmatter パースには一切参加しない)。Codex 側は `.codex/agents/*.toml`
  の先頭に `# x-sdd-model: <m>` / `# x-sdd-effort: <e>` の2行の参照コメントを
  挿入/更新し、`name`/`description`/`sandbox_mode`/`developer_instructions`
  など既存の TOML キーはバイト単位で不変(このコメントはドキュメント専用で
  Codex CLI にパースされない、OQ-002 の解決どおり)。R-10 保護される4つの
  レビューループ reviewer `.md` ファイル(`impl-reviewer-{a,b}.md`、
  `task-reviewer-{a,b}.md`)は書き込み先解決関数自体が構造的に実パスへ
  絶対に解決しない(AC-019、`--resolve-target-raw`/`--resolve-target` で
  関数そのものを直接テスト可能)。補正内容は
  `specs/epic-159-pillar-c/human-copy/<リポジトリ相対パス>` に4ファイル
  ステージし、`MANIFEST.sha256` に SHA-256 エントリを追記、実パスは一切
  書き込まない。`--check` モードは全ターゲット(4保護ファイル含む)を
  読み取り専用で比較し、ドリフト検出時は非ゼロ終了(AC-016)。保護
  ファイルへの読み取りは書き込みではないため R-10 ガードを一切踏まず、
  CI 無人実行が可能(AC-020)。`role_defaults` は現行の本番値からシードして
  あるため、実ファイルへの初回描画は `model:` 値に関して zero-diff no-op
  (AC-017、6つの保護対象外ターゲットで検証済み・実際に本番描画を実行し
  `plugins/sdd-quality-loop/agents/evaluator.md` ほか5ファイルへ
  `x-sdd-effort` 行のみを追加)。`model: inherit` のエージェントとロール
  マップに存在しないエージェント(`domain-reviewer-*` 等)は描画対象から
  構造的に除外(AC-018)。`--check` は `tests/validate-repository.ps1` の
  既存チェック列と `.github/workflows/test.yml`(T-001 がステージ済みの
  候補に本タスクの新規ステップを追記、bash/pwsh 両レーン)に配線。
  リスク `high`(このタスクだけが本番の Claude/Codex エージェント定義
  ファイル群と R-10 保護境界そのものに書き込む)につき Required Workflow
  は `tdd`: 書き込み境界(AC-019)と読み取り境界(AC-020)を独立した
  RED/GREEN ペアとして分離記録(`specs/epic-159-pillar-c/verification/T-003/`
  配下、`red-sh.log`/`green-sh.log`、`red-ps1.log`/`green-ps1.log`;
  AC-019 は書き込み先解決関数を意図的に誤分類した widened map で実パスへ
  解決することを示す負例と、正しい既定マップでの正例のペア、AC-020 は
  同期済みフィクスチャで OK・x-sdd-effort 値をミューテートしたフィクスチャで
  再度 DRIFT になる negative self-check のペア)。PowerShell twin は
  T-002 で確立した2層の case-sensitivity 規律(`-ceq`/`-cne`/`-cmatch` の
  明示的使用、`role_defaults` キーは `.PSObject.Properties` 列挙+`-ceq`で
  照合し PSObject のドット参照の大小文字非依存性を回避)を踏襲し、
  role_defaults キーと `canonical_tier` 値それぞれの mis-cased
  negative fixture で両 twin が拒否することを検証。新スイート
  `tests/render-agent-frontmatter.tests.sh` / `.ps1` は本番ファイルの
  コピーのみを操作し(ライブファイルへは一切書き込まない)、`tests/run-all.sh` /
  `tests/run-all.ps1` へ自スイートを直接登録(grep 自己検査つき)。詳細は
  `reports/implementation/epic-159-pillar-c/T-003.md` を参照。
- **run-record v2: effort attribution + degradation lock (Issue #153,
  epic-159-pillar-c T-004)**: `emit-run-record.sh` / `.ps1` へ
  `--effort-main` / `--effort-reviewers` / `--effort-control-main` /
  `--effort-control-reviewers` / `--effort-applied-main` /
  `--effort-applied-reviewers` の6フラグを追加。いずれか1つでも指定されると
  `schema` が `sdd-run-record/v2` へ昇格し、`model_ids` に隣接する
  `effort` オブジェクト(`main`/`reviewers` 各キーに
  `effort_requested`/`effort_applied`/`effort_degraded_reason` の3
  サブフィールド)が加法的に出現する。フラグが一切指定されない場合の経路は
  v1 の heredoc / レコード構築部分を一切変更せず未加工のまま複製した分岐で
  処理するため、byte 単位で従来と不変(AC-025、`git diff` によるソース
  レベル比較と既存のコミット済み v1 レコード
  `reports/runs/RUN-20260705T023011Z-sdd-forge-mcp.json` の読み取り専用
  検証の両方で確認)。`effort_applied` は「ペアの
  `--effort-control-*` が `flag` に解決され、かつ適用が確認された」経路
  以外では絶対に非 null にならない構造的保証(security-spec.md B4)を実装:
  `--effort-applied-*` に非 `none` 値が渡されたのに対応する
  `--effort-control-*` が `flag` でない場合は fail-closed で拒否
  (受理して黙って握りつぶすことはしない)。`effort_degraded_reason` は
  `effort_applied` が null かつそのロールスロットの `--effort-*` が
  指定された場合にのみ非空(AC-024、両方向を
  `tests/emit-run-record-feature-scope.tests.sh`/`.ps1` の
  TEST-021..026/TEST-051 でロック)。reason 文字列は解決済み
  `effort_control` 値をキーにする(`effort-control-frontmatter`/
  `effort-control-none`/`effort-application-declined`/
  `effort-application-not-confirmed`)ため、Codex ホストが
  `effort_control.codex-cli` が `frontmatter`/`none` のモデルを選択した
  ケースも Claude Code のケースと完全に同一形状で劣化することを構造的に
  証明(AC-051、host 名ではなく effort_control 値そのものに基づく)。
  PowerShell twin は T-002/T-003 で確立した2層 case-sensitivity 規律を
  継承: layer 1 は `--effort-control-*` 値に対する ordinal
  `HashSet[string]` メンバーシップ検査(`[System.StringComparer]::Ordinal`)、
  layer 2 は `Resolve-EffortSlot` 内の分岐ディスパッチにおける `-ceq` の
  明示使用。mis-cased negative fixture(`Flag`)が両 twin で fail-closed に
  拒否されることを検証。pwsh 7 のデフォルト ConciseView エラー整形が
  部分文字列マッチによるテストアサーションを壊す問題(T-003 で発見)を
  回避するため、新規エラーパスは `[Console]::Error.WriteLine()` による
  プレーンテキスト出力を用いる。`implementation-report.template.md` に
  `- Model:` / `- Effort:` の2行を追加し、
  `validate-implementation-report.sh` が存在チェックとフォーマットのみを
  検証(値の正しさは検証しない、既存スコープに合わせる)。
  `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` の Process
  手順15にも同じ2行要件を明記。テストスイートの各シナリオは同一秒内の
  ファイル名衝突を避けるため専用の feature slug を使用し、jq 出力は
  `tr -d '\r'` を経由(CI resilience)。詳細は
  `reports/implementation/epic-159-pillar-c/T-004.md` を参照。
- **routing テストの full ケース化 + PowerShell twin 新設 + test.yml 登録ギャップ
  閉鎖 (Issue #154, epic-159-pillar-c T-005)**:
  `tests/agent-model-routing.tests.sh` を REQ-002/REQ-005 の全ケースへ拡張
  (TEST-027: 三部構成の保護 `test.yml` 登録証明 -- (a)
  `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` への
  ステージ済み候補 + `MANIFEST.sha256` 整合、(b) ライブ
  `.github/workflows/test.yml` の SHA-256 不変(本タスク前後で
  `3099a2a8e9ddc61b38fa5ef6b76be7b6181c5aa383225341f304330b88f65716`
  のまま)、(c) human-copy 適用後の自己登録 grep は適用後に初めて成立する
  性質として実装レポートに記載; TEST-034: v1↔v2 selector 出力レベルでの
  投影不変量、`tests/agent-capabilities-v2.tests.sh` の TEST-004 と
  フィクスチャ共有)。新規 `tests/agent-model-routing.tests.ps1` を追加し、
  requirements.md の Problems 節が指摘していた事前存在の twin ギャップを
  解消。`.sh` の全ケースリストを 1 対 1 移植しつつ、Windows CI レーンで
  bash/jq への依存を持たないよう各二重ランタイムケースの PowerShell
  ネイティブ半分のみを移植。PowerShell 固有の regression ケース(sv-SE
  スレッドカルチャ下でも select-agent-model.ps1 内部の
  `[StringComparer]::Ordinal` タイブレークが揺らがないことの証明)と、
  T-002/T-003 で確立した2層 case-sensitivity 規律(`-ceq`/`-cne`/
  `-ccontains` 演算子 + registry/candidate 文字列に対する ordinal
  Dictionary、mis-cased negative fixture ペア)を継承。`tests/run-all.ps1`
  へ新 twin を直接登録(`tests/run-all.sh` の既存登録行は不変を再確認)。
  `.github/workflows/test.yml` は R-10 保護ファイルであり直接編集せず、
  両 twin の CI ステップ(bash/pwsh 両レーン)を追記した完全な補正版を
  `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` +
  `MANIFEST.sha256` としてステージ。`tdd` ワークフロー(Risk: high)で RED
  (`specs/epic-159-pillar-c/verification/T-005/red-twin-absent.log`:
  twin 不在によりスイートが fail、`red-mutated-golden.log`: 変異させた
  golden フィクスチャに対する比較が red 化することで TEST-028 の
  mutation-based negative self-check が discriminating であることを
  証明)→ GREEN (`specs/epic-159-pillar-c/verification/T-005/green-sh.log`
  / `green-ps1.log`)の順で実装、詳細は
  `reports/implementation/epic-159-pillar-c/T-005.md` を参照。
- **Codex ホストへの effort 実適用 + argv injection 拒否 + REQ-008 締めくくり監査
  (Issue #152, epic-159-pillar-c T-006)**: `run-panelist-gpt.sh` / `.ps1` に
  `--effort <e>` / `-Effort <e>` を追加し、指定時のみ既存の `codex --model ...`
  呼び出し(`run-panelist-gpt.sh:146` 相当)に `--effort <e>` を追記(未指定なら
  従来どおりバイト単位で不変、AC-035)。`prepare-panelist-input.sh` / `.ps1` に
  同名のパススルーフラグを追加し、selector 由来の effort 値を stdout の
  第2行(`effort=<e>`)経由で呼び出し側の `run-panelist-gpt --effort <e>` へ
  橋渡し(AC-036、両スクリプトは別プロセスで直接連結されないため verbatim な
  受け渡しとして実装)。`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`
  に Codex ホストでの `sdd-evaluator`/`sdd-investigator` 起動手順を明記:
  `select-agent-model.sh --host codex-cli --role <role> --json` の
  model+effort 出力を `codex` の CLI フラグとして供給し(AC-037、実際に
  `contracts/agent-model-capabilities.v2.json` の実レジストリと
  `.codex/agents/sdd-evaluator.toml` / `sdd-investigator.toml` の
  `# x-sdd-model:` / `# x-sdd-effort:` 参照コメント(T-003 が描画)を突き合わせて
  一致することを確認済み)、その値をT-003の描画済み参照コメントと突き合わせる
  cross-check が乖離を `DRIFT: <toml> toml=<m>/<e> live=<m>/<e>` として
  検出可能な形で報告する(AC-038、どちらの値も無言で優先しない)。Claude Code
  経路は `select-agent-model --host claude-code` が全 Anthropic モデルで
  `effort_control: frontmatter` に解決することを利用し、`emit-run-record
  --effort-control-main frontmatter` を通じて `effort_applied=null` +
  `effort_degraded_reason=effort-control-frontmatter` を実レコードに記録
  (AC-039、REQ-008、T-004 の AC-024/AC-051 と同一の field-population
  ルールを共有)。**AC-052 (security-spec.md B3)**: `--model`/`--effort` の
  語彙外形状(空白混入・先頭 `-`/`--`・`;` 区切り、及び `--effort` は
  `{low, medium, high, xhigh}` 外の文字列)を argv 構成前に拒否し、非ゼロ
  exit・診断メッセージ・`codex` 呼び出し 0 回を保証(検証は実 `codex` の
  代わりにスタブ実行体を使った argv/呼び出しマーカー記録方式、実LLM呼び出しは
  一切行わない、AC-040)。新規 `tests/run-panelist-effort.tests.sh` / `.ps1`
  (TEST-035..040/052、`tests/run-all.sh`/`.ps1` へ自スイート登録済み)を追加。
  **REQ-008 締めくくり監査(AC-047/AC-048)**: このフェーズが追加した
  effort 消費面は T-004 の run-record(AC-024: frontmatter/none 制御での
  null+reason 記録、AC-051: Codex ホストでも非 flag 制御なら host 名でなく
  解決済み `effort_control` 値で同一形状に劣化)と T-006 自身の panelist
  経路(AC-039)の2面のみで、いずれも Claude Code(または非 `flag` 制御)側の
  劣化ケースが実証済み、かつどのスイートも Claude Code の effort 機構欠如を
  理由に FAIL/SKIP とせず PASS 扱いであることを確認(実装レポートに
  面ごとのチェックリストとして記録)。R-10 保護ファイルである
  `.github/workflows/test.yml` は直接書き込まず、本スイートの新規CIステップ
  (bash/pwsh 両レーン)を T-005 の既存ステージ済み内容に追記する形で
  `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` +
  `MANIFEST.sha256` としてステージ(適用前後でライブファイルの SHA-256 は
  `3099a2a8e9ddc61b38fa5ef6b76be7b6181c5aa383225341f304330b88f65716`
  のまま不変)。受け入れ先行(acceptance-first)で RED
  (`specs/epic-159-pillar-c/verification/T-006/red-sh.log`: `--effort` が
  両スクリプトで未知引数として拒否される)→ GREEN
  (`specs/epic-159-pillar-c/verification/T-006/green-sh.log` /
  `green-ps1.log`)の順で実装、詳細は
  `reports/implementation/epic-159-pillar-c/T-006.md` を参照。
- **ループインベントリと登録強制スイート (Issue #141, epic-159-pillar-a T-001)**:
  `tests/loops/loop-inventory.json`(schema `loop-inventory/v1`)を、8つの
  レビュー/ゲートループ(spec-review / impl-review / task-review /
  domain-review / quality-gate / terminal-tier / wfi-audit /
  hitl-diagnosis)の唯一の機械可読レジストリとして追加。新スイート
  `tests/loop-inventory.tests.sh` / `.ps1` が、リポジトリから実際のループ面
  (`plugins/**/scripts/*-review-precheck.sh`、
  `validate-review-context-set.sh` の stage:role 認可ペア)を導出して
  インベントリと双方向に突合し、cap_source:script なエントリの数値上限を
  driver ソースへ grep 照合し(terminal-tier は cap_kind:state として除外)、
  skill-instruction 強制のループ(wfi-audit / hitl-diagnosis)が偽陽性を
  出さないことを確認し、`tests/run-all.sh` / `tests/run-all.ps1` /
  `.github/workflows/test.yml` への自スイート登録を強制する。各チェックは
  mktemp コピーに対する negative self-check を伴い、300秒の実行時間予算
  (`LOOP_SUITE_BUDGET_SECONDS`)を自己計測・自己 FAIL する。実装時の grep
  実測により、impl-review / task-review の round<=3 上限は precheck
  スクリプトではなく SKILL.md 文面でのみ強制されると判明したため、両ループ
  も `cap_source: skill-instruction` として登録(ADR-0010 参照、詳細は
  `reports/implementation/epic-159-pillar-a/T-001.md`)。
  `docs/adr/0010-loop-inventory-and-fixture-vocabulary.md`(Status Proposed)
  にこの発見を反映。
- **共有ループドライバとスモークスイート (Issue #142, epic-159-pillar-a
  T-002)**: `tests/lib/loop-driver.sh` / `.ps1`(source 専用、実行不可)を、
  spec/impl/task/domain の各レビューループを駆動する共有ハーネスとして追加。
  `loop_fixture_init`(greenfield は mktemp 上でゼロから合成、brownfield は
  呼び出し元供給の synthetic seed からコピー)は `specs/<feature>/`
  成果物・1エントリの workflow-state レジストリ・正準ハッシュ式
  (`sha256(sequence|stage|role|run_id|host_session_id|previous_record_sha256)`)
  による identity-ledger genesis チェーンを、リポジトリ作業ツリー外の
  fixture root に合成する。`drive_review_round` は REAL な
  `<stage>-review-precheck.sh` → 前ラウンドの実際の成果物一覧のみから構成
  した manifest → REAL な `validate-review-context-set.sh --reserve` →
  `tests/spec-review-loop.tests.sh` の `write_contract()` 形状(INV-008)に
  倣ったレビュワー成果物、の順で駆動する。`assert_artifacts_schema` /
  `assert_terminal` / `assert_runtime_budget`(`LOOP_SUITE_BUDGET_SECONDS=300`)
  を提供。新スモークスイート `tests/loop-driver.tests.sh` / `.ps1` が
  spec-review のラウンド1→3を実際に駆動して green を証明し、
  `tests/run-all.sh` / `tests/run-all.ps1` / `.github/workflows/test.yml`
  へ登録。**実装時の発見**: `spec-review-precheck.ps1` はリポジトリ上に
  存在しない(`.sh` のみ)ため、pwsh レーンの TEST-006(spec-review 駆動)
  は理由付きの named SKIP として記録(既存の domain-review pwsh 欠落パターン
  を踏襲)。`drive_review_round` は spec-review のみを完全実装し、
  impl/task/domain は明示的なエラーで拒否(A3/#143 スコープ、詳細は
  `reports/implementation/epic-159-pillar-a/T-002.md`)。
- **ループ整合性スイートと 2d8c6a5 RED differential 記録 (Issue #143,
  epic-159-pillar-a T-003)**: 新スイート `tests/loop-consistency.tests.sh` /
  `.ps1` が、spec / impl / task / domain の各レビューループをラウンド1→3
  (ラウンド1-2は NEEDS_WORK、ラウンド3は各ループの inventory `terminal`
  へ到達: spec/impl/task は PASS、domain は cap-reached BLOCKED)で駆動し、
  観測終了状態を loop-inventory の `terminal` と照合する(TEST-008)。
  impl-review ラウンド2レグが HEAD で green であることを毎回確認し
  (TEST-009)、`2d8c6a5^`(修正前の親コミット)に対する一度限りの RED 証跡を
  `specs/epic-159-pillar-a/verification/T-003/red-differential.log` に記録
  (`git worktree` 隔離 + `SDD_LOOP_REPO_ROOT` 上書きで、pre-fix
  `validate-review-context-set.sh` が impl-reviewer-a の前ラウンド
  `integrated-summary.json` manifest エントリを拒否する非ゼロ終了を実証)。
  各駆動ラウンドについて双方向不変条件(下流ゲートが要求する入力は上流ゲートが
  認可する入力である)を、REAL な `validate-review-context-set.sh` への
  read-only 再検証(`assert_bidirectional_invariant`、`--reserve` なし)で
  確認し、認可されない合成 manifest エントリで red化する negative
  self-check を伴う(TEST-010)。**スコープ裁定**:
  `tests/lib/loop-driver.sh` / `.ps1` の `drive_review_round` ディスパッチを
  impl/task/domain の3レビューステージへ拡張(T-002 の Out of Scope が
  この駆動を T-003/T-004 に割り当てており、T-003 の Goal 達成に必須。
  escalation chain の駆動は対象外、T-004 のまま)。`loop_fixture_init` を
  design.md・4レイヤー仕様・traceability.md・domain/ ツリーの合成へ拡張
  (harmless な追加のみ、T-002 の既存契約は無変更、
  `tests/loop-driver.tests.sh` / `.ps1` の green を再確認済み)。**実装時の
  発見**: pwsh レーンでは `spec-review-precheck.ps1` 欠落(T-002 既知)が
  impl/task レグへ推移的に伝播する(両者とも spec-review の実成果物を前提と
  するため)。`domain-review-precheck.ps1` も個別に欠落(#147)。両欠落とも
  理由付きの named SKIP として記録、TEST-010/TEST-017 は両レーンで実際に
  green。OQ-5(`task-review-precheck.sh:219-222` の `require_persisted_pass`
  が stage "impl" で impl-review 成果物を読む箇所)を読み取り専用で調査し、
  task-review 前提条件の検証としてタスクレビューの独立な深層検証(defense-
  in-depth)であるとの所見を記録(詳細は
  `reports/implementation/epic-159-pillar-a/T-003.md`)。
- **quality-gate エスカレーションチェーンと template⇔gate parity 拡張
  (Issue #144, epic-159-pillar-a T-004)**: 新スイート
  `tests/loop-escalation.tests.sh` / `.ps1` が、gate-report 件数 0/1/2 →
  `continue`、3 → `Escalate-Human`(`check-quality-gate-cycle-limit.sh`、
  `reports/quality-gate/` 不在時は 0 件扱い)、`select-agent-model.sh` の
  tier エスカレーション(lightweight→standard→strong→strong-tier
  recurrence で `BLOCKED terminal-tier-recurrence`、`next_tier` 値を検証)、
  その結果生成される terminal-tier-recurrence blocked-state artifact の
  `contracts/terminal-tier-blocked-state.schema.json` 準拠、
  `check-terminal-tier-resume.sh` が人間承認記録なしで拒否・ありで許可する
  ことを、fixture 上で end-to-end に駆動する(TEST-011、OQ-4 解消: 本スイート
  が同スクリプトの初の直接ドライバ)。`T-001` vs `T-0010` の接頭辞衝突
  fixture で word-boundary マッチが件数を汚染しないことと、その
  word-boundary を除去した一時コピーで fixture が red化することを確認
  (TEST-018、#111/#112 の前例)。parity 拡張(TEST-012)は
  `implementation-report.template.md` を実タスク ID でレンダリングして
  loop-driver fixture に配置し、REAL な `validate-review-context-set.sh` の
  quality:sdd-evaluator identity checks(厳密パス・見出し・full-line
  `- Task ID:`・`## Outputs` セクション走査 — INV-014/INV-015)へ通し、
  `- Task ID:` 行削除で red化・`## Outputs` セクション境界外の decoy 行が
  認可されないことを確認する negative self-check を伴う
  (`tests/template-validator-parity.tests.sh` を拡張・複製せず参照のみ、
  INV-016)。python3 不在(制限 PATH)時は `deterministic-runtime-unavailable`
  を named SKIP として記録(TEST-013、INV-017; pwsh レーンでは
  `check-terminal-tier-resume.ps1` が python3 非依存の純 PowerShell 実装で
  あることを確認し、`select-agent-model.ps1` は
  `-DeterministicRuntimeCommand` 上書きで同等の劣化経路を駆動)。
  **実装時の発見**: `select-agent-model.sh` は実行ビットなしでコミットされて
  いるため(mode 100644)、`bash "$SCRIPT" ...` 経由で駆動(test.yml の既存
  注記と同じ回避策)。詳細は
  `reports/implementation/epic-159-pillar-a/T-004.md`。
- **HITL / WFI-audit 終端動作スイート (Issue #145, epic-159-pillar-a2
  T-001)**: 新スイート `tests/hitl-wfi-terminal.tests.sh` / `.ps1` を追加。
  HITL leg は REAL な
  `plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh`
  のフィクスチャコピーを `CHECK` スタブとモック stdin で駆動し、
  never-reproduces(5 iteration 完走・exit 0・終端文字列)と
  iteration-3-reproduces(即時 exit 1・RED canary)の両方を検証
  (TEST-001/TEST-002、`export -f CHECK` により exit 127 false-green
  経路を防止)。WFI-audit leg は `wfi-audit-cycle/SKILL.md` の一方向規則
  `Audit-Attempt >= 3 -> Audit-Status: Human-Blocked`(precondition 4、
  STEP 4/7)をフィクスチャスコープの WFI-NNN.md コピーへ Audit-Attempt
  0→1→2→3 で適用する参照チェックとして固定し、閾値を書き換える
  negative self-check で red 化することを確認(TEST-003、skill 自体は
  一切起動しない)。新規ファイルが remote issue-tracker CLI を一切
  呼び出さないことと WFI-audit フィクスチャの Category が常に
  `process` であることを構成的に証明し(TEST-004)、実ファイル
  `docs/workflow-improvements/WFI-010.md` / `WFI-011.md` の
  読み取り専用コピーが同じ不変条件を満たすことと、実ファイル自体の
  SHA-256 が実行前後で不変であることを確認(TEST-005)。
  `tests/run-all.sh` / `tests/run-all.ps1` /
  `.github/workflows/test.yml` への自スイート登録と、
  `tests/lib/loop-driver.sh` の `assert_runtime_budget`
  (`LOOP_SUITE_BUDGET_SECONDS=300`)による実行時間予算の自己計測・
  閾値 0 の negative self-check を実施(TEST-006)。CI resilience
  (AC-018): 両フィクスチャルートを直接 mktemp 後に `pwd -P` で正規化
  (INV-030)、0→1→2→3 sweep と 5-iteration drive はリテラル整数の
  カウントループのみで possibly-empty 配列展開なし(INV-029)、jq
  不使用(INV-031 non-use 宣言)。**実装時の発見**: pwsh ツインの
  reproduces-on-iteration-3 ラッパースクリプトで `COUNTER_FILE` を
  `export` せずに `exec bash` していたため、`set -u` 下で
  unbound-variable エラーとなり iteration 1 で誤って red 化する
  バグを実装時に検出・修正(`export COUNTER_FILE=...`)。詳細は
  `reports/implementation/epic-159-pillar-a2-T-001.md`。
- **正準 brownfield seed と check-placeholders brownfield ロック (Issue #146,
  epic-159-pillar-a2 T-002)**: `tests/fixtures/loops/brownfield-seed/` を
  新規追加。ADR-0010 の brownfield 語彙を実体化する、正当な
  `raise NotImplementedError` を持つ抽象基底クラス(`src/base.py`)、
  タスク無関係の既存 `# TODO` マーカー(`src/legacy_util.py`)、マーカーの無い
  実装ファイル(`src/service.py`)、bootstrap-complete な
  `specs/brownfield-seed-demo/tasks.md`、変更ファイルのみを列挙する
  `CHANGED_FILES.txt`(両マーカー保有ファイルを恒久的に除外)からなる3カテゴリ
  すべてを含む不活性フィクスチャ。新スイート
  `tests/check-placeholders-brownfield.tests.sh` / `.ps1` が、実 gate
  `check-placeholders.sh`/`.ps1` を mktemp コピーへ READ-ONLY 駆動し、
  Case A(`CHANGED_FILES.txt` のマーカーフリー部分集合のみ渡す)は exit 0、
  Case B(seed ディレクトリ全体を渡す)は exit 1 かつ両マーカー
  (base.py の NotImplementedError、legacy_util.py の TODO)を報告し、
  マーカーフリーな2ファイルは決して所見に現れないことをロック(TEST-008/
  TEST-009)。`tests/loop-consistency.tests.sh` / `.ps1` の既存 TEST-008 に
  brownfield-profile leg を追加し、`loop_fixture_init brownfield` が
  正準 seed から `$LOOP_FIXTURE_ROOT` 配下へ verbatim にコピーされることを
  確認したうえで spec-review round 1 を駆動し、観測終了状態が greenfield
  leg と同じ inventory `terminal`(PASS)に一致することを検証
  (TEST-008.15〜18、AC-007/AC-010)。pwsh レーンは既存の greenfield spec leg
  と同じ `spec-review-precheck.ps1` 欠落理由で round 駆動部分のみ named
  SKIP に degrade(fixture 初期化と verbatim コピー検証は両レーンとも green)。
  `tests/run-all.sh` / `tests/run-all.ps1` /
  `.github/workflows/test.yml` へ自スイート登録。CI resilience
  (AC-018): mktemp 作業ディレクトリを `pwd -P` で正規化(INV-030)、
  jq 不使用(INV-031 non-use 宣言 — check-placeholders-brownfield
  スイート自体は exit code とゲートのプレーンテキスト所見のみを検査し、
  `loop_fixture_init` 経由の AC-007 検証は既に jq に依存する
  `tests/loop-consistency.tests.sh`/`.ps1` 側に配置して新規 jq 依存を
  導入しない設計とした)、brownfield leg の validator 駆動は既存の
  `loop_validator_capability_probe`/`loop_validator_skip` ゲートを
  そのまま継承(INV-032)。詳細は
  `reports/implementation/epic-159-pillar-a2-T-002.md`。
- **domain-review-precheck.ps1 の full-parity port と guard-ps1-ascii
  TARGETS 一般化 (Issue #147, epic-159-pillar-a2 T-003)**:
  `plugins/sdd-domain/scripts/domain-review-precheck.ps1` を新規追加。
  未編集の `domain-review-precheck.sh` を 1 対 1 移植し、attempt/round
  境界・round-1 での `--edit-summary` 拒否・rounds 2-3 の非空
  `--edit-summary` 要求・`--reset` 前提条件・domain/ 正準アーティファクト
  (7 ファイル + aggregates/*.md)の存在/symlink 検査・AC-014
  post-approval drift 検出(sdd-domain 機能自身の AC-014、
  `specs/sdd-domain/requirements.md:120`)を全て実装。
  `tests/lib/loop-driver.ps1` が splat 経由でこのスクリプトを渡す
  `<attempt> <round> [--edit-summary=<text>]` の positional 呼び出し規約
  (`--edit-summary=` プレフィックス込みの生トークンが `-EditSummary` の
  3 番目の位置引数として届く)と、直接の named パラメータ呼び出し
  (`-Attempt`/`-Round`/`-EditSummary`/`-Reset`)の両方をサポート。
  `tests/guard-ps1-ascii.tests.sh` を単一 `TARGET` から `TARGETS` 配列へ
  一般化し(`GUARD_PS1` の保護 hook-guard 単一ターゲット上書き semantics は
  不変更)、CR バイトスキャンを追加した上でこのファイルを登録
  (TEST-012/AC-012)。reject-path 検証(TEST-011): 範囲外 Round と
  round-1 での非空 `--edit-summary` を、named 呼び出しと
  loop-driver 相当の positional array-splat 呼び出しの両方で、
  `.sh` 原本と同一の exit code(1)・エラーメッセージ
  (`ERROR: domain-review-precheck: ...`)で拒否することを確認。
  **実装時の発見(Specification Difference)**: self-healing 確認
  (TEST-013)で `pwsh tests/loop-consistency.tests.ps1` の domain leg named
  SKIP は解消した(4→3、#147 を引く SKIP はゼロ)が、round 駆動自体は
  `tests/lib/loop-driver.ps1` 側の未編集・既存の
  `Publish-LoopDomainRoundBContract` 関数に潜在していた PowerShell の
  配列展開バグ(`Invoke-LoopJq -r ".allowed_input_manifest"` が複数行
  JSON を返し、それを別の `& jq ... --argjson` へ再埋め込みする際に
  PowerShell が配列要素を個別の外部プロセス引数として展開してしまい、jq
  が不完全な JSON を受け取る)により FAIL する。domain-review-precheck.sh
  が今まで存在しなかったため domain leg は一度も実行されたことがなく、
  spec/impl/task の contract 構築(manifest をリテラルに jq フィルタ内で
  組み立てる方式)には存在しないパターン固有の欠陥と判明。本タスクの
  制約により `tests/lib/loop-driver.ps1` は無編集のまま、この発見を
  `specs/epic-159-pillar-a2/verification/T-003/green-ps1.log` に全証跡と
  共に記録し、修正は将来の別タスクへ委ねる。詳細は
  `reports/implementation/epic-159-pillar-a2-T-003.md`。
- **spec-review-precheck.ps1 full-parity port と ps1 hygiene ターゲット完了
  (Issue #174, epic-159-pillar-a2 T-004)**:
  `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` を新規追加。
  未編集の `spec-review-precheck.sh` を 1 対 1 移植し、feature-slug 検証・
  attempt/round 境界・round-1 での `--edit-summary` 拒否・rounds 2-3 の
  非空 `--edit-summary` 要求・`--reset` 前提条件に加え、他の precheck
  ポートには存在しない spec 固有の自ステージ own-round 再検証ロジック
  (`.sh` 原本の `validate_contract`/`validate_reviewer_output`: 前ラウンドの
  `spec-review-contract.json`・`precheck-result.json`・
  `integrated-summary.json`・`reviewer-a.json`/`reviewer-b.json`・
  `integrated-verdict.json` を横断してスキーマ・ハッシュ・
  reviewer 別 allowed_input_manifest・finding_counts からの
  verdict/warningCount 再計算までを再検証)を全て実装。round > 1 と
  `--reset` の双方がこの再検証を経由する。`review-contract-validate.ps1`
  への共通ポータブル基盤呼び出しと、`--reset` 時の
  `Spec-Review-Status: Passed` → `Pending` への実ファイル書き戻しも移植。
  `tests/guard-ps1-ascii.tests.sh` の `TARGETS` 配列(T-003 が一般化済み)に
  このファイルを 1 行追加(TEST-015/AC-015、9 passed 0 failed)。
  reject-path 検証(TEST-014): 範囲外 Round・round-1 での非空
  `--edit-summary`・`--reset` 前提条件違反(attempt N+1 round 1 以外での
  `--reset`、および `--reset` なしの新 attempt)の 3 系統を、named 呼び出しと
  loop-driver 相当の positional array-splat 呼び出しの両方で、`.sh` 原本と
  同一の exit code(1)・エラーメッセージ(`ERROR: spec-review-precheck: ...`)
  で拒否することを確認。self-healing 確認(TEST-016): `pwsh
  tests/loop-driver.tests.ps1` TEST-006(15 passed/1 SKIP → 22 passed/0
  SKIP)と `pwsh tests/loop-consistency.tests.ps1` TEST-008 の spec/impl/task
  レグおよび brownfield-profile レグ・TEST-009.1(14 passed/3 SKIP → 27
  passed/0 SKIP)が、いずれも #174 を引く named SKIP から実行・green へ
  完全に転換(残存 FAIL・SKIP ゼロ)。impl/task レグは
  `task-review-precheck.ps1`/`impl-review-precheck.ps1` 自身の無編集のまま、
  実在する spec-review PASS チェーンへの推移的依存だけで復旧することを確認
  (両スイートとも無編集)。**実装時の発見(PowerShell パーサ差異、本タスク内で
  修正済み)**: `Test-ValidateContract` の own-round 再検証実装時、PowerShell
  7 の `ConvertFrom-Json` が ISO-8601 形式の JSON 文字列値(例:
  `integrated-summary.json` の `generated_at`)を `[DateTime]` へ自動変換して
  しまい、`jq` の `type == "string"` 相当チェックが誤って red 化する差異を
  発見。`Test-IsStringLike`(`[string]` または `[DateTime]` のいずれかを
  許容)ヘルパーを追加してこの 1 箇所のみに適用し解消(他フィールドは
  日付として解釈され得ない値のため影響なし)。ホスト側修正 9ca31bb
  (`tests/lib/loop-driver.ps1` の `--argjson` manifest 複数行展開バグ、
  T-003 発見分の全ステージ修正)により、round 駆動自体は spec/impl/task/
  domain 全レグで健全であることも確認。詳細は
  `reports/implementation/epic-159-pillar-a2-T-004.md`。
- **能力リフレッシュ手順とマトリクス確認列の追加 (Issue #156, epic-159-pillar-d
  T-001)**: `docs/contributor/workflow-detail.md` の WFI (Workflow
  Improvement) ライフサイクル節に、既存の Draft ステップと人間承認ステップの
  間へ「能力リフレッシュチェック」ステップを新設。`Mechanism: model-routing`
  の WFI を Draft する前に確認する正典ソース一覧(Anthropic 公式
  docs/blog、OpenAI developers docs/blog、Claude Code / Codex CLI /
  Copilot CLI の各リリースノート)、4つのチェック項目(モデル ID の有効性 /
  新モデル・新機能の有無 / effort・ツール対応の変化 / v2 レジストリとの乖離)、
  週次自動起票フロー(`.github/workflows/model-freshness-check.yml`、
  epic-159-pillar-d T-003)への接続と手動起票フォールバックを明記し、手動
  起票する issue のタイトルには自動起票と重複判定を揃えるための安定タイトル
  マーカー `[model-freshness-divergence]` を必ず含めることを規定。
  `docs/agent-capability-matrix.md` の Provider Tier Mapping 表には
  「最終確認日」「参照ソース」の末尾2列を全6行に追加(既存セルは無変更、
  `未確認` で初期化し次回リフレッシュ実施時に更新される想定)。
  `tests/agent-model-routing.tests.sh`(無編集)を再実行し green を確認
  (`assert_literal` の固定文字列一致は各行の追記前プレフィックスに対する
  部分一致であるため、末尾列の追加後も成立)。ホスト中立(Claude Code /
  Codex どちらにも偏らない単一プローズブロック)。詳細は
  `reports/implementation/epic-159-pillar-d/T-001.md`。
- **v2 レジストリへの現行世代モデルデータ投入 (Issue #158, epic-159-pillar-d
  T-002)**: Pillar C の C1 (#149) が `main` へ着地させた
  `contracts/agent-model-capabilities.v2.json` へ、OpenAI の現行世代
  (`gpt-5.4`/`5.5`/`5.6` 系)を表す新規3エントリを tier ごとに追加
  (`openai/gpt-5.4-codex-mini`/lightweight、`openai/gpt-5.5-codex`/
  standard、`openai/gpt-5.6-codex`/strong)、各エントリで Claude Code /
  Codex 両ホストの `effort_control` を充足。既存7エントリはバイト単位で
  無変更 — `tests/agent-capabilities-v2.tests.sh` の名前キー v1⇔v2
  パリティロックと `tests/agent-model-routing.tests.sh` の実レジストリ
  直読アサーション(`:415-421`、TEST-034 `:868-884`)が、この7エントリの
  改名・削除を red 化することをソース調査で直接確認したため
  (両スイートとも「無編集のまま再実行して green」= AC-014 の対象)、
  リネームではなく新規追加という手段を選択。Anthropic 側の3エイリアス
  (`anthropic/haiku`/`sonnet`/`opus`)は無改名 — issue #158 の「Claude 5
  系のエイリアス方針」自体がバージョン番号を含まない命名を意味するため、
  既存名がそのまま現行世代データとして正しい。確認日
  (2026-07-19)と参照ソースは新規サイドカー文書
  `contracts/agent-model-capabilities.v2.md` に記録(ネットワーク取得は
  実施せず、T-001 が確立した正典ソース一覧と issue #158 自身の確定済み
  ファミリー記述を根拠とする)。v1 レジストリは SHA-256 比較で編集前後
  バイト同一を証明(AC-013)。`tests/agent-capabilities-v2.tests.sh`/
  `.ps1`(Pillar C のパリティスイート)と
  `tests/agent-model-routing.tests.sh`/`.ps1` を無編集のまま再実行し
  green を確認(AC-014)。`docs/agent-capability-matrix.md` の
  最終確認日列は本タスクでは記入せず `未確認` のまま維持(同表の
  モデルファミリー値は `tests/agent-model-routing.tests.sh` の
  `assert_literal` で固定されたルーティング用ピン留め値であり、本タスクが
  更新する v2 レジストリの現行世代カタログとは別物であるため — REQ-005 の
  「genuine reference がある場合のみ」の条件が今回は不成立と判断)。
  受け入れ先行(acceptance-first)で RED
  (`specs/epic-159-pillar-d/verification/T-002/acceptance-first-red.md` +
  `red-baseline-*.log`: 確認記録が存在せず OpenAI 側が2世代遅れという
  事前状態を記録)→ GREEN
  (`specs/epic-159-pillar-d/verification/T-002/green-*.log`)の順で実装、
  詳細は `reports/implementation/epic-159-pillar-d/T-002.md` を参照。
- **週次 model-freshness-check 自動化の追加 (Issue #157, epic-159-pillar-d
  T-003)**: 新規 `.github/workflows/model-freshness-check.yml`(週次
  `cron: "0 3 * * 1"` + `workflow_dispatch`、`ubuntu-latest`、
  `permissions: contents: read` / `issues: write` のみ、
  `pull-requests: write` は持たない)が新規
  `.github/scripts/check-model-freshness.sh` を実行し、Anthropic/OpenAI
  公式ソースを best-effort 取得して
  `contracts/agent-model-capabilities.v2.json` の `models[].name` との
  乖離を検出する。取得失敗時(いずれかのベンダーで発生)は
  `[model-freshness-fetch-unavailable]` マーカー付き専用 issue へ
  「取得不能」コメントを残して exit 0(fail-soft, INV-009 — 外部ソース
  障害でこの CI ジョブ自体を失敗させない。非対称失敗時も残存側の部分
  データから乖離計算しない)。乖離検出時は charset allowlist
  `[A-Za-z0-9.-]` 検証済みモデル ID トークンのみを本文に埋め込んだ
  `[model-freshness-divergence]` マーカー付き issue を起票
  (`workflow-improvement` ラベル、重複排除つき — このマーカー文字列は
  T-001(#156)の手動起票チェックリストと同一のものを使用)。
  `check-model-freshness.sh` は `contracts/` への書き込み経路を一切持たず
  (Security Boundaries B2)、`.ps1` twin は持たない(記録済み non-twin
  設計判断、`self-improvement-pr-guard.sh` の既存 non-twin 前例に倣う、
  AC-016)。新規スイート `tests/model-freshness-check.tests.sh` / `.ps1`
  が、fetch 失敗3シナリオ(両方/Anthropic のみ/OpenAI のみ)・乖離検出+
  重複排除・no-diff ゼロ副作用・adversarial issue-body allowlist
  (markdown injection / instruction-like text / script fragments が
  issue 本文に verbatim で漏れないことの陽性/陰性ペア証明)を、実スクリプト
  + PATH 上書き `gh` スタブ + 注入可能フィクスチャで直接ロック(実ネット
  ワーク・実 `gh` 呼び出しは一切なし)。`.ps1` twin は
  `check-model-freshness.sh` 自体をシェルアウトせず、同一アルゴリズムを
  ネイティブ PowerShell として独立再実装した上で同じフィクスチャ群を駆動
  (`tests/release-loop-gate.tests.ps1` の full-parity-port 踏襲)。
  `tests/run-all.sh` / `.ps1` へ自スイートを直接登録
  (grep 自己検査つき、TEST-009/TEST-016)。R-10 保護ファイルである
  `.github/workflows/test.yml` は直接書き込まず、本スイートの新規CIステップ
  (bash/pwsh 両レーン)を反映した完全な補正版を
  `specs/epic-159-pillar-d/human-copy/.github/workflows/test.yml` +
  `MANIFEST.sha256` としてステージし、人間の適用を待つ(適用前後で
  ライブファイルの SHA-256 は不変)— 人間適用コミットが着地するまで
  `tests/model-freshness-check.tests.sh`/`.ps1` 自身の TEST-009
  ライブファイル自己検査は意図的に red のまま(AC-011 の fail-closed
  設計、stagedによる代替なし)。受け入れ先行の TDD で RED
  (`specs/epic-159-pillar-d/verification/T-003/red-sh.log` /
  `red-ps1.log`: スクリプト・ワークフロー・登録のいずれも未着地の状態で
  スイート自身が意味のある失敗をすることを確認)→ GREEN
  (`specs/epic-159-pillar-d/verification/T-003/green-sh.log` /
  `green-ps1.log`: TEST-009 のライブファイル半分を除く全アサーションが
  green)の順で実装、詳細は
  `reports/implementation/epic-159-pillar-d/T-003.md` を参照。
- **`--effort-policy` の既定値を `matrix` に変更 (Issue #155,
  epic-159-pillar-c T-007, Phase 2 / REQ-007)**: `select-agent-model.sh` /
  `.ps1` の `--effort-policy` 既定値を `welded` から `matrix` へ1行変更
  (`select-agent-model.sh:18`、`select-agent-model.ps1:16` の
  `ValidateSet` 既定値)。フラグを付けない全呼び出しが
  `risk_effort_matrix[risk]` ベースのリスク連動 effort 選択(escalation
  bump・`supported_efforts` へのクランプを含む)に切り替わる。`welded`
  (effort を tier に溶接した Phase 1 の既定挙動)は
  `--effort-policy welded` を明示すれば無期限にフルサポートされ続ける
  (非推奨化タイマーなし、OQ-004)。T-003 が `role_defaults` を現行値から
  事前シードしていたため、フリップ後最初の本番 `role_defaults` レンダーは
  ゼロ差分(`render-agent-frontmatter.sh --check`: 10 targets, 0 drift、
  AC-042)。`USERGUIDE.md` / `docs/agent-capability-matrix.md` を matrix
  既定の説明で更新。**前提ゲート(AC-045)**: `git merge-base
  --is-ancestor` で T-001..T-006 の Phase 1 マージコミット
  (825d6c6、PR #185)と A3 コミット(2d8c6a5、#143)の双方が実装時点の
  HEAD の祖先であることを再検証済み
  (`specs/epic-159-pillar-c/verification/T-007/prereq-gate.log`)。TDD で
  RED(`specs/epic-159-pillar-c/verification/T-007/red-sh.log`: フリップ前は
  既定 `welded` のまま解決し `risk_effort_matrix` 値と食い違う)→ GREEN
  (`specs/epic-159-pillar-c/verification/T-007/green-sh.log`)の順で実装。
  **TEST-044(実 Codex ホストでの smoke 実行、AC-044)**: 本実装セッションでは
  意図的に見送った — 正直な理由(実 `codex` CLI はこのリポジトリに対して
  自律的にファイル書き込み・コマンド実行が可能な agentic ツールであり、
  無人の自動スイート実行から無条件で起動するのは安全でないと判断)は
  `reports/implementation/epic-159-pillar-c/T-007.md` の Unresolved Items
  を参照。スイート内の TEST-044 は SKIP(named-reason、フィクション化なし、
  `SDD_ALLOW_REAL_CODEX_SMOKE=1` を明示した運用者のみ実行可能)。この
  タスクは T-001..T-006 とは別 PR・別リリースとして着地し、
  `scripts/bump-version.sh` の実行は本実装セッションの範囲外(呼び出し元が
  別途実施、AC-046)。詳細は
  `reports/implementation/epic-159-pillar-c/T-007.md` を参照。

### セキュリティ修正

- **sdd-hook-guard.ps1 のキルスイッチが入れ子 cwd から AGENT_STOP を検出できない (週次セルフ改善監査)**:
  `Test-KillSwitch` は `CLAUDE_PROJECT_DIR` 未設定時に `@(".", ".")` 相当のカレント
  ディレクトリしか見ておらず、`.py`/`.js`/`kill-switch.ps1` が実装する「git ルートまで
  最大21階層親を辿って `AGENT_STOP` を探す」(C-08) ロジックが欠落していた。ネストした
  作業ディレクトリから実行された場合、プロジェクトルートに置いた `AGENT_STOP` が
  無視され、ps1 ランタイムだけツール使用を止められない片側リグレッションになって
  いた(py/js は正しく deny、ps1 のみ allow で分岐することを再現テストで確認)。
  `kill-switch.ps1` と同じ親ディレクトリ走査を `Test-KillSwitch` に移植。
  `tests/guard-r10-port.tests.ps1` に .ps1/.py/.js 三者パリティの回帰テストを追加。
- **prepare-panelist-input.sh の HMAC 検証における任意コード実行 (Issue #108)**:
  SDD_SUDO トークンのフィールド(issuer / nonce / repo / issued-epoch /
  expires-epoch / sig / 署名鍵)を未クオートの `python3 - <<PYEOF` ヒアドキュメントへ
  直接展開していたため、`"""` を含むフィールドで HMAC 比較の前に任意の Python が
  実行できた。クオート済みヒアドキュメント(`<<'PYEOF'`)＋ `os.environ` 経由の
  受け渡しに変更し、データとコードを分離。実 HMAC 正常系・改竄検知・敵対的
  フィールド無害化(コード実行なし)の回帰テストを追加し、これまで CI 未接続だった
  `tests/prepare-panelist.tests.sh` を run-all.sh と CI の Bash/PowerShell ステップに接続。
  .ps1 ツインは .NET HMAC を直接使用しており本脆弱性の影響なし。
- **リリースパスのループスイート・ゲート化 (Issue #148, epic-159-pillar-b
  T-001 + T-002)**: `scripts/bump-version.sh` に、既存の CHANGELOG
  見出しチェックの直後・全ミューテーションステップ(プラグインマニフェスト・
  README・validate-repository.ps1 等の書き換え)より前の位置で、
  `tests/loop-consistency.tests.sh` と `tests/loop-inventory.tests.sh` を
  実行するループゲート前提条件を追加。いずれかのスイートが非 0 終了した場合は
  fail-closed(exit 1、リリース面を一切変更しない)で停止し、環境変数・CLI
  フラグによるバイパスは存在しない。新スイート `tests/bump-version-gate.tests.sh`
  / `.ps1` が、tar-copy + ローカル `git init` によるフィクスチャリポジトリコピー
  上で実 `bump-version.sh` を読み取り専用で駆動し、green path(両スイートを
  トリビアルに合格するスタブへ差し替え)、独立した2つの red path(各スイートを
  個別に失敗するスタブへ差し替え、`git status --porcelain` がゼロ差分であること
  を確認 — 両スイートが独立にゲートすることの証明)、実スクリプトソースへの
  no-bypass grep 自己チェック、ゲート呼び出し行が最初のミューテーション行より
  前にあることを検証する行番号順序アサーション、CI-resilience(`pwd -P` 正規化・
  `set -u` 下での空配列非展開・jq 非使用・実 validator 非使用)と自己登録の
  適合性をロック。`tests/run-all.sh` / `.ps1` / `.github/workflows/test.yml` に
  登録。`scripts/bump-version.ps1` ツインは意図的に存在せず(release-operator
  CLI であり、テストスイートの `.sh`/`.ps1` ツイン義務の対象外という設計判断)、
  Windows ホストおよび CI は `.github/workflows/release.yml` 側の必須
  `loop-gate` ジョブ(Issue #148, epic-159-pillar-b T-002)が同等の保証を提供する
  — 詳細は `docs/contributor/release-runbook.md`。実装時に、本スイート自身の
  green path が BSD/macOS 標準 `sed`(GNU 専用構文の `sed -i "<script>" <file>`
  に非対応)では `scripts/bump-version.sh` の既存(本タスクでは不変更)
  ミューテーションセクションで失敗するという、無関係な既存の互換性ギャップを
  発見。本タスクの範囲外(該当セクションは design.md により不変更)として記録し、
  当該ホストでは capability probe による named SKIP に度数低下する
  (`tests/bump-version-gate.tests.sh`/`.ps1` TEST-001 のみ、影響)。
  CI 脚(T-002)として `.github/workflows/release.yml` に新規 `loop-gate`
  ジョブ(`ubuntu-latest`)を追加し、`tests/loop-consistency.tests.sh` と
  `tests/loop-inventory.tests.sh` を実行。既存のビルドジョブ(`release:`)に
  `needs: loop-gate` を追加し、tarball/SBOM/checksum/sigstore attestation/
  アップロードチェーンが両スイート合格なしには一切実行されないようにした。
  `loop-gate` ジョブには明示的に `permissions: contents: read` を指定し、
  ワークフロー全体の `contents: write` / `id-token: write` /
  `attestations: write`(既存ビルドジョブのスコープ)を暗黙に継承しないよう
  昇格権限を要求しない設計とした。新スイート `tests/release-loop-gate.tests.sh`
  / `.ps1` が、実 `release.yml` に対するテキストマーカー構造チェック
  (`tests/workflow-state-ci-integration.tests.sh` の技法を踏襲)をロック:
  `loop-gate:` ジョブスライスへの両スイート呼び出し文字列の存在、`release:`
  ジョブスライスへの `needs: loop-gate` の存在と両ジョブスライスからの
  `continue-on-error: true` / `if: always()` / `if: success() || failure()`
  エスケープハッチ不在のネガティブスキャン、`needs:` 行をテキストで除去した
  mktemp フィクスチャコピーに対する同一チェック関数の再適用によるネガティブ
  ブランチ・カナリア(このアサーションが空虚でないことの証明)、
  `runs-on: ubuntu-latest` 限定・`strategy:`/`matrix:` キー不在・自己登録の
  適合性をロック。`tests/run-all.sh` / `.ps1` / `.github/workflows/test.yml`
  に登録。ジョブキー検索は `jobs:` トップレベルキーより後の行に限定
  (本ワークフローの `on: release: types: [published]` トリガーセクション自身が
  持つ2スペースインデントの `release:` キーをジョブ境界と誤認識しないため)。
  実装時に、本スイート自身の green path 構築中、BSD/macOS 標準 `mktemp` が
  `XXXXXX` の直後にリテラルなサフィックスを持つテンプレートを乱数化せず
  2回目以降の実行が "File exists" で失敗するという、無関係な既存の互換性
  ギャップを発見。`mktemp -d` でディレクトリを作成しその中に固定名のスクリプト
  ファイルを置く方式に変更して修正(このスイート自身の実装のみに影響、
  release.yml やその他の既存スクリプトは不変更)。

### 修正

- **self-improvement workflow が GitHub App トークン交換の OIDC で失敗する問題 (Issue #48)**:
  `CLAUDE_CODE_OAUTH_TOKEN` secret 登録後も、ピン留めした claude-code-action
  (v1.0.165) が `github_token` 入力未指定時に GitHub App トークン取得のため
  OIDC 交換 (`core.getIDToken()`) を実行し、`id-token: write` 不在(AC-010 で
  意図的に除外)のため "Could not fetch an OIDC token" で失敗していた
  (run 29262507406 で実証)。`with: github_token: secrets.GITHUB_TOKEN` を明示して
  App トークン交換をスキップさせ、セッション内 gh CLI と同一の最小権限 workflow
  トークンに統一。permissions は不変(TEST-010 の id-token 不在 assert も維持)。
- **impl-review が round > 1 で構造的に不通過だった問題 (Issue #143)**:
  impl-review-precheck は round > 1 で impl-reviewer-a のマニフェストに前ラウンドの
  `integrated-summary.json` を要求するが、validate-review-context-set は同ファイルを
  reviewer-b にのみ許可していたため、reviewer-a の必須入力が role-unlisted として
  拒否され impl-review が round 1 以降に進めなかった。両ツイン(.sh/.ps1)で
  impl-reviewer-a にも許可(precheck 契約が前ラウンドに固定するため多層防御は維持)。
  review-agent-isolation に回帰テストを追加。
- **check-task-state.ps1 のタスク ID 部分一致 (Issue #111)**: `Select-String` の
  部分一致で `T-001` が `T-0010` のレポートにも一致していたのを単語境界一致に修正
  (`.sh` ツインは `grep -rlw` で既に正しかった)。
- **レビュー前チェックの jq 欠如時フェイルファスト (Issue #120)**:
  impl / task-review-precheck.sh に `command -v jq` の存在確認を追加し、パイプライン
  途中の不明瞭な失敗ではなく明確なエラーで停止(spec-review-precheck.sh /
  review-contract-validate.sh には既存)。
- **check-placeholders の grep 実エラー握り潰し (Issue #127)**: grep の終了コードを
  区別し(0=一致 / 1=不一致 / >=2=致命的エラー)、品質ゲートでのフェイルオープンを
  解消。.sh / .ps1 双方を fail-closed に統一。
- **quality-gate cycle-limit がタスク ID を全フィーチャー横断でカウントしていた問題
  (Issue #167 / RT-20260712-001)**: `check-quality-gate-cycle-limit.{sh,ps1}` は
  タスク ID(`T-NNN`)が `reports/quality-gate/` 配下のどのフィーチャーのレポートに
  現れても単語境界一致でカウントしていたため、3 フィーチャー以上が同じ裸のタスク
  ID を共有すると、対象フィーチャー自身のレポート件数が 0 でも偽の
  `Escalate-Human` を返していた(epic-136-phase1-guards の T-003〜T-006 で実測)。
  CLI 契約を `<task-id> <feature> [reports-dir]` に変更し(`feature` は必須第2
  位置引数、文法 `^[a-z0-9][a-z0-9-]*$`、欠落・不正は使用法エラー exit 2)、
  カウント述語を「単語境界一致のタスク ID」AND「同一ファイル内のアンカー付き
  `^Feature:[[:space:]]*<feature>[[:space:]]*$` 行」の二条件に変更
  (`emit-run-record.sh:123,125` が既に確立した二述語形状を再利用)。
  RT-20260712-001 の実測シナリオ(他フィーチャー3件+対象フィーチャー0/1/2件)を
  未修正スクリプトに対して先に RED 記録してから修正後に GREEN 確認する
  受け入れ先行(acceptance-first)手順で実装。本スイートの新規 CI 登録ステップ
  (bash 単一レーン、combined-suite 慣習に準拠)を反映した R-10 保護ファイル
  `.github/workflows/test.yml` の完全な補正版を
  `specs/quality-loop-fixes/human-copy/.github/workflows/test.yml` としてステージ
  (人間の適用待ち、適用前後でライブファイルの SHA-256 は不変)。
  `plugins/sdd-ship/skills/ship/SKILL.md` Step 4 のプロセ・呼び出し例2箇所も
  同様に補正版を用意したが、同ファイルの human-copy ステージング書き込みが
  R-10 ガードの suffix 判定(`specs/*/human-copy/` 配下の待避パスにも
  ライブ保護パスと同一の exact-suffix match が誤って適用される既知のギャップ)
  により本セッションのツールから完了できなかったため、完成済みの補正内容・
  SHA-256・ライブ差分を実装レポートに記録し、人間が直接適用する運びとした
  (AC-006 は本レポートで "blocked — 人間ステージング待ち" と正直に記録)。
  CLI 契約変更に伴い、旧 2 引数契約でスクリプトを直接駆動していた
  `tests/loop-escalation.tests.sh` / `.ps1`(T-001 の計画ファイル外だが、
  この変更がなければ実際に壊れる既存 CI 登録済みスイート)にも feature 引数を
  追加し、両レーンとも無回帰(green)を確認。詳細は
  `reports/implementation/quality-loop-fixes/T-001.md` を参照。
- **emit-run-record の gate_reports.blocked が VERDICT 行以外の本文中の
  "BLOCKED" 文字列も誤カウントしていた問題 (Issue #176 / WFI-010)**:
  `emit-run-record.{sh,ps1}` の `gate_blocked` 集計はレポート全文に対する
  無アンカーの `grep -q 'BLOCKED'` / `-match "BLOCKED"` スキャンだったため、
  レポート自身の `VERDICT:` 行が `PASS` でも本文中に「BLOCKED」という語が
  出現するだけで誤カウントされていた(実例:
  `reports/quality-gate/T-008.md`、WFI-010 が記録した epic-159-pillar-a の
  実測値 baseline=1・真値=0)。レポート自身のアンカー付き
  `^VERDICT:[[:space:]]*BLOCKED[[:space:]]*$` /
  `(?m)^VERDICT:\s*BLOCKED\s*$` 行のみを読む方式に変更(`VERDICT:` 行が
  存在しないレポートは fail-open でカウントされない、OQ-4)。
  `emit-run-record.ps1` にはファイル末尾の明示的な `exit 0` も追加
  (従来は暗黙の終了コードのみ)。`tests/emit-run-record-feature-scope.tests.sh`
  / `.ps1` に、同一フィーチャー内で `VERDICT: PASS` かつ本文に "BLOCKED" を
  含むレポートを含む新規フィクスチャ(feature `feat-t002`)を追加し、
  未修正スクリプトに対して先に RED 記録(誤って2件カウント)してから修正後に
  GREEN(正しく1件カウント)を確認する受け入れ先行(acceptance-first)手順で
  実装、既存の feat-a/feat-b フィクスチャとそのアサーションは無改変
  (INV-010 のカバレッジギャップを解消)。WFI-010 の Status を
  Approved → Applied に更新。詳細は
  `reports/implementation/quality-loop-fixes/T-002.md` を参照。
- **prepare-panelist-input のバンドル収集が単一階層のみで、実装レポートの
  宣言済み成果物との整合性検証もなかった問題 (Issue #166 / WFI-009)**:
  `prepare-panelist-input.{sh,ps1}` の `--input` 収集ロジックは単一階層の
  glob(`for f in "$input_path"/*` / 非 `-Recurse` の `Get-ChildItem`)で、
  サブディレクトリのファイルを収集しなかった。さらに収集後、実装レポートの
  `## Outputs` テーブルが宣言する成果物パス・SHA-256 と実際に収集した
  バンドルとの整合性を一切検証していなかった
  (epic-136-phase1-guards レトロスペクティブが記録した2件の
  evidence-completeness による盲検パネル NEEDS_WORK の根本原因、WFI-009)。
  `find "$input_path" -type f | sort` ベースの再帰走査(`.ps1` は
  `Get-ChildItem -Recurse -File` のネイティブ実装、ソート済みで決定的)に
  置き換え、コンセントゲート直後・サニタイズ/ダイジェスト計算前に宣言済み
  成果物の整合性検証を追加: `validate-review-context-set.sh:63-74` の
  `## Outputs` テーブルパーサ形状を逆方向に再利用し、各宣言パスをバンドル
  自身の `--input` ルート配下に収まるかコンテインメント検証してから
  (root 外に解決されるパスは読み取らず即座にギャップとして扱う、
  Security Boundary B1)存在・SHA-256 一致を確認、ギャップが1件でも
  あればサニタイズ/ダイジェスト計算に到達する前に非ゼロ終了しギャップ
  一覧を stderr に出力・ダイジェスト行は一切印字しない(構造的性質であり
  条件分岐によるガードではない)。実装レポートのパスは新規フラグを追加
  せず(Breaking API: no、CLI フラグ不変)、`--task`/`--feature`/
  `--project-root` から `reports/implementation/<feature>/<task_id>.md`
  という既存の規約(`validate-review-context-set.sh:267-282` が同一規約を
  使用)で導出。`cross-model-verify/SKILL.md` の Step 1 と Step 2 の間に
  "Step 1.5 — Pre-Panel Readiness" を新設し、仕様が列挙可能なカバレッジ
  要件を明示するタスクについてのみ、機械検証可能なカバレッジマニフェスト
  の全要素がマッピングされていることをパネリスト起動前に検証、未マッピング
  要素があれば起動前に停止する(通常タスクは no-op で従来どおり Step 2 に
  進む)。`tests/prepare-panelist.tests.{sh,ps1}` に再帰・整合性チェックの
  陽性/欠落/ハッシュ不一致/サブディレクトリ/パストラバーサル
  (センチネルファイル使用)の6ケースを追加し、未修正コレクタに対して
  先に RED 記録してから修正後に GREEN を確認する TDD 手順で実装
  (高リスクタスクの必須要件)。BL-007(コンセントゲート)・BL-008
  (サニタイズ)・BL-009(`--effort` 出力契約)は無改変で green を維持。
  WFI-009 の Status を Approved → Applied に更新。詳細は
  `reports/implementation/quality-loop-fixes/T-003.md` を参照。
- **validate-review-context-set.sh が Windows Git Bash (jq.exe) 上で正当な
  identity ledger を拒否していた問題 (Issue #179)**:
  `validate-review-context-set.sh` のレコードハッシュ再計算経路にある全
  `jq -r` 消費箇所(マニフェスト単一値読み取り9箇所+条件付き `task_id`
  読み取り1箇所、`@tsv` 形式の ledger バッチ読み取り1箇所、
  `allowed_input_manifest` 読み取り2箇所、計12箇所)が jq 出力の末尾 `\r`
  を除去していなかったため、Windows の `jq.exe` が emit する CRLF 改行が
  `while IFS=$'\t' read` ループの最終フィールド(`record_sha256`)に混入し、
  正当な genesis ledger に対してもバイト完全一致比較が失敗し
  `REVIEW_CONTEXT_IDENTITY: canonical identity ledger record hash is
  invalid` を誤って返していた(`tests/lib/loop-driver.sh:460-481` の
  `loop_validator_capability_probe` が `degraded` として長期間吸収)。
  コミット `c756a5a` で確立済みの `tr -d '\r'`(`uname`/OS 分岐なし)を
  該当12箇所すべてに機械的に追加。`validate-review-context-set.ps1` は
  `ConvertFrom-Json` ベースで本来この欠陥の対象外のため無改変(INV-019)。
  `tests/review-contract-foundation.tests.sh` に、対象の jq プログラム文字列
  にのみ末尾 `\r` を付与する PATH 差し込み型 jq シム(1箇所ずつ分離適用、
  全体一括だと stage/role の CONTRACT チェックが先に失敗してしまうため)
  を用いたフィクスチャスイートを追加し、未修正スクリプトに対して先に RED
  記録(genesis ledger が `canonical identity ledger record hash is
  invalid` で拒否される実測)してから修正後に GREEN(`REVIEW_CONTEXT_OK`)
  を確認する TDD 手順(高リスクタスクの必須要件)で実装。BL-010 の
  真正な改ざんケース(sequence 不正・previous_record_sha256 不正・
  シンボリックリンクトラバーサル・run/session ID 重複)は shim 適用有無の
  両レーンで修正後も fail-closed のままであることを再確認し、本タスクの
  変更が改ざん検知を弱めていないことを証明(security-spec.md Security
  Boundary B2)。フィクスチャは mktemp スコープの ledger コピーのみを使用し
  実 `reports/review-context/identity-ledger.json` には一切書き込まない
  (実施前後で当該ファイルの SHA-256 が不変であることを確認済み)。詳細は
  `reports/implementation/quality-loop-fixes/T-004.md` を参照。

### ドキュメント

- **プラグイン数・スキル数の陳腐化修正 (Issue #115)**: skill-reference.md を
  「7 プラグイン / 26 スキル」に更新(sdd-domain を反映)、sdd-domain-plugin-design.md の
  「スキル数 21→27」を「21→26」に訂正。

## v1.10.0 (2026-07-09)

### evidence deep-verify — 6番目の read-only evidence ツール(Issue #68 / Phase 5)

- `sdd-forge-mcp` に `evidence_deep_verify` を追加(PR #106): evidence bundle の
  深層再検証を MCP 経由で提供します。per-artifact SHA-256 再計算と 6 値ステータス
  分類(match / mismatch / missing / too-large / path-denied /
  invalid-recorded-sha、全読取 path-guard 経由・throw なし)、正準 artifacts
  ダイジェストと spec_revision の host スクリプト逐語一致(ADR-0009)、
  git_commit の 40-hex 形状検証(git 不起動、ancestry は host-deferred、
  ADR-0008)、contract/report クロスバインド検証、署名の echo-only 境界
  (`verified: false` 固定・署名鍵非読取)。契約 v1 に evidenceDeepVerifyData を
  加算(後方互換)。host スクリプトとの判定一致ゴールデン(4 fixture 双方向)と
  決定論・スモーク検証付き。全 8 タスクが独立 evaluator / light gate を
  first-pass 8/8 で通過。

### 修正

- `emit-run-record` の gate_reports / review_tickets 集計を対象 feature に
  スコープ(PR #103): タスク ID(T-NNN)は feature ごとに再利用されるため、
  素の `Task: T-NNN` 一致では全 feature の実行が合算されていた。レポート自身の
  `Feature:` 行 / チケットの `feature:` 行での絞り込みに変更し、feature slug の
  正規表現エスケープと CRLF 耐性(severity 行)も追加。sh/ps1 パリティ回帰
  テスト同梱。
- DS-010 契約テストの ordered-checks 終端を DOMAIN-CONFORMANCE 追加後の実装に
  整合(PR #100)。

### 追加

- スタンドアロン `adversarial-review` スキル(PR #102、plugins/ 外・可視性契約
  非干渉): 2 レビュアーのブラインド並列レビュー → 相互批評 → 統合 →
  fresh-context 修正検証のプロトコル。

### ワークフロー改善(WFI-006 / WFI-007)

- WFI-006(Issue #104): 実装レポートの散文陳腐化(4機能連続の friction)への
  対応 — 実装レポートテンプレートに Snapshot Notice 欄を追加し、quality-gate
  に「散文とゲート実測の乖離はゲートレポートに現時点値を記録する(凍結レポート
  本文は改変しない)」手順を追記。
- WFI-007(Issue #105): プラグイン文書 7 箇所の実装レポートパス記載を正準形式
  `reports/implementation/<feature>/<task-id>.md` に統一(evaluator 起動境界の
  要求パターンとの乖離解消。lite トラックは grep ベース探索のため対象外と判定)。

### WFI-004 プラグイン側フォローアップ(Issue #86)

- task-review-precheck に `--provenance-rereview` / `-ProvenanceRereview`
  モードを追加: 実装後の provenance 再レビュー(新 attempt でのエビデンス
  再バインド)時に、事前の persisted task-review PASS 実績を必須とした上で
  canonical workflow-state 検証の失敗のみを許容する(他の precheck 検証は
  従来どおり)。従来は「エビデンスが陳腐化しているから再レビューが必要」な
  状況で precheck 自体が構造的に通過不能だった。
- ADR-0007 を追加: controlled re-binding は「provenance 再レビュー(新
  attempt)」で行い、バリデータ(check-workflow-state)には選択的再バインド
  機構を追加しない決定を記録。
- task レビュアーロールファイル(task-reviewer-a/b)と task-review-loop
  SKILL.md の修正パッチを
  `docs/workflow-improvements/issue-86-protected-gate-files.patch` として同梱
  (enforcement-chain 保護ファイルのためエージェントは直接編集不可 —
  人間が `git apply` で適用する): バリデータ正準の出力スキーマへの整合
  (stage/role 文字列、manifest フィールド、checks[].status vs result、
  findings 配列)、INITIAL-STATE への実装後 provenance 再レビュー条項
  (lifecycle validity 評価)、full プロファイルのレイヤーマニフェスト要件の
  明記、OBSERVABLE-DONE への凍結アーティファクト誘導ガイダンス、SKILL.md への
  「Post-Implementation Provenance Re-Review」手順の新設。

### コンテキスト最適化（トークン削減）

- `investigate-codebase` が `specs/<feature>/codemap.md`（トークン節約型の
  アーキテクチャマップ）を常時生成するようになりました。新テンプレート
  `templates/codemap.template.md` を追加。`sdd-bootstrap-interviewer` と
  `implement-task` は codemap が存在する場合それを先に読み、リポジトリの
  再探索を codemap がカバーしない範囲に限定します（下流エージェントの
  重複探索によるトークン消費を削減）。
- `bootstrap` / `ship` オーケストレータにコンテキスト圧縮（compaction）
  ガイダンスを追加。全状態がディスクに永続化されるフェーズ境界・タスク
  境界でのみ圧縮を行い、インタビュー中・タスク実装中・品質ゲート実行中の
  圧縮を避けます。

## v1.9.0 (2026-07-06)

### DDD アップストリームレーン（sdd-domain、7番目のプラグイン）

- 新プラグイン `sdd-domain` を追加（`sdd-bootstrap` / `sdd-implementation` /
  `sdd-quality-loop` / `sdd-lite` / `sdd-review-loop` / `sdd-ship` に続く
  7番目）。Phase 1 のさらに前段で、公開スキル `/sdd-domain:domain-model`
  （`new` / `update` / `reverse` の3モード）が七段階インタビュー
  （Domain Story → Event Storming → Ubiquitous Language → Context Map →
  Domain Model (aggregates) → Domain Message Flow → C4 Container）を実施し、
  人間承認済みの `domain/` 配下のドメインモデルと `domain-contract.json` を
  生成します。可視性契約は公開スキル5→6（新規は `domain-model` のみ）で
  維持され、内部スキル `domain-interviewer` / `domain-reverse` /
  `domain-review-loop` / `domain-sync` はすべて `user-invocable: false`
  です。
- **独立レビュー**: `domain-review-loop` が `domain-reviewer-a`（戦略:
  コンテキスト境界・関係パターン・イベント網羅性・用語の一意性）と
  `domain-reviewer-b`（戦術: 不変条件の検証可能性・トランザクション境界の
  現実性・god-aggregate/anemic-model リスク）による最大3ラウンドの独立
  レビューを実施し、承認後は cross-model-verify のスクリプトを人間権限
  （`SDD_SUDO`）下で直接呼び出してクロスモデル検証まで行います。承認後の
  `domain/` ドリフトはレビュー前提条件チェックが検知し、人間によるステータス
  リセットを要求します。
- **下流同期**: 承認済みモデルが存在する場合、`domain-sync` が
  `sdd-bootstrap-interviewer` の Phase 1 出力に正準コンテキストと用語を注入
  し（`requirements.md` に `Bounded-Context:` フィールドを追加）、
  `spec-reviewer-a/b` / `impl-reviewer-a/b` に DOMAIN-CONFORMANCE 観点を追加
  します。決定論ゲート `check-domain-conformance.(sh|ps1)` は
  `requirements.md`/`design.md` を `domain-contract.json` と照合し、未知の
  用語・未宣言の `Bounded-Context:`・未登録の集約参照を warn で報告します
  （`SDD_DOMAIN_ENFORCE=error` で昇格）。`workflow-retrospective` はこれらの
  warn 所見から用語逸脱数・境界違反数を集計します。
- **絶対的な不可侵**: `domain/` が存在しないプロジェクトでは全フック・
  同期・ゲートがスキップされ、1行のスキップ記録のみを残して既存ワークフロー
  はバイト同一の成果物を生成します（AC-010）。
- `tests/validate-repository.ps1` の期待値を更新（プラグイン数 6→7、
  スキル数 21→26、公開スキル5→6）。

### local-env-mcp — ローカル環境情報 MCP サーバー(新規)

- 読み取り専用の環境情報 MCP サーバー `mcp/local-env-mcp` を新設
  (`get_os_info` / `get_toolchain_versions` / `list_available_clis` の3ツール)。
  実行機能なしの設計: execFile 限定(shell なし)・コンパイル時固定 14 CLI
  allowlist・2秒タイムアウト・8KiB 出力上限・並列上限4・TTL 60秒キャッシュ・
  秘匿情報 redaction(canary 検査で非漏えいを実証)。契約は
  `contracts/local-env-mcp-tools.v1.schema.json`。esbuild 単一バンドルを
  dist コミットし、CI に 3 OS マトリクス + dist-parity ジョブを追加。
- installer 統合: `install.sh` / `install.ps1` が local-env-mcp を
  デフォルト同梱(`--mcp <list>` 選択・`--skip-mcp`・Node >= 20 ゲート)。
  Cursor(`~/.cursor/mcp.json` の `mcpServers`)/ VS Code(ユーザー
  プロファイル `mcp.json` の `servers`、OS 別パス)への自動登録
  (idempotent upsert・破損 JSON フェイルセーフ・`SDD_CURSOR_DIR` /
  `SDD_VSCODE_USER_DIR` オーバーライド)。`uninstall.sh` / `uninstall.ps1`
  は installer 管理エントリのみ削除し、ユーザーエントリを保全。
- ドキュメント: README / USERGUIDE に概要・3ツール・セキュリティ境界
  (実行機能なし)・Cursor / VS Code の自動/手動登録手順を追加。
- 全 10 タスクが full プロファイルの品質ゲート(独立 evaluator +
  evidence bundle)を PASS。TDD red/green 証跡・identity ledger 連鎖・
  requirement traceability(12 links)を完備。

### ワークフロー機構の修正と自己改善(WFI)

- AGENTS.md に「Post-review artifact freeze」「Post-implementation
  provenance re-review」の2規則を追加(WFI-004、人間承認済み)。実装後の
  full プロファイル `check-workflow-state` が恒常的に green 化
  (exit 1 → 0)。レビューゲートのプラグイン側ロール定義との不一致は
  https://github.com/aharada54914/sdd-forge/issues/86 で追跡。
- sdd-quality-loop / sdd-review-loop のゲート修正(issue #62 / #71 対応):
  保護対象ゲートファイルを標的とする書込のみ拒否、impl-review manifest の
  bounded superset 許容、任意チェックアウトからの spec 契約受理、weekly
  self-improvement の fail-fast 化(#74)。
- WFI-001(高リスクタスク preflight)・WFI-002(手動 precheck 逸脱記録)・
  WFI-003(レポート識別フィールド)・WFI-004 の4件が retrospective で
  Verified となり、retention-checklist に再発検知条件を登録。

## v1.8.0 (2026-07-03)


### デザイン駆動高速イテレーションレーン

- 内部スキル `design-sync-loop`（sdd-bootstrap）を新設。仕様段階で
  claude.ai/design（DesignSync ツール）からデザインシステムを参照し、
  使い捨て HTML モックアップを生成、都度人間承認のうえ Push して
  ブラウザ確認ループを回す。ツールがない環境では従来の手動手順
  （claude-design-workflow.md）にフォールバック。
- 内部スキル `visual-verify-loop`（sdd-implementation）を新設。UI タスクの
  実装後に Claude Preview MCP（Web）/ wpf-visual-verify（WPF）で
  「起動→スクリーンショット→デザイン照合→修正」を最大5回イテレーションし、
  最終スクリーンショットを `reports/visual-evidence/<task-id>/` に証跡保存。
  非ブロッキングで、合否判定は quality-gate と人間レビューのまま。
- sdd-bootstrap-interviewer / lite-spec / implement-task に上記への
  ルーティングを追加。公開スキルは5つのまま（可視性契約は不変）。

### 統一デザインシステム統合（design-system 契約）

- プロジェクトレベルの `design-system/` 契約を新設: W3C DTCG 準拠の
  design-tokens.json（`contracts/design-system.contract.v1.schema.json` で
  メタ検証）、design-system.md（3層構造・WCAG 2.2 AA）、ui-patterns.md
  （言語非依存の普遍的 UX 規約6カテゴリ）。テンプレート3点を同梱し、
  PLUGIN-CONTRACTS.md に producer/consumer 契約を定義。
- interviewer に `ds_profile`（custom / none）選択を追加。custom では
  design-sync-loop v2 が design-system/ を保証（ui-ux-pro-max シード生成・
  Figma DTCG エクスポート取込・D6 テンプレートインタビューの3経路）し、
  トークン駆動モックアップを生成。investigate-codebase に brownfield 用
  Design Inventory を追加。
- レビュー統合: impl-reviewer-a に DESIGN-SYSTEM-CONFORMANCE 検査を追加
  （impl-review-loop は20チェック化）、impl-reviewer-b の DESIGN-WITHIN-SCOPE
  に規約外 UI ライブラリ検出を追加。
- 実装強制: implementation-policy に UI 実装規則（トークン参照のみ・
  再利用優先・a11y 要点・lint 未整備のタスク化）、implement-task の
  条件付き必須読み物、visual-verify-loop の照合基準に design-system を追加。
- 検証ゲート: design-system-checklist.md 新設、accessibility-checklist を
  WCAG 2.2 AA に更新、決定論ゲート `check-design-system.(sh|ps1)` を warn
  モードで導入（`SDD_DESIGN_SYSTEM_ENFORCE=error` で昇格、導入2リリース後に
  error 化予定）。verification-contract に `design-system` チェック、
  risk-gate-matrix に条件付きコントロール行を追加。
- 全変更は条件付きロード / waivable check として実装し、非 UI プロジェクト・
  `ds_profile: none` へのオーバーヘッドはゼロ。

## v1.7.0 (2026-07-02)

### スラッシュメニューの2コマンド化とエントリコマンドのリネーム

- **破壊的変更**: エントリスキルをリネーム。`/sdd-bootstrap:run` → `/sdd-bootstrap:bootstrap`、
  `/sdd-ship:run` → `/sdd-ship:ship`。両スキルが `name: run` を共有していたため、
  ホスト UI（Claude Code / Codex）で選択後の表示がどちらも `run` になり
  区別できなかった問題を解消。
- 内部オーケストレーション用の14スキルに `user-invocable: false` を追加し、
  スラッシュコマンドメニューから非表示化。ユーザーに見えるコマンドは
  `bootstrap` / `ship` / `sdd-sudo` / `fix-by-review-ticket` / `diagnose` の5つのみ。
  `disable-model-invocation: true` は全スキルで維持（モデルの自動起動禁止は不変）。
  再開機能は影響なし（エントリコマンドがタスク状態から再開点を自動検出する）。
- `tests/validate-repository.ps1` にスキル可視性契約の検証を追加
  （公開5スキル以外は `user-invocable: false` 必須）。

### 自己改善フロー（WFI）の効果測定基盤

（提案の全文: `docs/contributor/self-improvement-measurement-proposal.md`）

- **ランレコード（Phase A）**: `emit-run-record.sh` / `.ps1` を新設。retrospective 実行時に
  `reports/runs/RUN-<timestamp>-<feature>.json` を決定論的に生成し、モデルID・
  プラグインバージョン・適用中 WFI 一覧・カウントベース指標を記録する。
  以後の WFI 効果の帰属分析はこのレコードを一次ソースとする。
- **WFI 検証の拘束力強化（Phase B）**: WFI テンプレートに `Target-Metric` /
  `Expected-Direction` / `Horizon` / `Rollback-Plan` と2軸分類
  （`Category`（スコープ軸: 既存2 + `human-process` / `measurement`）、
  `Mechanism`（instructions / memory / tools / architecture / model-routing）、
  `Meta-Change` フラグ）を追加。retrospective は Applied WFI の Horizon を毎回
  機械チェックし、期限内未達なら Rejected + ロールバック提案を出す。
  測定系（grader・閾値・retrospective ロジック）を触る WFI は Meta-Change
  厳格監査レーンへ（wfi-auditor-b に anti-Goodhart チェックを追加）。
- **Retention チェック（Phase C）**: `docs/workflow-improvements/retention-checklist.md`
  を新設し、Verified 済み WFI が直した失敗モードの再発を retrospective が毎回検知。
  再発時は WFI を新状態 `Regressed` に落とし、再起票を提案する。
- **golden タスクの足場（Phase D、スキャフォールド）**: `tests/golden/` に fixture
  形式と pairwise 検証手順の README を追加（fixture 本体は実失敗事例から今後蓄積）。
- `scripts/bump-version.sh` を新設し、リリース面（マニフェスト18 + marketplace 2 +
  README + バリデータ + リリーステスト）のバージョン同期を1コマンド化。

## v1.6.0 (2026-07-02)

### バグ修正トラックと P0 ハードニング

- `diagnose` スキルを新設。ハードなバグ・リグレッション・フレーキーテスト・性能退行に対し、
  再現→計装→根本原因→最小修正の5フェーズ診断規律（HITLループ）を回し、
  `reports/diagnosis/<id>.md` として出力する。フル SDD の3レビューループを通す前段として、
  軽量トラック（lite-spec → 単一承認 → implement-task → lite-gate）への入口を兼ねる。
  `task-reviewer-b` の `BUGFIX-DIAGNOSTIC-PATH` チェックが要求する証跡を供給する。
  `docs/workflow-guide.md` に「バグ修正トラック（diagnose）」節を追加。
- `wfi-audit-cycle` の監査ループに試行上限を設け、変化なし（NO-CHANGE）が続く場合は
  自動的に停止するよう修正し、監査サイクルの無限ループ化を防止。
- `sdd-ship` の品質ゲートに、ディスクベースの試行回数上限を導入し、修正・再検証サイクルが
  際限なく繰り返されることを防止。
- `implement-tasks` を独立タスクの並列ディスパッチに対応させ、依存関係のないタスク群を
  同時実装できるよう変更。
- workflow-state: 1.5.0 リリースコミットで provenance が乖離した3 feature
  （`agent-cost-context-isolation`、`bootstrap-interviewer-enhancement`、
  `workflow-state-integrity`）を、機能は維持したまま bounded legacy プロファイルへ移行。
- CI: provenance テストのため full history fetch (`fetch-depth: 0`) を追加し、
  installer テストの一時ディレクトリ cleanup を best-effort 化してテストの flake を修正。
- 全リリース面（プラグインマニフェスト、marketplace、README、リポジトリ検証スクリプト）を
  1.6.0 に同期。

## v1.5.0 (2026-06-30)

### Agent cost and context iteration metrics

- workflow-retrospective now records task attempts, review rounds,
  quality-gate runs, and model escalations so iteration cost can be measured
  independently from token price.
- All Claude, Codex, and Copilot plugin manifests, marketplaces, README, and
  repository release surfaces identify release `1.5.0`.
- Added a rollback contract for restoring the release surfaces to the pinned
  `1.4.0` baseline after hash validation.

## v1.4.0 (2026-06-29)

### Bootstrap interviewer のレイヤー仕様対応

- FULL プロファイルで UX、frontend、infrastructure、security の4レイヤー
  artifact を生成し、`design.md` と `traceability.md` から正規アンカーで索引化。
- 選択した feature directory だけを対象に、不足 artifact や空テンプレートを
  Bash / PowerShell で fail-closed 検証する構造チェックを追加。
- implementation review と task review の入力を、core spec、design、
  traceability、4レイヤー仕様の hash に拘束し、差し替えや profile downgrade
  による回避を拒否。
- Draft から Approved への人手または有効な署名付き sudo の承認境界と、
  既存 LITE / legacy profile の互換性を維持。

## v1.3.0 (2026-06-29)

### ワークフロー状態の整合性強化

- リポジトリ全体の SDD 状態を fail-closed で検証する Bash / PowerShell
  チェッカーを追加し、CI、品質ゲート、仕様・実装・タスクの各レビュー前処理へ統合。
- pre-v1.3.0 の履歴だけを対象に、固定 cutoff、理由、所有者、許容欠落項目を
  明示した bounded legacy migration を導入。
- predecessor review の遷移判定を修正し、レポートパス衝突時も feature と
  evidence bundle に結び付いた品質レポートだけを採用。
- 既存の公開コマンド、インストール／アンインストール動作、プラグイン構成は維持。

## v1.2.0 (2026-06-25)

### 修正: エントリーポイントコマンドがスラッシュメニューに表示されない問題

`sdd-bootstrap` / `sdd-ship` プラグインのエントリースキル名がプラグイン名と一致していたため、Claude Code のプラグインスキル名前空間と衝突し（[claude-code#22063](https://github.com/anthropics/claude-code/issues/22063)）、`/sdd-bootstrap` と `/sdd-ship` が `/` メニューに表示されず、フル入力しても `Unknown command` となっていた。

- エントリースキルの `name` をそれぞれ `run` にリネーム（スキルフォルダも `skills/run/` へ移動）。
- ユーザー向けコマンドは **`/sdd-bootstrap:run`** と **`/sdd-ship:run`** になった（プラグイン名前空間が衝突しなくなり、メニューに表示され実行可能）。
- 内部ヘルパー（`/sdd-bootstrap:sdd-adopt` など）、プラグイン名、`marketplace.json` の `source` パスは変更なし。
- 全ドキュメント・Codex `defaultPrompt`・テストの参照を新コマンド名に更新。

## v1.0.0 (2026-06-21)

### バージョニング方針の変更

v0.15.x から v1.0.0 へのメジャーバンプ。全プラグインのバージョンを `1.0.0` に統一。

`/sdd-bootstrap` + `/sdd-ship` の2コマンドワークフローが確立し、ユーザー向けの公開インターフェースが安定したため、メジャーバージョン 1 に昇格する。

### v0.14.x からの移行

- **移行注意**: `impl-review-loop` と `task-review-loop` は `sdd-review-loop` に移設されたため、旧 namespace（`/sdd-impl-review:*`、`/sdd-task-review:*`）は使用できない。その他の旧スキル（`implement-task`、`quality-gate` 等）は引き続き動作する。
- ユーザーが直接使うコマンドは `/sdd-bootstrap` と `/sdd-ship` の2つ。内部スキルは `sdd-ship` 経由で自動実行される。
- `v0.14.0` タグが旧パラダイム（15スキル時代）の最終状態として参照可能。

---

## v0.15.1 (2026-06-21)

### 変更

- **`sdd-review-loop` プラグイン新設（内部リファクタリング）**: `sdd-impl-review` と `sdd-task-review` の2プラグインを `plugins/sdd-review-loop/` に統合。`impl-review-loop` と `task-review-loop` の各スキル・エージェント・スクリプト・テンプレートを移植し、`plugins/sdd-bootstrap/skills/sdd-bootstrap/SKILL.md` および `sdd-bootstrap-interviewer/SKILL.md` の呼び出しパスを更新。旧プラグインディレクトリは完全削除（`$forbiddenPaths` で再作成を防止）。
- **フックガード強化（Python Check 2e）**: `sdd-hook-guard.py` に `impl_review_status_passed_increases` チェック（Check 2e）を追加。JS の `implReviewStatusPassedIncreases` との動作パリティを確立。`PROTECTED_GATE_SUFFIXES` に `sdd-review-loop` の6パスを追加。
- **内部 SKILL.md に Caller ヘッダー追加**: `implement-task`、`implement-tasks`、`quality-gate` の3スキルの frontmatter 直後に「このスキルは sdd-ship から呼ばれる」旨の caller-context ヘッダーを追加。直接呼び出し抑止のためのドキュメント整備。
- **ドキュメント再構成**: `docs/skill-reference.md`（1374→576行）と `docs/workflow-guide.md`（998→297行）をスリム化し、内部詳細を `docs/contributor/` 配下に分離。`wfi-category-guide.md` の forbidden terms に `sdd-review-loop` を追加。
- **テストスイート強化**: `tests/guard-parity.tests.sh` に Scenarios 19/20/21（impl-review-status ガードのパリティ検証）を追加。`tests/validate-repository.ps1` の `$expectedSkills` を 15→17 件に修正（sdd-bootstrap と sdd-ship の既存バグ修正）および `$forbiddenPaths` に旧プラグインパスを追加。

### v0.15.0 からの移行

- 破壊的変更なし。`impl-review-loop` と `task-review-loop` はプラグインが変わるだけで機能は同一。
- 既存レポートパス（`reports/impl-review/`、`reports/task-review/`）は変更なし。
- 旧パス（`/sdd-impl-review:impl-review-loop`、`/sdd-task-review:task-review-loop`）は削除済み。新パス `/sdd-review-loop:impl-review-loop` / `/sdd-review-loop:task-review-loop` を使用。

## v0.15.0 (2026-06-20)

### 追加

- **`sdd-ship` プラグイン（実装・品質保証フェーズのオーケストレーター）**: 新しいトップレベル公開コマンド。承認済みタスクを `implement-tasks` → `quality-gate`（または `lite-gate`）→ `workflow-retrospective` の順に処理し、全タスクを Done に導く薄いオーケストレーター。
  - **2コマンドワークフロー確立**: ユーザーが直接呼び出すのは `/sdd-bootstrap` と `/sdd-ship` の2つのみ。内部スキル（`implement-task`、`quality-gate` 等）は引き続き動作し、後方互換性を完全に維持。
  - **自動トラック検出**: `--full` → `--lite` → `spec_profile: lite`（AGENTS.md）→ デフォルト FULL の優先順でトラックを自動検出。`[sdd-ship] Track: ...` メッセージを常に先頭に出力。
  - **ゼロ引数起動**: 引数なしで実行すると AGENTS.md の `## Active Spec Directories` を走査し、承認済みタスクが1フィーチャーのみなら自動選択。
  - **`--verify` フラグ**: `Cross-Model: enabled` を持つタスクのみ `cross-model-verify` を実行。対象タスクがない場合は警告を出力して通常ゲートへ。lite トラックでは無視。
  - **`--retro` フラグ**: 全タスク Done 後に `workflow-retrospective` を強制実行。
  - **サイクル上限**: 同一タスクで `quality-gate` を3回実行しても Done に到達しない場合は人間調査を促して停止。
  - **セキュリティ境界**: `sdd-sudo` の呼び出し禁止、`Approval: Approved` の自己設定禁止、フックファイルの変更禁止。
  - ファイル: `plugins/sdd-ship/skills/sdd-ship/SKILL.md`、`plugins/sdd-ship/.claude-plugin/plugin.json`、`plugins/sdd-ship/.codex-plugin/plugin.json`、`plugins/sdd-ship/.plugin/plugin.json`

- **`sdd-bootstrap` トップレベルルーター**: `plugins/sdd-bootstrap/skills/sdd-bootstrap/SKILL.md` を新規作成し、全モード（feature/bugfix/refactor/project/adopt/investigate）のルーティングと `--lite`/`--feature`/`--reset` フラグを一元管理するエントリーポイントを追加。ハンドオフは常に `/sdd-ship` を次ステップとして案内。

### 変更

- **`install.sh` / `install.ps1` デフォルト変更**: デフォルトプラグインセットを `sdd-bootstrap,sdd-ship` に変更。`sdd-ship` を選択すると全依存プラグインが自動展開される。`VALID_PLUGINS` に `sdd-ship` を追加。`REQUIRED_PATHS` に sdd-ship の3ファイルを追加。
- **marketplace 更新**: `.claude-plugin/marketplace.json` と `.agents/plugins/marketplace.json` に `sdd-ship` エントリを追加。`sdd-implementation` と `sdd-lite` の description に `[internal]` プレフィックスを付与（UX 整理; 機能削除なし）。
- **フックガード更新**: `sdd-hook-guard.js` と `sdd-hook-guard.py` の `PROTECTED_GATE_SUFFIXES` に `plugins/sdd-ship/skills/sdd-ship/SKILL.md` を追加（R-10 保護）。
- **ドキュメント更新**: README.md にクイックスタート（2コマンド）セクションを追加。`docs/workflow-guide.md` に2コマンドクイックリファレンス表を追加。`docs/skill-reference.md` に sdd-ship と sdd-bootstrap のエントリを追加し、スキル数を16に更新。

### v0.14.0 からの移行

- 当時の公開内部スキルは直接呼び出し可能だった。後続リリースの明示的な移行（`sdd-review-loop` への namespace 移設など）はこの保証の対象外。
- 既存の `sdd-bootstrap,sdd-implementation,sdd-quality-loop,sdd-lite` でのインストールは引き続き動作する。新インストールは `sdd-bootstrap,sdd-ship` のみで全依存が自動展開される。
- `spec_profile: lite` を持つ既存プロジェクトは `/sdd-ship` が自動的に lite トラックを検出する。

## v0.14.0 (2026-06-19)

### 追加

- **`impl-review-loop` スキル（実装方針レビューループ）**: `sdd-impl-review` プラグインを新設し、design.md に対して 2 体の独立したブラインドレビュアー（A: 構造健全性、B: 実装可能性/リスク）による最大 3 ラウンドのレビューを実施する。
  - **Phase 1/2 分割**: `sdd-bootstrap-interviewer` を Phase 1（requirements.md + design.md + acceptance-tests.md）と Phase 2（tasks.md + traceability.md）に分割。`impl-review-loop` で `Impl-Review-Status: Passed` が設定されるまで Phase 2 はブロック。
  - **PASS-with-warnings**: ラウンド 3 終了時に Minor 指摘のみ残存の場合は `Passed` として設定し、`## Implementation Warnings` セクションに記録。
  - **BLOCKED + --reset**: ラウンド 3 終了時に Major/Critical 残存の場合は BLOCKED。`--reset` で attempt-M+1 からやり直し。
  - **ブラインドレビュー**: reviewer-b は `disallowedPaths` で reviewer-a.json を読めない。オーケストレーターが `integrated-summary.json`（件数 + ID のみ）を橋渡し。
  - **legacy_design 互換モード**: 新テンプレートフィールド未設定の既存仕様書は `[LEGACY COMPAT]` Minor 通知のみで失敗しない。
  - ファイル: `plugins/sdd-impl-review/skills/impl-review-loop/SKILL.md`、`agents/impl-reviewer-a.md`、`agents/impl-reviewer-b.md`、`scripts/impl-review-precheck.sh`、`templates/impl-review-contract.template.json`

- **`task-review-loop` スキル（タスク分解レビューループ）**: `sdd-task-review` プラグインを新設し、tasks.md に対して 2 体の独立したブラインドレビュアー（A: 構造カバレッジ、B: 品質/リスク）による最大 3 ラウンドのレビューを実施する。
  - **Reviewer-A の 14 チェック**: PREREQ-AC-IDS、BLOCKERS-FORMAT、REQ-COVERAGE、AC-COVERAGE、ORPHAN-TASK、ORPHAN-TEST、INITIAL-STATE、RISK-WORKFLOW-FORMAT、NO-DUPLICATE-AC、DEPENDENCY-COMPLETE（A.10）、DEPENDENCY-CYCLE（A.11）、SINGLE-CONCERN、OBSERVABLE-DONE、TRACEABILITY-SYNC
  - **Reviewer-B の 8 チェック**: RISK-APPROPRIATE、HIGH-CRITICAL-EVIDENCE、TASK-SIZE、EDGE-CASE-COVERAGE、TEST-TYPE-MATCH、ROLLBACK-PLAN、SCOPE-DISJOINT、DEPENDENCY-OVERLAP
  - **DEPENDENCY-COMPLETE → DEPENDENCY-CYCLE 順序保証**: A.10 (DEPENDENCY-COMPLETE) が A.11 (DEPENDENCY-CYCLE) より先に実行されることをスキルで保証。
  - **Blockers 正準形式検証**: `precheck.sh` がカンマ区切り T-NNN 形式を検証し、range 記法（`T-NNN..T-MMM`）を Major で棄却。
  - ファイル: `plugins/sdd-task-review/skills/task-review-loop/SKILL.md`、`agents/task-reviewer-a.md`、`agents/task-reviewer-b.md`、`scripts/task-review-precheck.sh`、`templates/task-review-contract.template.json`

- **`sdd-bootstrap-interviewer` にレビューゲート追加**: Phase 1 → 仕様レビュー → 実装方針レビュー → Phase 2 → タスク分解レビュー → 承認ゲートの5段階フローに変更。
  - LITE プロファイル（`spec_profile: lite`）は全ゲートをスキップ。
  - acceptance-tests.md 不在の場合は LITE-SKIP が自動発動。

### 変更

- **`sdd-hook-guard.js` ガード拡充**: 新規レビュアーエージェントファイル 6 点を R-10 保護リストに追加。`Impl-Review-Status: Passed` を有効な `integrated-verdict.json`（PASS|PASS-with-warnings）なしに書き込む操作をブロック。
- **`workflow-retrospective`**: `reports/task-review/`・`reports/impl-review/` をスキャン対象に追加。新メトリクス: `task_review_rounds_per_feature`、`impl_review_rounds_per_feature`、`impl_review_blocked_rate`、`impl_review_legacy_design_rate`。
- **design.md テンプレート拡張**: `Impl-Review-Status: Pending`・`Feature Type`・`## Components`・`## Architecture Decision Records`・`## Security Boundaries`・`## Constraint Compliance`・`## Open Questions`（Blocks Implementation / Resolution Path 形式）を追加。
- **tasks.md テンプレート拡張**: `Task-Review-Status: Pending` ヘッダー・タスク単位の `Planned Files`・`Data Migration`・`Breaking API` フィールドを追加。
- **requirements.md テンプレート拡張**: `## Security Boundaries` セクションを追加。

### v0.13.0 からの移行

- 破壊的変更なし。既存の design.md / tasks.md に新フィールドが無い場合は `[LEGACY COMPAT]` Minor 通知のみで自動通過。
- `impl-review-loop` と `task-review-loop` は新規フィーチャーからの適用を推奨。既存フィーチャーへの後付け適用も可能（`Impl-Review-Status: Pending` を design.md ヘッダーに追記するだけ）。
- プラグイン再インストール（ワンライナー再実行）で移行完了。

## v0.13.0 (2026-06-19)

### セキュリティ強化

- **`sudo_active()` TOCTOU 防止**: `O_NOFOLLOW` + `O_NONBLOCK`（FIFO ブロッキング攻撃対策）+ `fstat`（シンボリックリンク置換競合防止）を py/js 双方に追加。Windows では `O_NOFOLLOW` が存在しない場合に `lstatSync` / `os.lstat` でシンボリックリンクを拒否するフォールバックも追加。
- **パストラバーサル防止**: `_is_protected_gate_file` / `isProtectedGateFile` に `os.path.normpath` / `path.posix.normalize` を適用し、`../` を含むパスによる R-10 保護回避を閉じる。
- **heredoc リダイレクト保護**: `cat > protected_file << EOF` 形式のコマンドが R-10 保護ファイルを上書きできた問題を修正。
- **R-10 保護リスト拡充**: `tests/constant-parity.tests.sh` を py/js の保護対象に追加。
- **プラグイン JSON 相対パス修正**: シェルコマンドスキャンで相対パス形式のプラグイン JSON を正しく検出。

### 修正

- **`validate_path.py` 空白バイパス修正**: 空白のみのパス文字列がチェックを通過していた問題を修正（`strip()` を空チェック前に適用）。
- **`check-contract.py` JSON 型安全**: `checks` が非リストの場合・リスト内に非 dict 要素がある場合を明示的に失敗。`evidence` / `waiver_reason` フィールドに `_str_field()` ヘルパーで型安全な抽出を適用。

### テスト改善

- **`guard-parity.tests.sh`**: `parity_check` に期待 exit code パラメータを追加し、両ランタイムが一致しているだけでなく期待値通りであることも検証。
- **`constant-parity.tests.sh`**: `RISK_TIERS` の検証をティア名の比較から `tier:id` ペア（31 エントリ）の完全比較に強化。
- **`gates.tests.sh`**: R-04 テストを tmpdir コピー方式に変更し、テスト失敗時にスクリプトが消えない安全な実装に修正。

### v0.12.0 からの移行

- 破壊的変更なし。既存の tasks.md / contract / evidence ファイルへの変更不要。
- プラグイン再インストール（ワンライナー再実行）で移行完了。

## v0.12.0 (2026-06-18)

### 追加

- **`implement-tasks` スキル（バッチ実装）**: `sdd-implementation` プラグインに新スキルを追加。承認済みタスクを依存関係順に連続実行し、全タスクが `Implementation Complete` になった時点で `quality-gate` を自動起動する。
  - **依存関係フィルタ**: 各タスクの `### Blockers` セクションを解析し、参照先タスク (`T-NNN` パターン) が未完了の場合はスキップして後回しにする
  - **自動 quality-gate 移行**: 全 `Approval: Approved` タスクが `Implementation Complete` になった時点で quality-gate を自動起動する
  - **ループ再開対応**: Blocked 発生時はバッチを停止し、再実行時に最初の選択可能タスクから自動再開する
  - **sudo 対応**: 有効な `SDD_SUDO` があれば per-task 承認チェックを自動通過（Block-and-Stop 決定は sudo でもバイパスしない）
  - ファイル: `plugins/sdd-implementation/skills/implement-tasks/SKILL.md`

### 変更

- **`sdd-implementation` プラグインを v0.12.0 に更新**: description・capabilities・`defaultPrompt` を `implement-tasks` を含む形に更新（`.plugin/plugin.json` / `.claude-plugin/plugin.json` / `.codex-plugin/plugin.json`）
- **`docs/skill-reference.md` 更新**: スキル早見表に `implement-tasks` 行を追加（12スキルに）。既存行の「後段スキル」を `implement-tasks` 対応に更新。`implement-tasks` の詳細セクションを追加
- **`docs/workflow-guide.md` 更新**: §3.1 正常系フローの「実装」行に `implement-tasks` を追記。Mermaid 状態遷移図のラベルを更新。§4.7 セッション再開例に `implement-tasks` を追加

### v0.11.0 からの移行

- 破壊的変更なし。`implement-task` は従来通り動作する。
- 新スキル `implement-tasks` は追加のインストール不要（スキルディレクトリへの配置のみ）。
- 既存の tasks.md / reports / specs ファイルへの変更不要。

## v0.11.0 (2026-06-15)

### 追加

- **sdd-lite プラグイン（軽量・中量トラック）**: 社内・部署内アプリ向けの4ステップフロー（lite-spec → 単一承認 → implement-task → lite-gate → Done）。evidence-bundle / ADR 必須 / cross-model / critical を省略し、既存プラグインとの加算的昇格に対応。
  - スキル: `lite-spec`（軽量仕様生成）、`lite-gate`（軽量品質ゲート）
  - スクリプト: `check-task-state-lite.{sh,ps1}`（Done を evidence-bundle 非依存にした lite 状態ゲート）
  - テンプレート: `requirements-lite.md` / `design-lite.md` / `tasks-lite.md` / `quality-report-lite.md`
  - リファレンス: `lite-flow-policy.md`（lite 規約・昇格手順）

### 変更

- **install / marketplace が4プラグイン構成に**: `install.sh` / `install.ps1` および `.claude-plugin/marketplace.json` / `.agents/plugins/marketplace.json` に `sdd-lite` を追加。既定インストールで `sdd-bootstrap` + `sdd-implementation` + `sdd-quality-loop` + `sdd-lite` の4プラグインが同時導入される。

## v0.10.0

リスク適応ゲート (risk-adaptive-layer, PR #16) と クロスモデル検証 (cross-model-verification, PR #20) を追加したセキュリティ・品質強化リリース。CI グリーン (Windows / macOS / Linux)。

### 新機能・強化

**リスク階層 (`low / medium / high / critical`) とゲートマトリクス**: タスクに `Risk:` + `Risk Rationale:` フィールドを追加。階層が上がるほど必須ゲートセットが拡大し、下位階層の必須セットを完全包含する (非ダウングレード superset 則)。`Risk:` フィールドが無いタスク/contract はレガシーモードで動作し、階層強制を一切行わない (後方互換)。正準対応表: `plugins/sdd-quality-loop/references/risk-gate-matrix.md`。

**新ゲート `check-risk.{sh,ps1}`**: タスクの `Risk:` 階層と `Risk Rationale:` フィールドを検証。`high`/`critical` タスクが `Required Workflow: tdd` を宣言していない場合にフェイルクローズ。

**新ゲート `check-traceability.{sh,ps1}`**: REQ→AC→TEST→証跡のトレーサビリティチェーンを決定論的に検証。`high`/`critical` は require-evidence モードで証跡ファイルの実在も検査。

**リスク対応 `check-contract.{sh,ps1}` 拡張**: Pass 4 でタスク階層の必須チェックセット superset を強制。Pass 5 で `required_workflow: tdd` の Red→Green 証跡 (`red_evidence` / `green_evidence`) を検証。`stack` 記述子 (`code` / `shell` / `docs` / `spec`) に対応し、非コードスタックでは compile 系チェック (`lint` / `typecheck` / `build`) を理由付き (`waiver_reason` 非空) で waive 可能。テスト/トレーサビリティ系チェックは全スタックで必須のまま。

**Evidence bundle プロベナンス** (`generate-evidence-bundle.{sh,ps1}`): `risk`・`required_workflow`・`spec_revision`・`build_env`・`builder`・`review_verdict` フィールドを bundle に出力。`check-evidence-bundle.{sh,ps1}` が `high`/`critical` でこれらフィールドを必須検証。

**HMAC-SHA256 署名 (critical bundle)**: 鍵は外部 (`SDD_EVIDENCE_KEY` 環境変数 / `SDD_EVIDENCE_KEY_FILE` / `~/.sdd/evidence-key`) からのみ解決。`critical` タスクのバンドルは dirty ツリーでの生成をハードフェイル。

**二者承認 (critical タスク)**: `check-task-state` が `Approval:` + 別名義の `Second Approval:` を要求。sudo でもバイパス不可。`sdd-hook-guard` でも同様に強制。

**ガバナンスのコード化**: `.github/rulesets/main.json` (GitHub Rulesets API 形式)、ルート `CODEOWNERS`、`scripts/apply-branch-protection.sh`、`.github/workflows/test.yml` に `merge_group:` トリガーと `required-checks` ジョブを追加。

**新規ドキュメント**: `docs/THREAT-MODEL.md`（脅威モデル）・`docs/agent-capability-matrix.md`（エージェント能力マトリクス）を追加。

**クロスモデル検証 (cross-model-verification, PR #20)**: 単一の独立 evaluator (`sdd-evaluator`) に加え、複数ベンダーの LLM パネリスト (Claude + GPT/Gemini) に同一の検証を**盲目・並列**で投げ、独立 verdict を集約して単一ベンダー盲点を補強する層を追加。

- **新スキル `cross-model-verify`**: 収集層（`prepare-panelist-input` で consent＋サニタイズ → `detect-panel` / `run-panelist-{gpt,gemini}` で盲目並列実行 → verdict JSON 収集）。`disable-model-invocation: true`（ユーザー明示起動）。
- **新ゲート `check-cross-model.{sh,ps1}`**: 決定論的 consensus 判定（多様性: distinct vendor ≥2 かつ 非Anthropic ≥1 / 全 verdict PASS かつ Critical なし / evaluator 乖離 → `requires_human_decision`）。exit 0/1/2。
- **`check-contract` Pass 6**: contract の `cross_model` ディスクリプタ (`required` / `waived` / `legacy`) を検証。`signature`/`two-person approval` と同じ条件付き制御で、機械形 `RISK_TIERS` には非追加（matrix↔encoding パリティと後方互換を維持）。critical=必須(waiver可)/high=opt-in。
- **新パネリストエージェント**: `sdd-panelist-gpt`・`sdd-panelist-gemini`（read-only、`.codex/agents/sdd-panelist-*.toml` ＋ `plugins/sdd-quality-loop/agents/panelist-*.md`）。Claude パネリストは Agent ツール経由。
- **2層分離**: 収集層は外部 API・opt-in・**CI では実行しない**（コストと外部送信防止）。ゲート層のみ CI で fixture 検証。`SDD_EVIDENCE_KEY` 等はパネリストに渡さない。
- **新ポリシー**: `plugins/sdd-quality-loop/references/cross-model-verification-policy.md`。

### v0.9.0 からの移行

- **既存タスク/contract への影響なし**: `Risk:` フィールドが無い contract はレガシーモードで通過。新フィールドの追加は任意 (opt-in)。
- **`stack` 記述子**: 非コードリポジトリで compile 系チェックを waive する場合のみ、contract に `"stack": "docs"` 等を追加。
- **critical タスクを使う場合**: 証拠鍵 (`~/.sdd/evidence-key`) の生成と `Second Approval:` の人間記入が必要。
- 破壊的なファイル配置変更なし。プラグイン再インストール（ワンライナー再実行）で移行完了。

## v0.9.0

監査の残課題（C-04 / H-02 / H-04 / C-06 / H-06 / H-05）に対応したセキュリティ強化リリース。

### 新機能・強化

**署名付き sudo capability token (C-04)**: `SDD_SUDO` を偽造耐性のある署名トークン化。`issuer` / `nonce` (≥32 hex) / `repo`（プロジェクトルートの正規絶対パス）束縛 + HMAC-SHA256 署名 (`sig`) を追加。署名鍵はリポジトリ作業ツリーの**外**（`SDD_SUDO_KEY` / `SDD_SUDO_KEY_FILE` / `<HOME>/.sdd/sudo-key`）に置く。`sudo_active()` は py/js/ps1 共通で、非シンボリックリンク・必須フィールド・nonce 形式・`issued<=now<expires`・TTL≤24h・repo 一致・鍵で再計算した HMAC 一致をすべて満たす場合のみ有効化し、いずれか欠落で**フェイルクローズ**（承認ゲート維持＝バイパスは決して起きない）。偽造・コミット済み・他リポジトリからのコピー・リプレイを拒否。残存リスク（鍵を読めるエージェントは署名可）は `sudo-mode-policy.md` に明記。`/sdd-sudo` スキルが鍵生成（0600）と署名を行う。

**evidence の runner 生成・git SHA 束縛 (H-02)**: `generate-evidence-bundle.{sh,ps1}` を新設。証拠の SHA-256・`git_commit`(HEAD)・`git_generated_dirty` を自動算出してバンドルを生成（エージェントによる手書きを排除）。`check-evidence-bundle` は `git_commit` を必須化し、リポジトリ履歴に存在し HEAD の祖先（または HEAD）であることを検証（git 不在・検証不能はフェイルクローズ）。digest 束縛（成果物 SHA-256 一致）と併せ、捏造・古い・他コミット由来の証拠を拒否。

**Actions の SHA pin・release 署名・SBOM (H-04 / C-06)**: `test.yml` / `self-improvement.yml` の全 Action を commit SHA に pin（`# vX.Y.Z` コメント付き）。`.github/dependabot.yml` で pin を定期更新。`release.yml` を新設し、Release publish 時に再現可能ソース tarball・CycloneDX SBOM・`SHA256SUMS`・sigstore ベースの build-provenance attestation（keyless）を生成・添付。SBOM は `.github/scripts/generate-sbom.py`（stdlib のみ）が workflow の pin 済み Action から自動生成。

**installer の排他 lock (H-06)**: 同一インストール先への並行 install による stage→backup→swap 競合を防止。`install.sh` は atomic な `mkdir` lock ディレクトリ（macOS でも動くよう flock 非依存）、`install.ps1` はインストール先のハッシュで識別する名前付き Mutex。タイムアウト（`SDD_INSTALL_LOCK_TIMEOUT`、既定 120s）と stale 回収（`SDD_INSTALL_LOCK_STALE` / 死んだ pid）を備え、全 exit 経路で解放。タイムアウト時は install 先に触れずフェイルクローズ。

**outcome ベースの eval suite (H-05)**: `tests/eval.tests.sh` を新設。実際のゲート群（check-contract / check-placeholders / check-evidence-bundle / check-task-state / sdd-hook-guard）を good/completion-faking の 8 シナリオに対して実行し、Done 可否という**結末**を検証。CI (`test.yml`) に組み込み。

### 修正

- 承認ガードの穴を解消: Write content モードが `## T-NNN` セクション単位でしか比較せず、ヘッダ無しの `Approval: Approved` や新規 tasks.md がすり抜けていた問題を、ファイル全体の承認数の純増でも deny するよう py/js/ps1 で統一（per-task swap 検知は維持）。あわせて sudo テストの `issued-epoch` 欠落と、PowerShell の親ディレクトリ走査がルートで終端できず例外になる不具合を修正。

### WFI 承認の決定論的ガードを追加

- `docs/workflow-improvements/WFI-*.md` への `Status: Approved` のエージェント書き込みをフックガードが拒否（py / js / ps1 全ランタイム）。WFI 承認は **sudo でも解除されません**（タスク承認ガードと異なる点）。
- WFI テンプレートの Status を決定論的に検出可能なインライン `Status: <値>` 形式へ変更。
- `tests/guards.tests.sh` と `tests/hooks.tests.ps1` に WFI ガードのテストを追加。

### sudoモードの適用範囲を明確化（文書のみ・挙動変更なし）

- sudo が自動通過するのは **承認ゲートのみ** であることを明文化：tasks.md のタスク承認、quality-gate の定型サインオフ、`refactor`/`bugfix` の baseline 差分 `accepted` 承認。
- sudo が **通さない判断・統治** を第2の明示例外（brownfield と並ぶ）として明文化：`requires_human_decision: true` チケット、アーキテクチャ/認証/認可/breaking-API/セキュリティ決定、WFI 承認。AGENT_STOP・決定論的ゲートは従来どおり常時有効。
- `workflow-retrospective` と `fix-by-review-ticket` に `Sudo Mode` 節を追加し、quality-gate / implement-task / interviewer の `Sudo Mode` 節を承認と判断を区別する記述に更新。
- `/sdd-sudo` スキルに「How to Turn It On (Quick Start)」を追加し、入り方を明確化。
- 注: v0.7.0 で「アーキテクチャ review 承認も自動通過」と記載していたが、アーキテクチャ決定は承認ではなく判断のため sudo では通さない、と整理（ガードのコード挙動は不変）。

### v0.8.0 からの移行

- **sudo モードは鍵が必要に**: `/sdd-sudo` を再実行して鍵（`<HOME>/.sdd/sudo-key`）を生成し直してください。署名の無い・古い `SDD_SUDO` は無効（フェイルクローズ）として扱われます。CI 等で鍵を共有する場合は `SDD_SUDO_KEY` を設定。
- **evidence bundle は runner 生成必須**: `git_commit` フィールドが必須になりました。`generate-evidence-bundle.{sh,ps1}` で生成してください（手書きの sha256 / git_commit は不可）。
- **GitHub Actions は SHA pin**: タグ更新で自動追従しなくなります。更新は Dependabot（または手動で SHA + コメント更新）で行ってください。
- 破壊的なファイル配置変更はなし。プラグイン再インストール（ワンライナー再実行）で移行完了。
## v0.8.0

### 変更内容

- private repo 前提の remote install に対応。`install.sh` / `install.ps1` は `gh auth token` を使って GitHub API の archive を取得。
- `SourceDirectory` の既存テストを維持しつつ、認証済み remote path の mock テストを追加。
- README / troubleshooting を private 前提に更新。
- フックガードを fail-closed に変更し、agent role の更新・削除・shell 書き込みを拒否。
- `Done` 判定に SHA-256 付き evidence bundle を必須化。

### v0.7.0 からの移行

- `Done` タスクには `specs/<feature>/verification/<task-id>.evidence.json` が必要です。
- evidence bundle は quality report、verification contract、passing evidence の SHA-256 を記録します。
- malformed hook payload、guard runtime 不在、Copilot guard 不在は拒否されます。

## v0.7.0

### 新機能

**sudoモード**: 人間による明示的な `/sdd-sudo` 呼び出しで、人間承認ゲート（tasks.md の `Approval: Approved`、アーキテクチャ review 承認、quality-gate 判定）を期限付きで自動通過。AGENT_STOP kill switch と決定論的スクリプト（contract 検証、placeholder 検出、task-state 検証）は常に有効。audit trail には `(sudo <ISO8601>)` 記号で記録。使用は `/sdd-sudo [duration]`、`/sdd-sudo status`、`/sdd-sudo off`。詳細は `plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md` と `sudo-mode-policy.md` を参照。

**リポジトリ改名**: `sdd-plugins-windows-installer` から `sdd-forge` へ改名（自動リダイレクト）。

**週次セルフ改善ワークフロー**: `.github/workflows/self-improvement.yml` を新設。毎週月曜 09:00 JST に `anthropics/claude-code-action@v1` がリポジトリを監査し、Issue 起票と小さな改善 PR の作成までを自動実行する（人間はレビューとマージのみ）。実行指示は `.github/self-improvement-prompt.md` に置き、プロンプト自体も改善対象。認証は `claude setup-token` で発行した `CLAUDE_CODE_OAUTH_TOKEN` シークレット（Pro/Max サブスクリプション枠を消費、API 従量課金なし）。workflow-retrospective (WFI) ループとの競合は調停プロトコル（不可侵領域・台帳照合・WFI provenance・単一飛行・優先順位）で防止 — docs/workflow-guide.md「週次セルフ改善ルーチンとの境界と優先順位」参照。

### v0.6.2 からの移行

| v0.6.2 | v0.7.0 |
|---|---|
| sudoモードなし | **sudoモード追加**: 人間 `/sdd-sudo` 呼び出しで approval gate 自動通過。AGENT_STOP と決定論的ゲートは常に有効 |
| リポジトリ名 `sdd-plugins-windows-installer` | **改名**: `sdd-forge` へ移行（GitHub 自動リダイレクト対応） |
| 改善は人手起点のみ | **週次セルフ改善ワークフロー追加**: GitHub Actions が毎週監査 → Issue → 改善 PR を自動作成（要 `CLAUDE_CODE_OAUTH_TOKEN` シークレット） |

**破壊的変更**: なし。プラグインの再インストール（ワンライナー再実行)のみで移行完了。

## v0.6.2

### 変更内容

Codexエージェントロールファイルの検証・ガード・診断を追加。

## v0.6.1

### 変更内容

ハーネス監査に基づく信頼性修正リリース。機能追加はありません。

**強制レイヤの穴を修正**: Claude Code 用フックの承認ガードに `apply_patch` マッチャーを追加 (Codex 用設定との不一致でバイパス可能だった)。Copilot 用フックが `pwsh` のみの環境でフェイルオープンしていた問題を修正 (`pwsh` 優先 + `powershell.exe` フォールバック)。

**ガード4ランタイム (js/py/sh/ps1) の挙動統一**: `tasks.md` パス判定を全ランタイムで大文字小文字非区別に統一。Python ガードのキルスイッチ判定を stdin 読み込みより前に移動し、TTY ハングを防止。キルスイッチ単体スクリプトが `CLAUDE_PROJECT_DIR` とカレントディレクトリの両方を確認するよう統一。旧世代の `guard-task-approval.{sh,ps1}` (キルスイッチ/apply_patch 非対応) を削除。

**インストーラ修正**: `install.sh` がインストール先に `.codex/.codex/` 等の入れ子ディレクトリを作成するバグを修正。失敗時ロールバックを堅牢化 (Windows のファイルロックでも復元を試行)。エラー伝播を明示化。

**テスト/CI強化**: Linux (ubuntu-latest) を CI マトリクスに追加。`.gitattributes` で EOL を固定。Python ガード・キルスイッチ・MultiEdit ペイロード・インストーラ再実行冪等性・Copilot 登録の直接テストを追加。CI 失敗時のログアーティファクト保存を追加。

## v0.6.0

### 新機能

**brownfield導入サポート (`sdd-adopt`)**: プロジェクト開始後に SDD を採用する「brownfield導入」シナリオ向けスキル。`AGENTS.md` / `CLAUDE.md` / `docs/adr/` / `docs/review-tickets/` / `reports/` をスキャフォールドし、`specs/<feature>/adr/` などの旧配置 ADR を `docs/adr/` へ移行する。ホスト (GitHub / GitLab) に合わせたテンプレートを選択。

**構造プリフライトチェック (`check-sdd-structure`)**: `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh` / `.ps1` が必須ファイル・ディレクトリの有無を検査し `missing:` / `advisory:` / `drift:` / `host:` 行で報告。不足時は exit 1。`sdd-bootstrap-interviewer` が feature / bugfix / refactor モード開始時に自動実行し、不足があれば `sdd-adopt` の実行を促して停止する。

**implement-task / quality-gate の明示的前提条件**: `AGENTS.md` が存在しない場合、両スキルがガイダンス付きで停止し `sdd-adopt` の実行を促す。

### v0.5.0 からの移行

| v0.5.0 | v0.6.0 |
|---|---|
| brownfield導入の公式サポートなし | **`sdd-adopt` スキル追加**: `AGENTS.md`/`CLAUDE.md`/`docs/adr/`/`docs/review-tickets/`/`reports/` をスキャフォールド。ホスト (GitHub/GitLab) に合わせたテンプレートを選択。旧配置 ADR (`specs/<feature>/adr/`) を `docs/adr/` へ移行 |
| 構造チェックなし | **`check-sdd-structure.sh` / `.ps1` 追加**: 必須構造の有無を `missing:`/`advisory:`/`drift:`/`host:` 行で報告。不足時は exit 1 |
| interviewer がそのままインタビューを開始 | **プリフライト必須化**: feature / bugfix / refactor モードで `check-sdd-structure` を自動実行。不足があれば `sdd-adopt` を促して停止 |
| implement-task / quality-gate は AGENTS.md 不在でも継続 | **明示的前提条件**: `AGENTS.md` 不在時にガイダンス付きで停止し `sdd-adopt` を促す |
| ADR 配置が曖昧 | **ADR 正規配置を `docs/adr/` に統一** |

## v0.5.0

### 新機能

**macOS/Linuxインストーラ追加**: `install.sh` により `curl | bash` ワンライナーで macOS 13+ および Linux へ導入可能。フラグは PowerShell 版と対称 (`--target`, `--plugins`, `--install-root` 等)。

**Claude CodeフックのNode.js exec form化**: `hooks/claude-hooks.json` が `sh` 経由のシェル形式ではなく `node` コマンドの exec form を使用。Git Bash 不要の Windowsネイティブ対応を実現。

**CIをWindows+macOSマトリクスに拡張**: `.github/workflows/test.yml` が `windows-latest` と `macos-latest` の両方でテスト実行。`hooks.tests.ps1` を CI に追加。

**PS 5.1のTLS 1.2強制**: PowerShell 5.1 環境で `[Net.ServicePointManager]::SecurityProtocol` を TLS 1.2 に設定し、ダウンロード失敗を防止。

**check-task-state.shのmktemp化**: 競合状態を排除するため一時ファイルに `mktemp` を使用。

### v0.4.0 からの移行

| v0.4.0 | v0.5.0 |
|---|---|
| Windowsのみインストーラー (`install.ps1`) | **クロスプラットフォーム対応**: `install.sh` により macOS 13+ / Linux へ `curl \| bash` で導入可能 |
| Claude Codeフックが `sh` 経由のシェル形式 (Git Bash必須) | **Node.js exec form化**: `hooks/claude-hooks.json` が `node` コマンドの exec form を使用。Git Bash 不要 |
| CI は windows-latest のみ | **マトリクスCI**: `windows-latest` と `macos-latest` の両方で実行。`hooks.tests.ps1` を CI に追加 |
| PS 5.1でダウンロード失敗する場合あり | **TLS 1.2強制**: `[Net.ServicePointManager]::SecurityProtocol` を TLS 1.2 に設定 |
| `check-task-state.sh` が固定パス一時ファイル | **mktemp化**: 競合状態を排除 |

## v0.4.0

### 新機能

**Copilot CLI対応**: SKILL.md スキル、`*.agent.md` エージェント (`sdd-investigator` / `sdd-evaluator`)、`hooks/copilot-hooks.json` (preToolUse、stdout `permissionDecision` フォーマット)。`-Target Copilot` でインストール。

**Codex hooks/agents対応**: `hooks/hooks.json` に `command_windows` フィールドを追加し Windows Codex 環境をサポート。`apply_patch` ペイロードを処理する。`.codex/agents/` TOML エージェントをインストーラーが `~/.codex/agents/` へコピー。

**統一ガード `sdd-hook-guard`**: kill-switch とタスク承認チェックを1スクリプトに統合し、Claude Code / Codex / Copilot の3ランタイムで共通動作。

**check-contract / check-task-state 強化**: `waiver_reason` 必須化、証拠パストラバーサル防止、重複タスクID検出、実装レポート必須 (`Implementation Complete`)、`Blocked`/`Done` 検証強化。

**CIテンプレートのフェイルクローズ化**: `TODO_REPLACE_WITH_PROJECT_COMMANDS` マーカーにより未設定のまま CI が通過しない。

### v0.3.0 からの移行

| v0.3.0 | v0.4.0 |
|---|---|
| Claude Code のみ対応 | **Copilot CLI対応**: SKILL.md スキル、`*.agent.md` エージェント、`hooks/copilot-hooks.json` (preToolUse、既知の不具合: サブエージェント内) |
| Codex hookなし / エージェントなし | **Codex hooks/agents対応**: `command_windows` フィールド追加、`apply_patch` ペイロード処理、`.codex/agents/` TOML エージェント、インストーラーが `~/.codex/agents/` へコピー |
| 個別の kill-switch / guard スクリプト | **統一ガード `sdd-hook-guard`**: 3ランタイム共通、kill-switch + タスク承認チェックを統合 |
| check-contract / check-task-state 基本版 | **強化版スクリプト**: `waiver_reason` 必須化、証拠パストラバーサル防止、重複タスクID検出、実装レポート必須 (`Implementation Complete`)、`Blocked`/`Done` 検証強化、ベースライン必須セット保護 |
| CIテンプレートがコマンドなしで通過 | **フェイルクローズ化**: `TODO_REPLACE_WITH_PROJECT_COMMANDS` マーカーで未設定のまま通過しない |

## v0.3.0

### 新機能 (参考)

**調査フェーズ (investigate-codebase)**: `sdd-investigator` エージェントが読み取り専用でコードを解析し、`INV-xxx` 知見と `BL-xxx` 基線動作を生成する。

**refactorモード**: `sdd-bootstrap-interviewer` に追加。`baseline-behavior.md` が必須前提となり、受入条件を BL 同値として表現する。

**決定論的検証ゲート**: Default-FAIL 契約 (`verification-contract.json`)、`check-contract` / `check-placeholders` / `check-task-state` スクリプト (.sh / .ps1) により、エージェント自己申告に依存しない機械検証を実施する。

**独立 Evaluator**: `sdd-evaluator` サブエージェント (Claude Code) または新規セッション (Codex) が実装文脈を持たない状態で批判レビューを行う。

**Claude Code フック強制層**: `PreToolUse` フックがキルスイッチ (AGENT_STOP) と自己承認の強制ブロックを行う (現在は `hooks/claude-hooks.json` + `kill-switch.js` / `sdd-hook-guard.js` の Node.js exec form に移行済み)。

**ワークフローレトロスペクティブ**: `workflow-retrospective` スキルがリワーク指標を計測し、WFI (Workflow Improvement) 提案を人間承認ループで適用する。

### v0.2.0 からの移行

| v0.2.0 | v0.3.0 |
|---|---|
| bootstrap は3モード (project/feature/bugfix) | 4モード (+ `refactor`) |
| 調査フェーズなし | `investigate-codebase` (Stage 0) が追加 |
| `quality-gate` はエージェント自己申告を許容 | Default-FAIL 検証契約 + 決定論的スクリプトゲート |
| 独立レビューは任意 | `sdd-evaluator` サブエージェント (または新規セッション) が必須 |
| フックなし | `hooks/hooks.json` が承認ガード / AGENT_STOP を強制 |
| レトロスペクティブなし | `workflow-retrospective` + WFI ループが追加 |
