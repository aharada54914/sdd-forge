# 検証の起動・機能別結果・再発防止の仕様

対象: 2026-11-15のユーザー依頼にある3項目。機能追加とその検証を同じPRで扱う。
前提調査: [Lauren Tan講演との照合](../../reports/lauren-tan-sdd-forge-review-20261115.md)。
本書は今回の実装契約と受け入れ条件を記録する。既存の仕様レビュー、品質ゲート、
WFI承認を実行済みとする記録ではなく、既存の承認・Done判定を変更しない。

## 要件

| ID | 必要な挙動 | 実装・根拠 |
|---|---|---|
| REQ-1 | `python`と`python3`の別名でテスト結果を変えず、明示的な仮想環境を維持する | `tests/verification.py` の `runtime_command`、`tests/project-skill-observation.tests.py` の `test_cli_and_shell` |
| REQ-2 | 実体差替え・環境差・ソース差・実行権限差の拒否を維持する | `plugins/sdd-quality-loop/scripts/validate-project-skill.py` の `runtime_environment` と `_validate` |
| REQ-3 | 既存機能マップの各機能を、未実行・到達不能・チェック成功・失敗・未評価に分けて表示する | `plugins/sdd-bootstrap/scripts/project-skill.py` の `feature_coverage` |
| REQ-4 | 単一チェック成功、共有チェック、空・不正なマップを全機能保証としない | 同 `run` / `maintain` |
| REQ-5 | 既存Retention台帳から、登録済み回帰テストだけを選択・実行する | `tests/verification.py` の `retention_checks` / `retention_result` |
| REQ-6 | 未接続・人の判断待ち・失敗・カタログ上の未実行を成功にしない | 同 `--retention` 実行結果、既存 `verification-receipt/v1` の追加 `retention` 要素 |
| REQ-7 | 繰り返す修正を既存テスト、新しいRED/GREEN、設計による除去、判断が必要なものへ分類する | WFIテンプレートのRegression connection、監査者Bの既存VERIFICATION-COMPLETE項目 |

## 設計と互換性

### 起動条件

POSIXラッパーの既存の選択規則はpython3→pythonである。直接CLIで観測fixtureを
作るテストは、そのCLIが使うインタープリターへ観測を結び付ける。実行器は
現在のPythonと同じディレクトリ・同じ実体のpython3だけを別名として統一する。
別ディレクトリのvenvや異なる実体は、明示的に起動されたPythonを保つ。
バリデータは別名のパスも引き続き識別する。検証側で実体やパスを無視しない。

### 機能別結果

`run`のCLI結果と保存するtrial receipt、`maintain`のCLI結果に`feature_coverage`を追加する。
正本の入力は既存の`features/README.md`と各機能の`Check ID:`であり、新しい台帳はない。

| status | 意味 |
|---|---|
| `not-run` | 対応チェック未選択、または文書手順などで未実行 |
| `unreachable` | 実行前提が利用できず、実行境界へ到達できない。製品ルートが存在しないという証明ではない |
| `check-passed` | その機能に一意に対応する宣言済みチェックが成功し、観測を保存・検証した |
| `check-failed` | 対応チェックが失敗した |
| `unassessed` | マップ不正、共有チェック、観測不足、未知の結果 |

行には機能ファイル、Check ID、理由、receiptとobservationへの参照を持つ。
`complete`は非空の有効なマップで全行が`check-passed`の場合だけtrue。
対象範囲は常に`declared-checks-only`であり、未定義のユーザー経路やタスク完了は保証しない。
マップのない既存スキルは従来の保守結果を保つが、機能網羅性はunknownのまま。
マップがあるのに空・不正・未評価なら保守をblockedとする。

チェック選択は`SDD_PROJECT_SKILL_CHECK_ID`としてヘルパーへ渡す。
v4観測では、この上書き後の実際の環境を指紋化する。v1/v2の歴史扱いと
v3の元の環境拘束を維持し、保存済みの観測を書き換えない。
厳格な契約は品質プラグインとルートの2箇所で同じschemaを保持する。

### 再発防止への接続

既存Retention台帳の`Regression Suites`列はカタログのsuiteパスを空白区切りで参照する。
`Judgment Reason`列は、自動判定できない条件の具体的な限界を記す。
元の再発条件とWFI履歴は保持し、WFI-004は解決済み回帰の別表にのみ接続する。
任意コマンド、シェル式、未登録suite、重複・矛盾・空の表は拒否する。

```
python3 tests/verification.py --retention --plan
python3 tests/verification.py --retention --run --receipt /tmp/retention.json
```

既存実行器の同じ実行・結果保存機能を使う。シャードによる部分実行は拒否する。
runの終了値は全件成功0、未完了または失敗1、不正設定2。WFI状態は書き換えない。
suite内部で独自に出すskipは終了値だけからは検出できないため、元ログも確認する。
これはカタログのコマンド単位の検証であり、WFIの意味的な成立を自動証明しない。

## 受け入れ条件とテスト

| AC | 確認内容 | 自動テスト |
|---|---|---|
| AC-1 | 両起動名の正常系、同一実体の別名、別実体・venvの保持 | observation `test_cli_and_shell`、catalog `test_python_runtime_prefers_dispatcher_name_without_changing_fallback` |
| AC-2 | 別名観測の拒否、同一パスの実体差替え、変数変更の拒否 | observation `test_runner_interpreter_alias_is_still_bound`、既存の差替え・環境変更テスト |
| AC-3 | v4は選択チェックを含む実際の環境を拘束し、上書き前の環境指紋を拒否 | observation `test_v4_binds_selected_check_in_the_effective_environment` |
| AC-4 | 2機能の片方だけ実行し、他方はnot-run。保守時に両方を実行して参照を保持 | lifecycle `test_feature_coverage_partial_run_and_complete_maintenance` |
| AC-5 | 共有、失敗、前提不足、文書手順、不正・空マップ、未知結果を全成功にしない | lifecycleのfeature coverage負例、既存の文書手順・missing runtimeテスト |
| AC-6 | 登録済み回帰のRED/GREEN、未接続・判断待ち・skipの未完了 | catalogのretentionテスト |
| AC-7 | 未登録、式、パス逸脱、重複、矛盾、不正表を拒否 | catalog `test_retention_rejects_injection_duplicates_unknown_and_malformed_rows` |
| AC-8 | WFIテンプレート、既存監査項目、retrospectiveの整合 | `tests/retrospective-loop.tests.sh` と独立差分レビュー |

検証記録は[実装・検証結果](../../reports/verification/verification-feedback-20261115.md)に保存する。
