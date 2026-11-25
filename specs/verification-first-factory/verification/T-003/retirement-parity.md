# T-003　既存テストの廃止候補と検知パリティ

2026-11-26。比較元は `e9f3e3e00cb85d4c039d88582d7ba541925c3d00`。以下の実行結果は、その作業ツリーに README 固定行の後継検査と文書リンクの修正を加えた状態で取得した。

## 候補と承認状況

`docs/architecture/verification-first-concept.md:35–42` にあるファイル名の例を Git の追跡ファイルに展開した。カテゴリ1に28件（うち `resolve-project-context*` は補助 Python 8件を含む）、カテゴリ4に8件が該当する。末尾の一覧は比較対象の特定に用いる。`CODEOWNERS:14` の所有者は `@aharada54914`。`sdd/approved-test-retirements.json` の `retirements` は空で、個別承認は0件。テスト廃止は0件。廃止による所要時間の削減は計測していない。

| 候補 | 対象の実態 | 結果 |
|---|---|---|
| `tests/resolve-project-context*` | `plugins/sdd-quality-loop/scripts/resolve-project-context.{py,ps1,sh}` が現存。8組が CLI、呼出元契約、探索、分類、パリティ等を検査 | 個別に v1 機能廃止を立証できていない |
| `tests/human-copy-runner-contract.tests.sh` | 実行先 `tests/human-copy-runner-contract.tests.ps1` は `220f60afd` で削除。検査対象の `specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1` は現存 | 呼出先が欠けた候補。旧機能の廃止と、残すべき過去の適用証跡の扱いを要確認 |
| `tests/human-copy-mirror-freshness.tests.ps1` | `scripts/human_copy_mirrors.py` が現存。`220f60afd` が削除したのは `.sh` 側 | ファイル単位の廃止を立証できていない |
| `tests/rollback-1.5.0.tests.*` | テスト対象 `scripts/rollback-1.5.0.{ps1,sh}` が現存 | 古いバージョン名だけでは廃止の判断ができない |
| `tests/doc-diagrams.tests.*` | `.sh` と `.ps1` は同一の `.py` を実行。README 固定行、相対リンク、Mermaid 構文・固定版、ワークフロー図の固定行を検査 | README の固定行のみ後継で対応を確認。2つのホストラッパーの起動エラーや実行環境までは比較していない |
| `tests/check-placeholders*` | 現行の `.sh`／`.ps1` を実行し、違反・クリーン・ツールエラーの終了値とメッセージ、ファイル範囲等を確認 | `.ps1`／`.sh` 固有の契約を含み、後継の全失敗モード対応は未実証 |
| `tests/render-agent-frontmatter.*` | 現行レンダラー、`--check`、出力差分、保護対象、モデル設定等を検査 | 現行レンダラーの各契約について後継との並走が必要 |

`specs/verification-first-factory/requirements.md:27–30,60` に従い、機能自体が廃止済みのカテゴリ1だけにミュータント要件の例外がある。今回、個別テストを廃止できることを示したケースは0件。`constant-parity` は構想文書上のカテゴリ2に属する。

## 過去のカタログ整理

`ad223a0b10e391a5d16413f2da014810299c76cb`（`40eec6263^`）の `tests/verification-catalog.json` に登録された一意の `suites[].path` は424件。`git ls-tree -r --name-only` で同じコミットと突合すると77件が欠損している。`40eec6263` の登録は347件で欠損0件。取り除かれた77パスはすべて、変更前からファイルが欠けていた。構想文書の歴史的な集計では56件を挙げている。今回の統合後の分類は348件、欠損0件。

## README 固定行の実行結果

旧実装は `tests/doc-diagrams.tests.py:102–108`。後継は `tests/self-fitness.test.mjs` の `hasPinnedReleaseLine`。旧 CLI の `--root` に指定した一時ディレクトリの同じ `README.md` を両実装に渡し、次の結果を得た。負例では旧 CLI の専用エラーメッセージも照合した。

| 一時ファイルの入力 | 旧 CLI 終了値 | 後継 |
|---|---|---|
| 5行目に `v1.2.3 — Release` | 0 | 受理 |
| 同じ行が6行目にある | 1 | 検出 |
| 5行目でパッチ番号が欠ける | 1 | 検出 |
| 5行目でダッシュの種類が違う | 1 | 検出 |

