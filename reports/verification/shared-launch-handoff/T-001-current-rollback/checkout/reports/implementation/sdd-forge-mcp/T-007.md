# Implementation Report: T-007

- Task ID: T-007
- Feature: sdd-forge-mcp
- Risk: medium
- Required Workflow: acceptance-first

## Target

`.github/workflows/test.yml` に `mcp-tests` ジョブ（3 OS マトリクス: `npm ci`
→ `tsc --noEmit` → `npm test`）、`dist-parity` ステップ（再ビルド +
`git diff --exit-code dist/`）、`npm audit --omit=dev --audit-level=high`
ステップを追加する（design.md「Deployment / CI Plan」、tasks.md T-007
Goal/Scope）。既存ジョブ（`test` / `cli-hook-enforcement` /
`required-checks`）は一切変更しない。

## Summary

- `.github/workflows/test.yml` の `test` ジョブと `cli-hook-enforcement`
  ジョブの間に新規 `mcp-tests` ジョブを追加した。
  - `strategy.matrix.os: [windows-latest, macos-latest, ubuntu-latest]`
    （`fail-fast: false`、既存 `test` ジョブと同じパターン）。
  - `defaults.run.working-directory: mcp/sdd-forge-mcp` を指定し、以降の
    全 `run:` ステップがこのディレクトリで実行される。
  - `actions/checkout` は既存ジョブと同一 SHA
    （`9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0` / v7.0.0）を再利用。
  - `actions/setup-node` を新規導入（`node-version: "20"`、
    `cache: npm`、
    `cache-dependency-path: mcp/sdd-forge-mcp/package-lock.json`）。
    SHA は `git ls-remote` で `v5.0.0` タグの実際のコミット
    （`a0853c24544627f65ddf259abe73b1d18a591444`）を確認した値を使用
    （後述 Working Notes 参照 — 初稿で誤った SHA を書いていたことに
    気づき修正した）。
  - `npm ci` → `npx tsc --noEmit` → `npm test` の3ステップ（AC-006:
    Windows ランナーでもパーサー・パス処理テストが通る。golden テストは
    `process.platform` 分岐でフィクスチャ比較に自動切替済みのため
    追加の分岐は不要）。
  - `dist-parity`（AC-010）は `matrix.os == 'ubuntu-latest'` の1回のみ
    実行する専用ステップとして追加（`npm run build` →
    `git diff --exit-code -- dist/`）。3 OS 全部で実行すると esbuild の
    出力が理論上プラットフォーム差異を持ちうる場合に誤検知するリスクが
    あるため、Linux 単独に絞った（このバンドルは実際には決定論的だが、
    タスク指示が「独立ジョブ、または ubuntu で1回」の選択を許容して
    いたため後者を採用）。
  - `npm audit --omit=dev --audit-level=high` も同じく ubuntu-latest のみ
    で実行（3 OS で重複実行する意味がない静的なセキュリティチェック）。
- 既存ジョブへの変更は一切なし（`git diff` で追加ブロックのみであること
  を確認、後述）。`required-checks` ジョブの `needs` 配列にも
  `mcp-tests` を追加していない — タスク指示が「既存ジョブ・既存ステップ
  を変更・削除しない（追加のみ）」と明示しており、`required-checks` も
  既存ジョブであるため、`needs` への追記は「変更」に該当すると判断し
  见送った（Unresolved Items に記録）。
- `mcp/sdd-forge-mcp/dist/index.js` を `npm run build` で再生成した
  （ソース変更なし、ビルド実行のみ）。

## Files Changed

- `.github/workflows/test.yml` — `mcp-tests` ジョブを新規追加（既存3ジョブ
  は無変更、追加のみ）
- `mcp/sdd-forge-mcp/dist/index.js` — `npm run build` で最新ソースから
  再生成（`src/` は無変更）。`mcp/` ディレクトリ自体が現時点で git 管理
  下に未追加（untracked）のため、この変更はコミットされておらず
  オーケストレーターの git add/commit 判断に委ねる。

## Tests Added Or Updated

コード（`src/`/`tests/`）の変更なし。CI ワークフローの追加のみのため
node:test 側の新規テストはなし。検証は以下のローカル実行で代替した:

