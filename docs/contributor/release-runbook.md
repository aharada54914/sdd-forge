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
  T-002）: 詳細は [release.yml セクション](#release-yml-の-loop-gate-ジョブ) を
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
（[release.yml セクション](#release-yml-の-loop-gate-ジョブ) 参照、T-002）が
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
新規の必須ジョブ `loop-gate` を持ちます（`release.yml:31-48`）:

- **`loop-gate` ジョブ**: `ubuntu-latest` 上で、リポジトリをチェックアウトした
  のち `tests/loop-consistency.tests.sh` と `tests/loop-inventory.tests.sh` を
  順に実行します。いずれかのスイートが非 0 終了した場合、GitHub Actions の
  通常のジョブ失敗としてこのジョブ自体が失敗します。
- **ビルドジョブ（`release:`）**: `needs: loop-gate` 依存を持ちます
  (`release.yml:51`)。GitHub Actions のジョブ依存セマンティクスにより、
  `loop-gate` ジョブが成功しない限り、tarball / SBOM / checksum /
  attestation / アップロードのいずれのステップも一切実行されません。

`release.yml` のトリガー面（`release: [published]` および
`workflow_dispatch`、`release.yml:10-13`）自体は本タスクで変更していません。
`test.yml` の実行有無に関わらず、`release.yml` が起動するたびに `loop-gate`
ジョブ自身が独立してループスイートを実行します — タグを直接 push した場合や
古い ref に対する `workflow_dispatch` の場合でも、この保証は成立します。

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