`rtk proxy node --test tests/self-fitness.test.mjs` は9/9、`rtk proxy python3 tests/verification-catalog.tests.py` は22/22。固定行だけの比較は `rtk proxy node --test --test-name-pattern='pinned README|legacy doc-diagrams' tests/self-fitness.test.mjs` で再実行できる。

## 文書検査の差異

旧検査で見つかった相対リンク切れ4件は `docs/README.md`、`docs/agent-capability-matrix.md`、`docs/architecture/overview.md`、`docs/contributor/coding-standards/audit/typescript/contextual-follow-up.md` にあった。現行の案内は ADR-0051、過去の説明は v1.26.0 または監査時のコミットを参照するように修正した。Git の当該オブジェクトでパスと監査対象テキストを確認した。

`rtk proxy env DOC_DIAGRAMS_REQUIRE_MERMAID=1 python3 tests/doc-diagrams.tests.py --no-selftest` で README・docs 配下の259文書と16図を検査した。相対リンクと図中の固定バージョンは各0件。旧検査は `docs/workflow-guide.md` に v1 の描画 ID に依存する固定行を要求する。現行 `plugins/sdd-ship/skills/ship/SKILL.md:26,67` が定める回顧は、全対象タスクが Done になり `--retro` が指定されたときだけ実行する。現行ガイドにこの条件を明記した。`tests/workflow-documentation.tests.sh:28` も同じ旧文字列を期待しており、両方の固定行契約が残る。

初回の厳格パースでは `docs/architecture/mcp-v2-spec.md` の `createFsReadonlyIo(root)` を含む矢印ラベルで構文エラー1件を検出した。同じ図の関数名を含む2つの矢印ラベルを引用符で囲んだ。修正後、`rtk proxy env DOC_DIAGRAMS_REQUIRE_MERMAID=1 python3 tests/doc-diagrams.tests.py` で負例の内蔵セルフテストも実行した。259文書の相対リンク切れ0件、Mermaid 16/16 構文成功、図中の固定版0件。旧スイート全体の終了値は **1**、残る指摘はワークフローの旧固定行のみ。後継の Self-Fitness は **9/9 成功**。README の並走テストはこれらの失敗モードを検査対象にしていない。

追検証では、図に「全対象タスクが Done」「ship に `--retro` を指定」の2条件を示したうえで、旧検査からも識別できる `P --> W[workflow-retrospective]` の接続を復元した。上記の厳格コマンド（内蔵の負例を含む）は終了0。259文書・16図・固定アンカーの全検査が成功した。別スイート `bash tests/workflow-documentation.tests.sh` は、README に旧コマンド `spec-review-loop` の記載を求める先行検査で終了1だった。


## 比較した Git blob

`git ls-tree e9f3e3e00cb85d4c039d88582d7ba541925c3d00:tests` で追跡パスと SHA を再確認できる。