- `npx tsc --noEmit`: エラーゼロ（変更前後とも）。
- `npm test`: **157 tests / 157 pass / 0 fail**（変更前後とも同一件数 —
  ワークフロー変更はテストコードに影響しない）。
- YAML 構文検証: `node -e "require('js-yaml').load(...)"`
  （プロジェクト既存の `js-yaml` 依存を利用、システム Python への
  影響を避けた — pyyaml が未インストールで `pip install` が
  externally-managed-environment エラーになったため）。パース成功、
  `jobs` キーが `['test', 'mcp-tests', 'cli-hook-enforcement',
  'required-checks']` の4つであることを確認。
- actionlint: 環境に未インストール（`which actionlint` で確認）。
  タスク指示の「なければ YAML パースのみで可」に従い、YAML パースの
  みで検証を完了した（Unresolved Items に記録）。

## Regression Tests Run

- `npx tsc --noEmit`（変更前ベースライン、変更後の最終確認の両方）:
  エラーゼロ。
- `npm test`（変更前後）: 157/157 pass、0 fail。
- `npm run build` を連続2回実行し `shasum -a 256 dist/index.js` を比較:
  両方とも
  `42ccf2f06ba6880dbc17f1ad528e35ea8c7d6d073c30749e20c446af38d9ec57`
  で完全一致（dist-parity が CI で通る前提条件 — ビルドの再現性を確認）。
- `npm ci --dry-run`: `up to date`（package-lock.json とのインストール
  整合を確認）。
- `npm audit --omit=dev --audit-level=high`: `found 0 vulnerabilities`
  （exit code 0）。

## Specification Differences

- `dist-parity` と `npm audit` の実行タイミングをタスク指示の選択肢
  （「独立ジョブ、または mcp-tests ジョブ内の ubuntu で1回」）のうち
  後者（`mcp-tests` ジョブ内、`if: matrix.os == 'ubuntu-latest'` の
  ステップ）とした。3 OS それぞれで重複実行する必要がない静的検証
  だと判断したため。独立ジョブに分離していない点がタスク指示の
  「または」の一方を選んだ設計判断であることを明記する。
- `actions/setup-node` の SHA 固定値は初稿では未検証の値を記載してしまい
  （ハルシネーション）、`git ls-remote` で実際のタグ SHA を確認した上で
  修正した。最終的な値は `a0853c24544627f65ddf259abe73b1d18a591444`
  （`v5.0.0` / `v5` 両タグが同一コミットを指すことを確認済み）。

## Unresolved Items

- **actionlint 未実行**: 環境に actionlint がインストールされておらず、
  タスク指示の「なければ YAML パースのみで可」に従って YAML 構文検証
  （`js-yaml` によるパース）のみで代替した。actionlint 固有の検査
  （`runs-on` の値検証、`if:` 式の型チェック等）は未実施。
- **`required-checks` ジョブへの `mcp-tests` 不算入**: タスク指示が
  「既存ジョブ・既存ステップを変更・削除しない（追加のみ）」と明示して
  おり、`required-checks` ジョブ自体が既存ジョブ（`needs: [test,
  cli-hook-enforcement]`）であるため、`needs` 配列への `mcp-tests`
  追加は「既存ジョブの変更」に該当すると判断し実施しなかった。この
  結果、`mcp-tests` が失敗しても `required-checks` は現状のブランチ
  保護の必須チェックとして `mcp-tests` の成否を見ない
  （`mcp-tests` 自体は独立した GitHub Actions のチェックとしては
  表示されるため、リポジトリ設定側で必須チェックに `mcp-tests` を
  個別に追加すれば実効的にブロック可能）。この判断がタスクの意図
  （CI 統合による品質担保）と整合するかは quality gate でのレビューを
  推奨する。
- **`dist/` の git 未追跡**: `mcp/` ディレクトリ全体が現時点で git
  管理下に無い（untracked）。そのため `git diff --exit-code -- dist/`
  を今回ローカルで実行しても差分検出の対象にならない（ファイルが
  そもそも追跡されていないため）。CI 上の `dist-parity` ステップが
  意味を持つのは、`mcp/` ディレクトリ（`dist/index.js` を含む）が
  コミットされた後である。今回はビルドの再現性（2回連続ビルドで
  ハッシュ完全一致）をもって「dist-parity が CI で通る前提条件」を
  満たしたことの代替確認とした。dist/ のコミットそのものはタスク
  指示により本タスクの範囲外（git add/commit はオーケストレーターが
  行う）。

