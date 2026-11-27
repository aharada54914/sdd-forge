# T-002 再審用の統合検証

対象コミットは `33a9733b2573660a1380e41263ce45093eae39ff`。隔離したチェックアウトで、そのコミットの `run-sdd-gate.mjs` と `check-spec-drift.mjs` を使用した。すべての実行で `--anti-tamper` を明示し、テスト20件がすべて成功した。

| 実行記録 | 変更 | 保護検査 | 統合判定・終了コード |
|---|---|---|---|
| execution.json | 変更なし | CLEAN、検査0ファイル | PASS、0 |
| integrated-positive.json | テストファイルにコメントを追加 | CLEAN、検査1ファイル | PASS、0 |
| integrated-negative.json | 保護台帳に改行を1つ追加 | PROTECTED_PATH_MODIFIED、検査1ファイル | FAIL、1 |

3回ともspecDriftはCLEAN。保護台帳の差分で生成されたOQ-001の本文、対象feature、基準コミットを照合した。個別検査の規約違反時の終了コード4は回帰テストが検証している。integration.jsonに実行引数・run ID・終了コードを記録した。各作業パスは実行当時の一時ディレクトリである。

G5の照合にはsource-bindings.jsonのコミット・ツリー・実行ソースのSHA-256と、同じコミットのrepair.diffを使用できる。過去の記録は当時の実行を示す。現在の台帳のT-006状態はtested-tasks.mdとの比較をcurrent-task-status.diffに収めた。stable-baseline.jsonで保護仕様の3ファイルを再収集し、以前と同じパス集合であることを確認した。
