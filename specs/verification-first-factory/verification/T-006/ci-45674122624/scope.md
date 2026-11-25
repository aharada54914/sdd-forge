# T-006 CI 実績と変更範囲

GitHub Actions はコミット `cf53793720d0f3eb996e154627ace69dac893793` で TLC を実行した。正式なチェックの TAP は11件成功、失敗・スキップ0件。Python の `tests/project-skill-formal.tests.py` も8件成功した。TAP、予約モデルの結果、CIログから取り出したコマンドと集計を同梱した。アーティファクトZIPのSHA-256はGitHubが返した値と一致する。[実行ジョブ](https://github.com/aharada54914/sdd-forge/actions/runs/45674122624/job/139416964240)

各モデル・設定・テストの内容ハッシュを `ci-receipt.json` に収録した。`sameContent` はCIコミットと `f755b33f3` のバイト一致を示す。mapping.json はその後に変更された。CIの実行対象はCIコミットであり、後続のローカル修正は独自の検証を要する。

承認済み tasks.md の T-006 は形式モデル、対応表、CIのPythonテスト、廃止承認記録を Scope に挙げる。ロックと統合ゲートの実装はモデルが表現する動作で、T-006 の Scope 表には含まれない。T-008 は統合ゲートを Scope に含み、ロック競合の fail-closed 連携を要求する。task-lock.mjs 自身はT-008のScope表にも記載されていない。

- `4ce2aaa85`（Wave 3、T-008/T-009）は run-sdd-gate.mjs と Wave 3 統合テストを変更した。
- `c7f22ad69` は task-lock.mjs と run-sdd-gate.mjs を同時に修正し、競合に対する製品動作、TLA+ モデル、テストも変更した。ロック競合時の動作はT-008の検証に関係する。
- `a3d9a7574` は task-lock.mjs の解放時の所有者検証、mapping.json と形式テストを同時に変更した。このコミットは複数の範囲にまたがる。コミットのメッセージから単一のタスクへの帰属までは確認できない。

独立評価では、T-006 のモデル・実装対応の裏付けとして製品コードを読むことと、当該コードをT-006の実装成果として扱うことを区別できる。機械レシートにあるスコープ外警告も審査対象に含める。
