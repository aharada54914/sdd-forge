# HUMAN APPLY STEP — epic-192-a4-facet-manifest CI staging

## ステージング候補の場所（正規パス）

本 feature の CI 候補は正規の human-copy staging パスにあります:

- `specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml`
- `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256`

以前ここに置かれていた `github-workflows-test.yml.PROPOSED` は、旧 guard が
human-copy staging への書き込みを誤って拒否していた時期の回避ファイルであり、
廃止しました。現行の installed guard (sdd-quality-loop v1.10.0+) は
`specs/<feature>/human-copy/` への staging 書き込み免除を持つため、
候補は正規パスに直接置かれています。

## 候補の内容（FINAL — 全六スイート、T-001..T-005 完了）

ベース: live `.github/workflows/test.yml`
（2026-08-17 時点、origin/main マージ後の sha256
`486828f097e12ff99a44afd113df7a2347578b74c872253e858311c1d6fe898d`、
T-002 実装開始時点で live 側との差分なしを再確認済み）

変更は **純挿入 5 箇所のみ**（削除・並べ替えなし）:

1. epic-191 A3 ブロック末尾の
   `Test component-path-ownership parity suite (pwsh)` step の直後に、
   T-001 の 2 スイート × (bash/pwsh) の 4 step（+29 行）:
   - `Test facet-manifest-schema suite (bash)` / `(pwsh)`
   - `Test facet-manifest-semantics suite (bash)` / `(pwsh)`
2. その直後に、T-002 の 1 スイート × (bash/pwsh) の 2 step（+19 行）:
   - `Test capability-summary-schema suite (bash)` / `(pwsh)`
3. その直後に、T-003 の 1 スイート × (bash/pwsh) の 2 step（+20 行）:
   - `Test context-projection-schema suite (bash)` / `(pwsh)`
4. その直後に、T-004 の 1 スイート × (bash/pwsh) の 2 step（+21 行）:
   - `Test facet-manifest-staleness suite (bash)` / `(pwsh)`
5. その直後（`mcp-tests` ジョブの手前）に、T-005 の 1 スイート ×
   (bash/pwsh) の 2 step（+23 行、うちコメント13行）:
   - `Test facet-manifest-parity suite (bash)` / `(pwsh)`

計 +112 行（live 1055 行 → staged 1167 行、実測差分で確認済み）。六スイート
全て `tests/run-all.{sh,ps1}` に登録済みで、決定論的（LLM なし・ネットワーク
なし・`gh` なし・live sudo grant なし）です。これが本 feature（epic-192-a4-
facet-manifest, T-001..T-005）の最終・完結した CI staging 候補です。

## 適用手順（人間がエージェントセッション外で実行）

```sh
cd <repo root>
cp specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml \
   .github/workflows/test.yml
```

## 適用後の検証

```sh
shasum -a 256 .github/workflows/test.yml
# 期待値（MANIFEST.sha256 と一致すること）:
# 23437fffffcf4be43734b29fc242667d8534e4b75877db789d2b1a7205615f38
```

適用後、`tests/run-all.sh`/`.ps1` を再実行して全六スイートが green であることを
確認してください:

```sh
bash tests/facet-manifest-schema.tests.sh
bash tests/facet-manifest-semantics.tests.sh
bash tests/capability-summary-schema.tests.sh
bash tests/context-projection-schema.tests.sh
bash tests/facet-manifest-staleness.tests.sh
bash tests/facet-manifest-parity.tests.sh
```

注意: 適用前に live `.github/workflows/test.yml` の sha256 が上記ベース値と
異なる場合、live 側が先に進んでいます。その場合は本候補を最新 live を
ベースに再構築してから適用してください（挿入内容は上記 5 箇所・全10 step
のみ）。