| カテゴリ | ファイル | Git blob SHA |
|---|---|---|
| 4 | `tests/check-placeholders-brownfield.tests.ps1` | `f8107fb814ea0bda81fcfd95d3e5e7292e260549` |
| 4 | `tests/check-placeholders-brownfield.tests.sh` | `37aad0ca12f037f16eca57f15fc712231d3a6e33` |
| 4 | `tests/check-placeholders.tests.sh` | `dedc2053f410fbf4b75833f93185824f9ebf3070` |
| 4 | `tests/doc-diagrams.tests.ps1` | `d71501c7e7c45049b4d8795090001cba25667347` |
| 4 | `tests/doc-diagrams.tests.py` | `e6834bc728c95e6aa500722eda951ec1cabba868` |
| 4 | `tests/doc-diagrams.tests.sh` | `5c0167062c69fe2507faea63e056d62ac6971261` |
| 1 | `tests/human-copy-mirror-freshness.tests.ps1` | `0a8fc28f97b0c09bc0d88c25fc1c78fd957a39ff` |
| 1 | `tests/human-copy-runner-contract.tests.sh` | `9acadde516fb6a79c3340e8efb61bdbd32c85433` |
| 4 | `tests/render-agent-frontmatter.tests.ps1` | `77c9592798171d4d4b7fa849409db5d82e2cce6f` |
| 4 | `tests/render-agent-frontmatter.tests.sh` | `dfa9592ada5ab3804a3b895a1f33568c36912311` |
| 1 | `tests/resolve-project-context-block-check.py` | `2b84625682f0920d8372c9bdcc9a5f88763ccc57` |
| 1 | `tests/resolve-project-context-block.tests.ps1` | `9bc19c1b329dd678ed3251a676ba241f9ab3c14b` |
| 1 | `tests/resolve-project-context-block.tests.sh` | `f67b3cb86948b75c98814d1eeb1cb31ced4404fe` |
| 1 | `tests/resolve-project-context-caller-contract-check.py` | `1375ab32a4eca38205b8470022454d359a1e8f2c` |
| 1 | `tests/resolve-project-context-caller-contract.tests.ps1` | `b9e4ada77f2a7a85e4523989722e1a83985be570` |
| 1 | `tests/resolve-project-context-caller-contract.tests.sh` | `8503666a924cb1f021c6d92e00bb68d780156d1a` |
| 1 | `tests/resolve-project-context-cli-check.py` | `1c53ab2ded7df474df9289b793c6e848e41b4fe8` |
| 1 | `tests/resolve-project-context-cli.tests.ps1` | `1ce3689ab6c8c759a578c347e9fdcffe623792d1` |
| 1 | `tests/resolve-project-context-cli.tests.sh` | `4484252c8ee61e7cf724d185acba1b49bd41c094` |
| 1 | `tests/resolve-project-context-discovery-check.py` | `381c2a0591fa12afd7f352536ddb8ecdcd218118` |
| 1 | `tests/resolve-project-context-discovery.tests.ps1` | `68fa24edd18a4174866ef24432c6bc43af3d9a60` |
| 1 | `tests/resolve-project-context-discovery.tests.sh` | `e64e14544fad79c91913a94406eab0e413122d4e` |
| 1 | `tests/resolve-project-context-lite-check.py` | `bb4a0ba7c833a75a9494752f336192ddb1ffb811` |
| 1 | `tests/resolve-project-context-lite.tests.ps1` | `f6d4664145ae7245d79d6713bb9c688fd7203be7` |
| 1 | `tests/resolve-project-context-lite.tests.sh` | `d1ba11bbaee675937f2c3f786a07d0c464b6f92f` |
| 1 | `tests/resolve-project-context-match-check.py` | `3dbb8584c78f806d05386495c0623573d94cf3e7` |
| 1 | `tests/resolve-project-context-match.tests.ps1` | `3845def4f2200c50bce1fccc525f4301bf86fc6f` |
| 1 | `tests/resolve-project-context-match.tests.sh` | `e96d3ab3e1d32fc17948a33dda5e65eda159ae99` |
| 1 | `tests/resolve-project-context-metamorphic-check.py` | `0cfd7164dca06ee502206ecfa21013ae69acbcae` |
| 1 | `tests/resolve-project-context-metamorphic.tests.ps1` | `7dfe093e9d58714b2cee0739a8f82c1236760fd7` |
| 1 | `tests/resolve-project-context-metamorphic.tests.sh` | `98a7c6de98085276293aae9f61eba2a2b229d33b` |
| 1 | `tests/resolve-project-context-parity-check.py` | `57887f89b1f82c42db2d7e0ea34a352f75c40b84` |
| 1 | `tests/resolve-project-context-parity.tests.ps1` | `cf550c7377c1ee97725b3a730695ca6885e21d3c` |
| 1 | `tests/resolve-project-context-parity.tests.sh` | `17e90d223fefb2a8c4ea2ed73931bc2c0299cea1` |
| 1 | `tests/rollback-1.5.0.tests.ps1` | `cb9f58fe4a8bed48dbc64b04b32d7e8ec2759bf0` |
| 1 | `tests/rollback-1.5.0.tests.sh` | `d22d28e22ade07f95188592a88b7c582d40a6de1` |
