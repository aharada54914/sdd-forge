# T-002 独立レビュー後の検証

## スキップ件数と OQ の復旧

修正前の回帰テストをコミット `b89e38a94` に記録した。すでにスキップしているテストの説明変更は終了コード4になった。既存OQのJSONが壊れた場合は終了コード2となり、IDまたはfeatureが一致しない場合は、いずれも古いOQを再利用した。この4ケースはすべて期待値と異なった。

修正後はテストファイルごとに基準コミットと作業ツリーのスキップ指定を数える。Nodeのテストオプションはオブジェクトの改行、文字列理由、無効値、条件式を区別する。防御チェックは条件式を実行せず、スキップされ得る指定として数える。既存表記の説明変更と理由変更では終了コード0、件数増では4となった。PythonとGoの既存表記でも増加を検出した。

OQの番号・feature・基準コミット・違反一覧・ステータスが整合するときは同じ記録を使う。不整合な記録はそのまま残し、新しい番号のOQと終了コード4を返した。正当な既存のConfirmedは再利用できた。

- `node --test tests/v2-spec-drift.test.mjs` は20件成功。
- 実TLCを指定した `node --test tests/v2-spec-drift.test.mjs tests/v2-formal-gate.test.mjs tests/v2-sdd-core-flow.test.mjs` は63件成功、スキップ0件。GateLifecycleのEscalate対応と実行トレースを再検証した。最終テストの通常のオプション表記追加後に、上記20件を再実行した。
- MCPの標準esbuild設定で一時バンドルを生成し、275個の入力に `check-spec-drift.mjs` が含まれないことと、既存配布物とバイト単位で一致することを確認した。SHA-256は `bce07ec7a875ee7c1f01e7724b9c78022c59aa6e7fc96ca37b2ea27c2e76663b`。

## CODEOWNERS の配置

設計書64行目に記載した廃止承認マニフェストの所有者指定は、このブランチではルートの `CODEOWNERS:14` にあり、所有者は `@aharada54914` である。`git ls-files -- .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS` の出力は `CODEOWNERS` の1行だった。GitHubはPRのベースブランチで `.github/`、ルート、`docs/` の順に最初のファイルを使う。現行配置を維持した。ブランチ保護でレビューを必須にしているかどうかは、このファイルの検証範囲外である。[GitHub公式の配置とレビュー条件](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
