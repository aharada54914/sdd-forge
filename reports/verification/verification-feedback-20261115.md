# 起動条件・機能別結果・回帰接続の実装検証

日付: 2026-11-15 UTC。元の調査: `941fd7d5`。
ユーザーは3項目の仕様化・実装・検証・単一PRでの提示を明示的に依頼した。
仕様: [verification-feedback.md](../../docs/contributor/verification-feedback.md)。
設計判断: [ADR-0049](../../docs/adr/0049-verification-feedback-observations.md)。

## 変更

- 実行器は同一ディレクトリ・同一実体のPython別名だけを統一する。
  明示的なvenvや異なるPythonは切り替えない。CLI fixtureも実際の起動先へ拘束する。
  検査本体でパスや実行ファイルのidentityを無視する変更はしていない。
- run/maintainが既存の機能マップから結果一覧を返す。単一成功から未選択の機能へ
  成功を広げず、共有チェック・観測不足・不正マップ・未知結果は未評価となる。
- チェックIDをヘルパーへ渡し、v4観測では上書き後の実環境を拘束する。
  v1/v2の歴史扱い、v3の既存解釈、task/trial境界、ソースとtoolchain拘束を維持する。
- 既存Retention台帳から登録済みsuiteのみを実行できる。結果に台帳のSHA-256を残す。
  WFIテンプレート、retrospectiveの内蔵テンプレート、監査者Bの既存項目をそろえた。

## 実行結果

既存のカタログ実行器で各suiteを実行した。実際のreceipt、各出力のSHA-256、
集計とRetention結果は[checks.json](verification-feedback-20261115/checks.json)に保持した。
実行時には未コミットの実装があるため、receiptはdirtyであり再利用可能なゲート証拠ではない。

| suite | テスト数 | 結果 |
|---|---:|---|
| project-skill-observation | 42 | 成功 |
| project-skill-lifecycle | 48 | 成功 |
| project-skill-profiles | 5 | 成功 |
| project-skill-formal | 6 | 成功 |
| project-evidence-collector | 21 | 成功 |
| verification-catalog | 20 | 成功 |
| verification-ci | 93 | 成功 |
| verification-ci-plan | 61 | 成功 |
| verification-impact | 6 | 成功 |
| run-measurement | 20 | 成功 |
| 合計 | 322 | 成功 |

追加の確認:

- `python tests/project-skill-observation.tests.py`: 成功。カタログ経由のpython3と両方を確認。
- `tests/retrospective-loop.tests.sh`: fixtureの正確な集計とテンプレートの整合に成功。
- `--retention --run`: WFI-004の39チェック成功、skip 0。
  WFI-002/007/008/011はそれぞれの文脈・履歴上の理由でjudgment-required。
  全体の終了値1、complete falseは意図した未完了表現であり、全WFI成功ではない。
- バリデータschemaのルートとプラグインの同一性、`bash -n`、`git diff --check`: 成功。
- 既存native coding standardsのPython差分スキャン: 変更6ファイルをRuff 0.13.3で実行し、
  findings 0。全言語・全ルール・全人口の監査完了を意味しない。

## REDと独立レビュー

元の`941fd7d5`を分離worktreeへ展開し、Python起動問題がruntime-changedで失敗することを
再現した。新しいfeature coverageテスト2件とRetention接続テストを旧実装へ適用し、
チェックID未配信・feature_coverage欠落・retention API欠落で失敗することも確認した。
これらの失敗は旧実装の全般的欠陥ではなく、今回の受け入れ条件を満たさない対照である。

独立した読み取り専用レビューで、venv切替、子環境と指紋の不一致、未知結果の成功扱いを
指摘された。修正し、それぞれの負例を追加した。再レビューで新たな重大な不具合は
確認されなかった。独立レビュー時のPowerShell未実行分は、主担当が環境指定の
`/workspace/.tools/sdd-forge-dev/bin/pwsh`をPATHへ入れた実行で補った。
このレビューを既存の品質ゲートの正式PASSや仕様承認とは扱わない。

## 限界

検証はローカルLinuxでの関連回帰であり、macOS/Windows実機や全リポジトリsuiteの
実行ではない。TLC本体、新しいモデルによる行動比較、実利用全体の品質向上は未測定。
Retentionはsuiteのプロセス結果を扱う。suite内部の独自skipはログの確認が必要で、
WFI条件の意味的成立や人の承認を代行しない。自動マージ・リリースは行わない。

## マージ前の追加修正

PR #777の自動レビューで、字下げされたRetention行が読み飛ばされる指摘を受けた。
`c305451d`の旧実装で、登録済みsuite行の後に2空白で字下げした判断待ち行を置くと
`complete: true`になることを再現した。修正後は両方の行を保持し`complete: false`となる。

0〜3個のASCII空白はヘッダー・データ行とも受理する。4個以上、タブ、混在・Unicode空白、
ヘッダーから離れたWFI行は不正入力として拒否する。カタログ回帰は21テスト成功、
変更したPythonのRuff検査と差分検査も成功。先の322件はその時点の履歴であり、
この追記で過去のreceiptを更新・再利用したとは扱わない。

ユーザーは全チェックの成功と完成確認後のマージを明示的に依頼した。
GitHubの必須レビュー・最新HEADのCIを尊重し、承認や成功を捏造しない。