## Quality Gate Focus

- `dist-parity` / `npm audit` を `mcp-tests` ジョブ内の ubuntu 条件分岐
  ステップとして実装した設計判断が、タスク指示の意図と整合しているか
  （独立ジョブへの分離を求めていないか）。
- `required-checks` の `needs` に `mcp-tests` を追加しなかった判断が
  「既存ジョブ変更禁止」の解釈として妥当か、それとも T-007 の目的
  （CI 統合によるブランチ保護の実効性）を損なっていないか。
- `actions/setup-node` の SHA 固定値の正当性（`git ls-remote` による
  検証のみで、GitHub 公式のリリースページ等での二重確認はしていない）。

## Working Notes

- 事前確認（acceptance-first の証跡）: `grep -n "mcp-tests"
  .github/workflows/test.yml` を変更前に実行し、exit code 1
  （該当行なし）で `mcp-tests` ジョブが存在しないことを確認した。
- 調査: `.github/workflows/test.yml` の既存 `test` ジョブは
  `actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0`（v7.0.0）
  を使用しているため、新規ジョブでも同一 SHA を再利用した。一方
  `actions/setup-node` は本リポジトリで初導入のため既存の参照値が
  なく、当初 SHA を記憶ベースで記載したところ、実際には存在しない
  （もしくは異なるタグの）コミットハッシュだったことに気づいた。
  `git ls-remote https://github.com/actions/setup-node.git
  refs/tags/v5.0.0` で実際の SHA
  （`a0853c24544627f65ddf259abe73b1d18a591444`）を確認し修正した。
  ハルシネーション防止のため、外部アクションの SHA 固定は必ず
  `git ls-remote` 等で実測することを今後も徹底する。
- 調査: `python3 -c "import yaml; ..."` がタスク指示の例示コマンドだが、
  この環境には pyyaml が入っておらず `pip install pyyaml` は
  externally-managed-environment エラーで拒否された。システム
  Python 環境を変更せず、プロジェクトが既に依存している `js-yaml`
  （`mcp/sdd-forge-mcp/node_modules/js-yaml`）を `node -e` から呼ぶ
  形で代替検証した。
- 調査: `mcp/sdd-forge-mcp/.gitignore` に「`dist/` is intentionally NOT
  ignored（ADR-0003、T-007 dist-parity のため）」という既存コメントが
  あり、design.md の想定（dist はコミット対象）と整合していることを
  確認した。ただし `mcp/` ディレクトリ自体が `git status --porcelain`
  で `?? mcp/sdd-forge-mcp/`（未追跡）と出たため、実際のコミットは
  本タスクの範囲外（オーケストレーターの判断）と理解した。
- 検証: `rm -rf dist && npm run build` を1コマンドとして実行しようと
  したところ、Fact-Forcing Gate（破壊的コマンド検知）でブロックされた。
  チェーンの前半 `rm -rf` がブロックされたため後半の `npm run build`
  も実行されなかったことを `ls -la dist/` と scratchpad への事前コピー
  のハッシュ比較で確認した上で、`rm -rf` を使わず `npm run build`
  単体（esbuild は `--outfile` を単純上書きするだけで削除ではない）を
  2回連続実行し、ハッシュが完全一致することでビルドの再現性を検証した。

## Session Handoff

- **Current status**: T-007 完了。`.github/workflows/test.yml` への
  `mcp-tests` ジョブ追加（既存ジョブは無変更を diff で確認済み）、
  YAML パース検証済み、`dist/index.js` を最新ソースから再生成し2回連続
  ビルドでハッシュ一致を確認済み、`npm audit --omit=dev
  --audit-level=high` で脆弱性ゼロを確認済み。tasks.md / plugins/ /
  src/ / tests/ は無変更。git commit / push は未実施（オーケストレーター
  に委ねる）。
- **Next action**: quality gate によるレビュー。特に「Quality Gate
  Focus」節の3点（dist-parity/npm audit の配置、required-checks
  への不算入、setup-node SHA の妥当性）を確認してほしい。
- **Unresolved items**: 上記「Unresolved Items」参照
  （actionlint 未実行、required-checks 不算入、dist/ 未コミットによる
  dist-parity の実地未検証）。
