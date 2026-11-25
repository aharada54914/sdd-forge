# T-004 実差分の Shadow 検査（PR #976）

PR head `cc5872c29` と Actions のマージコミット `124c57a18` のツリーはともに `1cec1f4a4`。ローカルで同じツリーを PR base `2db182ad2` に対して検査し、48ファイルから8件を検出した。終了コードは0、判定は WARN、所要1,964 ms。レシートの各行にルール、位置、検査対象ファイルの SHA-256 を記録した。CI は Markdown をジョブの要約に書くため、この JSON はローカル再実行の記録である。[ガードレール実行](https://github.com/aharada54914/sdd-forge/actions/runs/45719350191)

| 用途 | 件数 | 判定根拠 |
|---|---:|---|
| 本番コード | 1 | `run-sdd-gate.mjs:96` にルールが指摘する `shell: true` が存在。実フィールドサンプル1件中、構文の誤検知0件。 |
| 過去の検証に保存したソース | 3 | いずれのコピーにも指摘の構文が存在する。2つの過去の検証ディレクトリ内にあるため、本番サンプルから除外した。 |
| 意図した違反の fixture | 4 | `tests/v2-agent-lint.test.mjs:30–35` が同じ4ルールの検出を要求する。本番サンプルから除外した。 |

`node --test tests/v2-agent-lint.test.mjs` は5/5成功。差分ハンク、変更した import の循環、抑止、waiver の有効期限、100ファイル3秒以内の各ケースを実行した。本番1件の観測値と3回の hosted SAST 無指摘から、利用者既定の strict への昇格は判定できない。

AC-007 の「663行維持」は `484cbe7ae`（v2.1.3）での値。本線コミット `51eab7219` の変更により、PR base と head はともに677行。両者の `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs` はバイト単位で一致する。独立ゲートでは「この PR が Layer 1 を変更していない」と「現在も663行」を区別する必要がある。
