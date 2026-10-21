# リリース手順（コントリビューター向け）

このドキュメントは、sdd-forge のリリース手順と、リリースパスに組み込まれた
ループスイート・ゲート（Issue #148, epic-159-pillar-b）の挙動を記述します。
一般的なリポジトリ概要は [README.md](../../README.md) を、バージョン変更の
履歴は [CHANGELOG.md](../../CHANGELOG.md) を参照してください。

## ループゲートの概要

`tests/loop-consistency.tests.sh` と `tests/loop-inventory.tests.sh`
（以下「ループスイート」）は、レビュー/ゲートループのレジストリ整合性と
ループ駆動の一貫性を検証する既存の回帰スイートで、`test.yml` の push/PR ごとに
3-OS マトリクスで既に実行されています。epic-159-pillar-b は、この2スイートの
合格をリリースパス自体の前提条件として明示的に組み込みます。二本の独立した脚
（leg）で構成されます:

- **CLI 脚**（本ドキュメントの本節、T-001）: `scripts/bump-version.sh`
  自体が、バージョン文字列を書き換える前に両スイートを実行します。
- **CI 脚**（`.github/workflows/release.yml` の必須 `loop-gate` ジョブ、
  T-002）: 詳細は [release.yml セクション](#releaseyml-の-loop-gate-ジョブ) を
  参照してください。

いずれの脚も、ループスイート自体のロジックを再実装せず、実スイートを
読み取り専用で駆動してその終了コードのみを消費します。

## `scripts/bump-version.sh` のループゲート前提条件

### 挙動

`scripts/bump-version.sh <new-version>` は、以下の順で前提条件を評価します
（`scripts/bump-version.sh:38-55`）:

1. **CHANGELOG 見出しチェック**（既存、本タスクでは不変更）: `CHANGELOG.md`
   に `## v<new-version>` 見出しが存在しない場合、fail-closed で停止します。
2. **ループゲート前提条件**（本タスクで追加、Issue #148）: 見出しチェックの
   直後・全ミューテーションステップ（プラグインマニフェスト・
   `README.md`・`tests/validate-repository.ps1` 等の書き換え、
   `scripts/bump-version.sh:57-` 以降）より前に、`tests/loop-consistency.tests.sh`
   と `tests/loop-inventory.tests.sh` を `$ROOT` 相対パスで順に実行します。
   いずれかのスイートが非 0 終了した場合、`scripts/bump-version.sh` は
   **リリース面を一切変更せずに** exit 1 で停止し、失敗したスイートの
   出力をそのまま表示します。

この前提条件は既存の CHANGELOG 見出しチェックを緩めるものではなく、単に
新しい前提条件を追加するだけです。両方の前提条件を満たさない限り、
どのリリース面（プラグインマニフェスト、マーケットプレース、README、
バリデータ等）も書き換えられません。

### バイパスは存在しない

環境変数・CLI フラグ・その他の条件分岐によって、このループゲート前提条件を
スキップする手段は一切ありません（fail-closed、no override — 本リポジトリの
既存ガード方針と一致）。`tests/bump-version-gate.tests.sh` / `.ps1` の
TEST-004 が、実スクリプトソースへの grep 自己チェックでこれを継続的に
ロックしています。

### 検証方法

`tests/bump-version-gate.tests.sh` / `.ps1` は、実リポジトリを一切変更せず、
tar-copy + ローカル `git init` によるフィクスチャリポジトリコピー上で実
`scripts/bump-version.sh` を駆動します:

- **green path**（TEST-001）: 両ループスイートをトリビアルに合格するスタブへ
  差し替え、`scripts/bump-version.sh` が exit 0 でリリース面を新バージョンへ
  書き換えることを確認します。
- **red path**（TEST-002, TEST-003）: `tests/loop-consistency.tests.sh` /
  `tests/loop-inventory.tests.sh` のいずれか一方だけを失敗するスタブへ
  差し替え、`scripts/bump-version.sh` が exit 非 0 で停止し、
  `git status --porcelain` がゼロ差分（リリース面の変更なし）であることを
  それぞれ独立に確認します。

これらは `tests/run-all.sh` / `.ps1` と `.github/workflows/test.yml` に
登録済みで、通常の push/PR CI で継続的に実行されます。

## クロスホストの degradation（REQ-004）

`scripts/bump-version.sh` に `.ps1` ツインは存在しません。これは意図的な
設計判断です: `scripts/bump-version.sh` はリリース担当者が手元で実行する
CLI であり、本リポジトリのテストスイートに課される `.sh`/`.ps1` ツイン
義務の対象ではありません（`constant-parity.tests.sh` / `crlf-parity.tests.sh`
等のツイン整合性スイートも、対をなさないスクリプトを対象外として扱います）。

**Windows ホストでリリース版バンプを直接実行することはできません。**
Windows ホストのコントリビューター、および `release.yml` を起動するあらゆる
CI 環境は、代わりに `.github/workflows/release.yml` の必須 `loop-gate` ジョブ
（[release.yml セクション](#releaseyml-の-loop-gate-ジョブ) 参照、T-002）が
提供する同等の保証に依拠します。`loop-gate` ジョブは `ubuntu-latest` 上で
同じ2つのループスイートを実行し、既存のビルドジョブ（tarball / SBOM /
checksum / sigstore attestation / アップロードチェーン）はそのジョブへの
`needs:` 依存によって、両スイートが合格しない限り一切実行されません。

したがって、CLI 脚（bash のみ）と CI 脚（ホスト非依存）を合わせることで、
「ループスイートが red のままリリース面が更新される」経路は、実行環境を
問わず構造的に閉じられています。

## `release.yml` の `loop-gate` ジョブ

### 挙動

`.github/workflows/release.yml` は、既存のビルドジョブ（`release:`、tarball
生成・CycloneDX SBOM 生成・SHA-256 チェックサム発行・sigstore keyless
build-provenance attestation・リリースアセットのアップロードを担う）に加えて、
必須ジョブ `ci-green` と `loop-gate` を持ちます:

- **`loop-gate` ジョブ**: `ubuntu-latest` 上で、リポジトリをチェックアウトした
  のち `tests/loop-consistency.tests.sh` と `tests/loop-inventory.tests.sh` を
  順に実行します。いずれかのスイートが非 0 終了した場合、GitHub Actions の
  通常のジョブ失敗としてこのジョブ自体が失敗します。
- **`ci-green` ジョブ**: タグが指すコミットと同じ SHA の `test.yml` が成功済みであることを GitHub API で確認します。別コミットの成功や実行中の結果では先へ進みません。
- **ビルドジョブ（`release:`）**: `needs: [ci-green, loop-gate]` 依存を持ちます。GitHub Actions のジョブ依存セマンティクスにより、
  `loop-gate` ジョブが成功しない限り、tarball / SBOM / checksum /
  attestation / アップロードのいずれのステップも一切実行されません。

`release.yml` のトリガー面（`release: [published]` および
`workflow_dispatch`、`release.yml:10-13`）自体は本タスクで変更していません。
タグの push だけでは `release.yml` は起動しません。GitHub Release の公開、
または対象 ref を指定した `workflow_dispatch` が別途必要です。起動時には
`ci-green` が同じコミットの CI 成功を確認し、`loop-gate` がループスイートを
独立して実行します。タグ公開と配布アセットの作成結果は分けて記録してください。

### 権限（no elevated permissions）

`loop-gate` ジョブは、リポジトリのチェックアウトとローカルスクリプトの実行
のみを行い、GitHub リリースアセットのアップロードや sigstore 署名は行いません。
ワークフロー全体のトップレベル `permissions:` ブロック（`contents: write` /
`id-token: write` / `attestations: write`、既存ビルドジョブが必要とするスコープ）
をジョブが暗黙に継承すると、不要な昇格権限を持つことになるため、`loop-gate`
ジョブ自身に `permissions: contents: read` を明示的に上書き指定しています
(`release.yml:32-39`)。これにより、`loop-gate` ジョブの権限面はビルドジョブより
狭く、リリースパスの権限サーフェスを広げることなくゲートが追加されています。

### バイパスは存在しない

`release: needs: loop-gate` を外す、または `loop-gate`/`release` いずれかの
ジョブに `continue-on-error: true` や `if: always()` / `if: success() ||
failure()` を追加することで、このゲートを無効化できる可能性があります
(weakened-gate threat)。`tests/release-loop-gate.tests.sh` / `.ps1` の TEST-008
が、これらのエスケープハッチが両ジョブのいずれにも存在しないことを継続的に
ロックしています。

### 検証方法

`tests/release-loop-gate.tests.sh` / `.ps1` は、実 `release.yml` を一切変更せず、
テキストマーカー技法（`tests/workflow-state-ci-integration.tests.sh` の技法を
踏襲）で構造を検証します:

- **TEST-007**: `loop-gate:` ジョブのテキストスライス内に、
  `tests/loop-consistency.tests.sh` と `tests/loop-inventory.tests.sh` の
  両方の呼び出し文字列が存在することを確認します。
- **TEST-008**: `release:` ジョブのテキストスライス内に `needs: loop-gate`
  エントリが存在すること、かつ両ジョブのいずれのスライスにも
  `continue-on-error: true` や `if: always()` / `if: success() || failure()`
  が存在しないことを確認します。
- **TEST-009**（negative-branch canary）: `release.yml` の mktemp フィクスチャ
  コピーから `needs:` 行をテキストで除去し、TEST-008 と同一のチェック関数を
  再適用して、非準拠と判定されることを確認します — これにより TEST-008 の
  アサーションが空虚でないことを証明します。
- **TEST-010**: `loop-gate:` ジョブのテキストスライスが `runs-on:
  ubuntu-latest` のみを宣言し(`strategy:`/`matrix:` キーを持たない)、
  かつ `tests/release-loop-gate.tests.sh` / `.ps1` 自身が `tests/run-all.sh` /
  `.ps1` と `.github/workflows/test.yml` に登録されていることを確認します。

これらは `tests/run-all.sh` / `.ps1` と `.github/workflows/test.yml` に
登録済みで、通常の push/PR CI で継続的に実行されます。

## 検証済みコミットへのタグ付け

1. リモートの既存タグと現在のマニフェストを確認し、未使用のバージョンを選びます。
2. CHANGELOG に実際の変更と未検証事項を記載してから `bash scripts/bump-version.sh <version>` を実行します。
3. 通常の回帰検証とリリース検証を実行し、変更をコミットします。
4. 公開済みの対象ブランチで `test.yml` を実行し、そのコミット SHA の成功を確認します。main 以外のブランチは push だけではこのワークフローが起動しないため、`workflow_dispatch` を使います。
5. その SHA に注釈付きタグ `v<version>` を作成して公開し、リモートの peeled commit が一致することを確認します。既存タグの付け替えや強制 push は行いません。

順序の補足（最終コミットを F とする）:

現在、ci-model-modernization の T-010 比較試行は認証エラーで停止しており、
T-011 は進行中です。候補モデルの採用、CI カテゴリの有効化、新しいバージョンや
タグの公開は未実施です。以下は、残る検証を終えて公開するときの手順です。
新しい CI 設定を使う PR では、先に信頼済みベースの planner を対応版へ更新します。
旧版による設定の拒否は full 強制でも解消しないため、対応するツールを揃えた
revision で手動 full を確認してください。

1. docs と version（CHANGELOG の Unreleased を含む）を先に確定し、curated な最終コミット F を作ります。
2. F で、隔離した checkout のローカル full と、実際の hosted full を実行します。fixture の結果は hosted の観測の代わりになりません。
3. リリース対象コードの必須チェックを通してから、F に新しい注釈付き不変タグ `v<version>` を作ります。既存タグは変更せず、リモートの既存タグが変わっていないことも確認します。
4. PR のテスト済みマージ revision と release F は別物です。branch 名での `workflow_dispatch` は raw SHA の指定ではないため、対象 ref が F を指し、実際の CI head SHA も F と一致することを確認します。merge_group の限界（OQ-001）は残ります。
5. タグは Release アセットの公開を意味しません。実クラウド受け入れ（#911）は未了のままです。

公開記録にはタグ、コミット、CI の URL、配布アセットの作成有無を残します。
クラウド対応の fixture 検証は実環境での IAM・デプロイ・ヘルス検証の代わりに
ならないため、実クラウドの未実行項目も別に記録します。

## Cloud release publication boundary

Use tests/verification-catalog.json and its consuming verification.py /
verification-workflow.py drivers, not a second inventory. After a task-scoped bump,
root commits the complete curated candidate, runs the full suite in an isolated exact
checkout and dispatches test.yml at that same commit (full coverage; no selected-test
release shortcut). Preserve required-checks and all native OS lanes. Record actual
CI URL, commit, OS results, annotated remote tag/peeled commit and assets status in
reports/verification/cloud-orchestration-release.md only after each action succeeds.
Never overwrite tags, auto-merge, or imply that a tag publishes Release assets.

Exclude private native-events.jsonl and native-stderr.log explicitly from staging
and publication: the root .gitignore verification/*.log negation overrides local
exclude assumptions. Inspect exact staged paths, not just git status. Do not stage
account metadata or raw provider responses. Public API snapshots need upstream
license/attribution notices; full AWS documentation HTML without established
redistribution permission stays private, with source URL/digest addenda instead.
Frozen local reports/snapshots are not rewritten to pretend every input ships.

Carry forward T-006 attempt-3/network-isolation.md: earlier fixture aliases may have
attempted unauthenticated read-only Azure HTTPS with a synthetic token/fictional
subscription; delivery/count unknown, no authenticated success/write. Affected old
aggregate PASS is invalid guard evidence. Final guarded suites prohibit urllib I/O
including subprocess and rollback paths. This is not live acceptance.
TEST-003/005/009 and affected task Done remain BLOCKED pending authorized sandbox.
A release tag is not production-readiness approval.

`gh workflow run --ref` の引数は branch/tag 名です（raw commit SHA ではありません）。
release test.yml は operator-selected protected ref が対象コミットを指すことを確認し、
実際の CI head SHA も一致させます。cloud workflow の CONTROL_REF も同様ですが、
外部 Policy.workflow_revision / native workflow_sha の exact W 検証は維持します。
